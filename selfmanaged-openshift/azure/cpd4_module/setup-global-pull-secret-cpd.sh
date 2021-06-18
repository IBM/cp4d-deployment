#!/bin/bash

ARTIFACTORY_USER=\$1
ARTIFACTORY_TOKEN=\$2
STAGING_USER=\$3
STAGING_APIKEY=\$4

staging_pull_secret=\$(echo -n "\$STAGING_USER:\$STAGING_APIKEY" | base64 -w0)
artifactory_pull_secret=\$(echo -n "\$ARTIFACTORY_USER:\$ARTIFACTORY_TOKEN" | base64 -w0)
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | sed -e 's|:{|:{"hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com":{"auth":"'\$artifactory_pull_secret'"\},|' > /tmp/dockerconfig.json
sed -i -e 's|:{|:{"hyc-cp4d-team-bootstrap-2-docker-local.artifactory.swg-devops.com":{"auth":"'\$artifactory_pull_secret'"\},|' /tmp/dockerconfig.json
sed -i -e 's|:{|:{"hyc-cloud-private-daily-docker-local.artifactory.swg-devops.com":{"auth":"'\$artifactory_pull_secret'"\},|' /tmp/dockerconfig.json
sed -i -e 's|:{|:{"hyc-cp4d-team-cde-docker-local.artifactory.swg-devops.com":{"auth":"'\$artifactory_pull_secret'"\},|' /tmp/dockerconfig.json
sed -i -e 's|:{|:{"cp.stg.icr.io/cp/cpd":{"auth":"'\$staging_pull_secret'"\},|' /tmp/dockerconfig.json
sed -i -e 's|:{|:{"cp.stg.icr.io":{"auth":"'\$staging_pull_secret'"\},|' /tmp/dockerconfig.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json



