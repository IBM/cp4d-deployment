#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl case launch --tolerance 1 \
    --case \${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --inventory dodsOperatorSetup \
    --action installCatalog 


cloudctl case launch --tolerance 1 \
    --case \${CASE_PACKAGE_NAME} \
    --namespace \${NAMESPACE} \
    --inventory dodsOperatorSetup \
    --action installOperator

