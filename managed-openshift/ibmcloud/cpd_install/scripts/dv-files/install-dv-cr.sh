#!/bin/bash

CASE_PACKAGE_NAME=$1
NAMESPACE=$2

oc project ${NAMESPACE}

## Install Customer Resources dv 
cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${NAMESPACE} \
    --action applyCustomResources \
    --inventory dv \
    --tolerance 1