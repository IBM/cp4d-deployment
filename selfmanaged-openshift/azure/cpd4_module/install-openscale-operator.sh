#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl case launch --case ./\${CASE_PACKAGE_NAME} \
    --namespace \${NAMESPACE}                                   \
    --tolerance 1