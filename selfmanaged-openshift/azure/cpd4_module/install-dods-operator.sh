#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2


export DODS-FILE-LOCATION=/home/core/dods-files/

export CASE_PATH=/home/core/dods-files/\${CASE_PACKAGE_NAME}
export SAVED_CASE=/home/core/dods-files/case-saved/
export CASECTL_RESOLVERS_LOCATION=/home/core/dods-files/resolvers.yaml
export CASECTL_RESOLVERS_AUTH_LOCATION=/home/core/dods-files/resolversAuth.yaml

cd \${DODS-FILE-LOCATION}


cloudctl case save --case \${CASE_PATH} \
    --tolerance 1 \
    --outputdir=\${SAVED_CASE}

cd  \${SAVED_CASE}

oc project ibm-common-services


cloudctl case launch --tolerance 1 \
    --case \${CASE_PATH} \
    --namespace openshift-marketplace \
    --inventory dodsOperatorSetup \
    --action installCatalog \
    --args "--recursive --inputDir \$SAVED_CASE"


cloudctl case launch --tolerance 1 \
    --case \${CASE_PATH} \
    --namespace \${NAMESPACE} \
    --inventory dodsOperatorSetup \
    --action installOperator

