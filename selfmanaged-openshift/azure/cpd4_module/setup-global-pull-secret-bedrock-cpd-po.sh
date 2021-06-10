#!/bin/bash

ARTIFACTORY_USER=\$1
ARTIFACTORY_TOKEN=\$2

pull_secret=\$(echo -n "\$ARTIFACTORY_USER:\$ARTIFACTORY_TOKEN" | base64 -w0)
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com":{"auth":"'\$pull_secret'"\},|' > /tmp/dockerconfig.json
sed -i -e 's|:{|:{"hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com":{"auth":"'\$pull_secret'"\},|' /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

# take a backup of dockerconfig.json after bedrock secret added. 

cp /tmp/dockerconfig.json /tmp/dockerconfig.json_bedrock_backup


