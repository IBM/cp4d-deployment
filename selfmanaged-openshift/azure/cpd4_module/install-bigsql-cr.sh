#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

oc project \${NAMESPACE}

## Install Customer Resources bigsql 
cloudctl case launch --case \${CASE_PACKAGE_NAME} \
    --namespace \${NAMESPACE} \
    --action applyCustomResources \
    --inventory bigsql \
    --tolerance 1