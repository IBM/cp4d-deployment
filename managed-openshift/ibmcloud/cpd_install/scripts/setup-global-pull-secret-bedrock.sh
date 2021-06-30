#!/bin/bash

ENTITLEMENT_USER=$1
ENTITLEMENT_KEY=$2

pull_secret=$(echo -n "$ENTITLEMENT_USER:$ENTITLEMENT_KEY" | base64 -w0)

# Retrieve the current global pull secret
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/dockerconfig.json

sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' /tmp/dockerconfig.json


oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

# copy to current directory
cp /tmp/dockerconfig.json config.json

# take a backup of dockerconfig.json after bedrock secret added. 
cp /tmp/dockerconfig.json /tmp/dockerconfig.json_bedrock_backup


