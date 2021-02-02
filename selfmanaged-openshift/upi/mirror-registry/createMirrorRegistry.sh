#! /bin/bash

# Install podman httpd-tools
EMAIL=$1
USERNAME=$2
PASSWORD=$3
REDHAT_USERNAME=$5
REDHAT_PASSWORD=$6
HOSTNAME=`hostname`
local_registry_host_port=5000

# Install jq
sudo subscription-manager register --username=${REDHAT_USERNAME} --password=${REDHAT_PASSWORD}
sudo subscription-manager attach --auto
sudo subscription-manager repos --enable="rhel-7-server-extras-rpms"
sudo yum install -y podman httpd-tools
sudo yum install -y firewalld
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y jq
sudo yum install -y openssl
sudo yum -y install wget
sudo mkdir -p /opt/registry/{auth,certs,data}
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$4/openshift-client-linux.tar.gz
sudo tar -xvf openshift-client-linux.tar.gz -C /usr/local/bin

# Generate SSL certificate
./createSSL.sh $EMAIL

# Generate a user name and a password for your registry that uses the bcrpt format
sudo htpasswd -bBc /opt/registry/auth/htpasswd $USERNAME $PASSWORD

# Create the mirror-registry container
sudo podman run --name mirror-registry -p $local_registry_host_port:5000 \
-v /opt/registry/data:/var/lib/registry:z \
     -v /opt/registry/auth:/auth:z \
     -e "REGISTRY_AUTH=htpasswd" \
     -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     -v /opt/registry/certs:/certs:z \
     -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
     -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
     -d docker.io/library/registry:2

# Open the required ports for your registry:
# sudo systemctl enable firewalld
# sudo systemctl start firewalld
# sudo firewall-cmd --add-port=$local_registry_host_port/tcp --zone=internal --permanent 
# sudo firewall-cmd --add-port=$local_registry_host_port/tcp --zone=public   --permanent 
# sudo firewall-cmd --reload

# Add the self-signed certificate to your list of trusted certificates
sudo cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/

# update-ca-trust
sudo update-ca-trust

# Confirm that the registry is available
echo "If the command output displays an empty repository, your registry is available."
curl -u $USERNAME:$PASSWORD -k https://$HOSTNAME:5000/v2/_catalog

# Adding registry to your pull-secret
echo "*** Adding registry to your pull-secret ****"
TOKEN=`echo -n $USERNAME:$PASSWORD  | base64 -w0`
HOSTPORT=$HOSTNAME:5000

# Make a copy of your pull secret in JSON format:
cat ./pull-secret | jq .  > ./pull-secret-dup.json

# Add your credentials to  pull-secret.json
cat pull-secret-dup.json | jq '.auths |= . +  {"HOSTPORT": { "auth": "TOKEN", "email": "you@example.com"}}' pull-secret-dup.json > pull-secret.json

sed -i "s/TOKEN/$TOKEN/g" pull-secret.json
sed -i "s/HOSTPORT/${HOSTPORT}/g" pull-secret.json
sed -i "s/you@example.com/$EMAIL/g" pull-secret.json

# Mirroring the OpenShift Container Platform image repository
echo "*** Mirroring the OpenShift Container Platform image repository ***"
export ARCHITECTURE=x86_64
export OCP_RELEASE=$4
export LOCAL_REGISTRY=$HOSTPORT
export LOCAL_REPOSITORY='ocp4/openshift4'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='./pull-secret.json'
export RELEASE_NAME="ocp-release"

# Variable to avoid errors due to selfsigned certificates. 
export GODEBUG=x509ignoreCN=0

# Mirror the Repository
echo "*** Mirror the Repository ***"
echo "oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"

oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}


# create the installation program that is based on the content that you mirrored, extract it and pin it to the release
echo "creating the installation program that is based on the content that you mirrored, extract it and pin it to the release"
echo "oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}""
oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"

