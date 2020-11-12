#!/bin/bash

APIKEY=$1
OPT_NAMESPACE=$2

export OPERATOR_REGISTRY=cp.stg.icr.io/cp
export OPERATOR_REGISTRY_USER=iamapikey
export OPERATOR_REGISTRY_PASSWORD=$APIKEY
export CPD_REGISTRY=cp.stg.icr.io/cp/cpd
export CPD_REGISTRY_USER=iamapikey
export CPD_REGISTRY_PASSWORD=$APIKEY
export NAMESPACE=$OPT_NAMESPACE

cloudctl-linux-amd64 case launch              \
    --case ibm-cp-datacore                    \
    --namespace ${NAMESPACE}                  \
    --inventory cpdMetaOperatorSetup          \
    --action install-operator                 \
    --tolerance=1                             \
   --args "--secret docker.io --registry ${OPERATOR_REGISTRY} --user ${OPERATOR_REGISTRY_USER} --pass ${OPERATOR_REGISTRY_PASSWORD} --entitledRegistry ${CPD_REGISTRY} --entitledUser ${CPD_REGISTRY_USER} --entitledPass ${CPD_REGISTRY_PASSWORD}"