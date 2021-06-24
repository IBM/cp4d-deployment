#!/bin/bash

STAGING_USER=\$1
STAGING_APIKEY=\$2

pull_secret=\$(echo -n "\$STAGING_USER:\$STAGING_APIKEY" | base64 -w0)

oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"hyc-cp4d-team-cde-docker-local.artifactory.swg-devops.com":{"auth":"'\$pull_secret'"\},|' > /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

# take a backup of dockerconfig.json after bedrock secret added. 

cp /tmp/dockerconfig.json /tmp/dockerconfig.json_cde_backup


