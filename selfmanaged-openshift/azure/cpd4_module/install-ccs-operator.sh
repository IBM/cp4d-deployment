#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl case launch --case ./\${CASE_PACKAGE_NAME} \
    --tolerance 1 --namespace \${NAMESPACE}         \
    --action installOperator                        \
    --inventory ccsSetup                            \
    --args "--registry cp.icr.io"