#!/bin/bash

APIKEY=\$1
OPT_NAMESPACE=\$2

export CPD_REGISTRY=cp.icr.io/cp/cpd
export CPD_REGISTRY_USER=cp
export CPD_REGISTRY_PASSWORD=\$APIKEY
export NAMESPACE=\$OPT_NAMESPACE

cloudctl-linux-amd64 case launch              \
    --case ibm-cp-datacore                    \
    --namespace \${NAMESPACE}                 \
    --inventory cpdMetaOperatorSetup          \
    --action install-operator                 \
    --tolerance=1                             \
    --args "--entitledRegistry \${CPD_REGISTRY} --entitledUser \${CPD_REGISTRY_USER} --entitledPass \${CPD_REGISTRY_PASSWORD}"