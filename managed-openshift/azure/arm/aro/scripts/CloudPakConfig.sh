#!/bin/sh

set -x 

export LOCATION=$1
export DOMAINNAME=$2
export SUDOUSER=$3
export WORKERNODECOUNT=$4
export CPDNAMESPACE=$5
export STORAGEOPTION=$6
export APIKEY=$7
export OPENSHIFTUSER=$8
export OPENSHIFTPASSWORD=$9
export CUSTOMDOMAIN=${10}
export CLUSTERNAME=${11}
export CHANNEL=${12}
export VERSION=${13}

export OPERATORNAMESPACE=ibm-common-services
export INSTALLERHOME=/home/$SUDOUSER/.ibm
export OCPTEMPLATES=/home/$SUDOUSER/.openshift/templates
export CPDTEMPLATES=/mnt/.cpd/templates

runuser -l $SUDOUSER -c "mkdir -p $INSTALLERHOME"
runuser -l $SUDOUSER -c "mkdir -p $OCPTEMPLATES"
runuser -l $SUDOUSER -c "sudo mkdir -p $CPDTEMPLATES"

#CPD Config

# runuser -l $SUDOUSER -c "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz -O $CPDTEMPLATES/cloudctl-linux-amd64.tar.gz"
# runuser -l $SUDOUSER -c "https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz.sig -O $CPDTEMPLATES/cloudctl-linux-amd64.tar.gz.sig"
# runuser -l $SUDOUSER -c "cd $CPDTEMPLATES && sudo tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/bin"
# runuser -l $SUDOUSER -c "chmod +x /usr/bin/cloudctl-linux-amd64"
# runuser -l $SUDOUSER -c "sudo mv /usr/bin/cloudctl-linux-amd64 /usr/bin/cloudctl"

### Install Prereqs:  CPD CLI, JQ, and Podman
## Download & Install CPD CLI
runuser -l $SUDOUSER -c "sudo wget https://github.com/IBM/cpd-cli/releases/download/v11.0.0/cpd-cli-linux-EE-11.0.0.tgz -O $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0.tgz"
runuser -l $SUDOUSER -c "cd $CPDTEMPLATES && sudo tar -xvf cpd-cli-linux-EE-11.0.0.tgz"
# Move cpd-cli, plugins and license in the CPDTEMPLATES folder
runuser -l $SUDOUSER -c "sudo mv $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0-20/* $CPDTEMPLATES"
runuser -l $SUDOUSER -c "sudo rm -rf $CPDTEMPLATES/cpd-cli-linux-EE-11.0.0*"

# Service Account Token for CPD installation
runuser -l $SUDOUSER -c "oc new-project $CPDNAMESPACE"

# Service Account Token for CPD installation
runuser -l $SUDOUSER -c "oc new-project $OPERATORNAMESPACE"

## Installing jq
runuser -l $SUDOUSER -c "sudo wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O $CPDTEMPLATES/jq"
runuser -l $SUDOUSER -c "sudo mv $CPDTEMPLATES/jq /usr/bin"
runuser -l $SUDOUSER -c "sudo chmod +x /usr/bin/jq"

## Installing Podman
runuser -l $SUDOUSER -c "sudo yum install podman -y"

# Set url
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
else
export SUBURL="${DOMAINNAME}.${LOCATION}.aroapp.io"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

# CPD CLI OCP Login
runuser -l $SUDOUSER -c "sudo $CPDTEMPLATES/cpd-cli manage login-to-ocp --server \"https://api.${SUBURL}:6443\" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD"

# Update global pull secret 

export ENTITLEMENT_USER=cp
export ENTITLEMENT_KEY=$APIKEY
pull_secret=$(echo -n "$ENTITLEMENT_USER:$ENTITLEMENT_KEY" | base64 -w0)
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > $OCPTEMPLATES/dockerconfig.json
sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' $OCPTEMPLATES/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=$OCPTEMPLATES/dockerconfig.json

# Sleep for 2 min then check the status of nodes
sleep 120

# Check nodestatus if they are ready.

while true; do
    node_status=$(oc get nodes | grep -E "SchedulingDisabled|NotReady")
    if [[ -z $node_status ]]; then
        echo -e "\n******All nodes are running now.******"
        break
    fi
        echo -e "\n******Waiting for nodes to get ready.******"
        oc get nodes --no-headers | awk '{print $1 " " $2}'
        echo -e "\n******sleeping for 60Secs******"
        sleep 60
    done