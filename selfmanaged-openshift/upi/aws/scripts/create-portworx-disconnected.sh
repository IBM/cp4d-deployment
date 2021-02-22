#! /bin/bash

PORTWORX_SPEC_URL=$1
REDHAT_USERNAME=$2
REDHAT_PASSWORD=$3
NAMESPACE=kube-system

export KUBECONFIG=$HOME/ocpfourx/auth/kubeconfig
oc login -u kubeadmin -p $(cat $HOME/ocpfourx/auth/kubeadmin-password)

# Install Podman
sudo subscription-manager register --username=$REDHAT_USERNAME --password=$REDHAT_PASSWORD
sudo subscription-manager attach --auto
sudo subscription-manager repos --enable=rhel-7-server-extras-rpms
sudo yum install -y podman httpd-tools

oc project $NAMESPACE
oc create route reencrypt --service=image-registry -n openshift-image-registry
oc annotate route image-registry --overwrite haproxy.router.openshift.io/balance=source -n openshift-image-registry
IMAGEREGISTRY_ROUTE=$(oc get route -n openshift-image-registry | grep -v default-route | grep image-registry | awk '{print $2}')

sudo podman login -u kubeadmin -p $(oc whoami -t) $IMAGEREGISTRY_ROUTE --tls-verify=false
oc create configmap px-versions --from-file=versions -n $NAMESPACE

REGISTRY_HOSTNAME=$(oc get route -n openshift-image-registry | grep -v default-route | grep image-registry | awk '{print $2}' | xargs)
sudo sed -i "/^\[registries.insecure\]/{n;d}" /etc/containers/registries.conf
sudo sed -i "/\[registries.insecure\]/a registries = [\'$REGISTRY_HOSTNAME\']" /etc/containers/registries.conf

sudo podman login -u kubeadmin -p $(oc whoami -t)  $IMAGEREGISTRY_ROUTE5 --tls-verify=false
sudo sh px-ag-install.sh pull
sudo podman login -u kubeadmin -p $(oc whoami -t)  $IMAGEREGISTRY_ROUTE --tls-verify=false
sudo sh px-ag-install.sh push $IMAGEREGISTRY_ROUTE/openshift-image-registry

sudo podman run -dt -p 8080:8080 docker.io/portworx/px-repo:1.0.0
sleep 2m

oc create deployment px-repo --image=docker.io/portworx/px-repo:1.0.0
oc get pods -l app=px-repo -o wide
# expose px-repo deployment, to enable access to host-systems
oc expose deployment px-repo --name=px-repo-service --type=LoadBalancer --port 80 --target-port 8080
oc get service px-repo-service
oc label nodes --all px/service=restart

oc create -f $HOME/ocpfourxtemplates/px-operator-disconnected.yaml
./portworx-prereq.sh

oc apply -f \"$PORTWORX_SPEC_URL\"
