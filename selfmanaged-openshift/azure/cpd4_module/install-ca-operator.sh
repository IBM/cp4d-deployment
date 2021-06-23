#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2
STORAGECLASS=\$3

oc project \${NAMESPACE}

## Install Catalog 

cloudctl case launch --action installCatalog \
    --case \${CASE_PACKAGE_NAME} \
    --inventory ibmCaOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch  --action installOperator \
    --case \${CASE_PACKAGE_NAME} \
    --inventory ibmCaOperatorSetup \
    --namespace \${NAMESPACE} \
    --tolerance 1

sleep 1m 

