#!/bin/bash

CASE_PACKAGE_NAME=$1
NAMESPACE=$2

oc project ${NAMESPACE}

## Install Catalog 

cloudctl case launch --case  ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --inventory db2uOperatorSetup \
    --action installCatalog \
    --tolerance=1
    
## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${NAMESPACE} \
    --inventory db2uOperatorSetup \
    --action installOperator \
    --tolerance=1