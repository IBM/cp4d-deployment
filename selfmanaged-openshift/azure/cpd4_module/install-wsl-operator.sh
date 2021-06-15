#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2
GITUSER=\$3
GITTOKEN=\$4

export OFFLINE_LOCATION=/home/core/wsl-files/offline
export WSL_FILES_LOCATION=/home/core/wsl-files

export CASECTL_RESOLVERS_LOCATION=/home/core/wsl-files/resolvers.yaml
export CASECTL_RESOLVERS_AUTH_LOCATION=/home/core/wsl-files/resolversAuth.yaml

cd \${WSL_FILES_LOCATION}

cloudctl case save --case ibm-wsl \
    --version 2.0.0-367 \
    --repo https://\${GITTOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev \
    --outputdir \${OFFLINE_LOCATION} -t 1

cd  \${OFFLINE_LOCATION}

oc project ibm-common-services

cloudctl  case launch --case ibm-wsl-2.0.0-367.tgz \
    --tolerance 1 \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory wslSetup \
    --args '--recursive --inputDir /home/core/wsl-files/offline'

cloudctl case launch --case ibm-wsl-2.0.0-367.tgz \
    --tolerance 1 \
    --namespace ibm-common-services \
    --action installOperator \
    --inventory wslSetup \
    --args "--registry cp.stg.icr.io"
