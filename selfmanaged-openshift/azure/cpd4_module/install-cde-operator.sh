#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

## Install Operator

cloudctl case launch \
  --case \${CASE_PACKAGE_NAME} \
  --namespace \${NAMESPACE} \
  --tolerance=1 \
  --action installOperator \
  --inventory cdeOperatorSetup