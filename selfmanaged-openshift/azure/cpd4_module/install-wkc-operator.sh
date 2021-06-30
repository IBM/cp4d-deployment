#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

## Install Operator

cloudctl case launch --case  \${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace \${NAMESPACE} \
    --action installOperator \
    --inventory wkcOperatorSetup
