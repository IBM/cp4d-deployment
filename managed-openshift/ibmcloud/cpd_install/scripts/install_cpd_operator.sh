#!/bin/bash

echo ${CPD_REGISTRY}
echo ${CPD_REGISTRY_USERNAME}
echo ${CPD_REGISTRY_PASSWORD}


oc new-project $NAMESPACE || return $?

# cat <<EOF | oc apply -f -
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: ibm-cp-data-operator-serviceaccount
# EOF

# oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:${NAMESPACE}:ibm-cp-data-operator-serviceaccount

cloudctl case launch                        \
  --case ${CPD_CASE_DIR}/ibm-cp-datacore    \
  --namespace=${NAMESPACE}                  \
  --inventory cpdMetaOperatorSetup          \
  --action install-operator                 \
  --tolerance=1                             \
  --args "--entitledRegistry ${CPD_REGISTRY} --entitledUser ${CPD_REGISTRY_USER} --entitledPass ${CPD_REGISTRY_PASSWORD}" || return $?
