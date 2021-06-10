#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl-linux-amd64 case launch --case ./\${CASE_PACKAGE_NAME} \
    --namespace \${NAMESPACE}                                   \
    --tolerance 1