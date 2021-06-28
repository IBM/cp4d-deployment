#!/bin/bash

ARTIFACTORY_USER=$1
ARTIFACTORY_TOKEN=$2

pull_secret=$(echo -n "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" | base64)
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com":{"auth":"'$pull_secret'"\},|' > /tmp/dockerconfig.json
sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

# take a backup of dockerconfig.json after bedrock secret added. 

cp /tmp/dockerconfig.json /tmp/dockerconfig.json_backup