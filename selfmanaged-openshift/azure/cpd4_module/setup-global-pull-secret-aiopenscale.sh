#!/bin/bash

DOCKER_USERNAME=\$1
DOCKER_APIKEY=\$2

pull_secret=\$(echo -n "\$DOCKER_USERNAME:\$DOCKER_APIKEY" | base64 -w0)
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|"auths":{|"auths":{"cp.stg.icr.io":{"auth":"'\$pull_secret'"\},|' > /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json


# take a backup of dockerconfig.json after bedrock secret added. 

cp /tmp/dockerconfig.json /tmp/dockerconfig.json_openscale_backup


