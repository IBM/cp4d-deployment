#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl-linux-amd64 case launch --case ./\${CASE_PACKAGE_NAME} \
    --tolerance 1 --namespace \${NAMESPACE}         \
    --action installOperator --inventory wslSetp    \
    --args "--registry cp.stg.icr.io"