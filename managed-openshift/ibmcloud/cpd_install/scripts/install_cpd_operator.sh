#!/bin/bash

oc new-project $NAMESPACE || exit $?

cloudctl case launch                        \
  --case ${CPD_CASE_DIR}/ibm-cp-datacore    \
  --namespace=${NAMESPACE}                  \
  --inventory cpdMetaOperatorSetup          \
  --action install-operator                 \
  --tolerance=1                             \
  --args "--entitledRegistry ${CPD_REGISTRY} --entitledUser ${CPD_REGISTRY_USER} --entitledPass ${CPD_REGISTRY_PASSWORD}" || exit $?
