#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

export WML_OPERATOR_CATALOG_NAMESPACE=openshift-marketplace


## Install catalog 

cloudctl case launch --case \${CASE_PACKAGE_NAME} \
    --namespace \${WML_OPERATOR_CATALOG_NAMESPACE}  \
    --inventory  wmlOperatorSetup \
    --action installCatalog \
    --tolerance 1

## Install Operator

cloudctl case launch --case \${CASE_PACKAGE_NAME} \
    --namespace \${NAMESPACE} \
    --inventory  wmlOperatorSetup \
    --action install \
    --tolerance=1