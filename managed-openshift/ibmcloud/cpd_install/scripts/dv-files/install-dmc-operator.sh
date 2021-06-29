#!/bin/bash

CASE_PACKAGE_NAME=$1
NAMESPACE=$2

oc project ${NAMESPACE}

## Install Catalog 

cloudctl case launch --action installCatalog \
    --case ${CASE_PACKAGE_NAME} \
    --inventory dmcOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch  --action installOperator \
    --case ${CASE_PACKAGE_NAME} \
    --inventory dmcOperatorSetup \
    --namespace ${NAMESPACE} \
    --tolerance 1

sleep 1m 

cat << EOF | oc apply -f -
apiVersion: dmc.databases.ibm.com/v1
kind: Dmcaddon
metadata:
  name: dmc-addon
spec:
  namespace: zen
  storageClass: portworx-shared-gp3
  pullPrefix: cp.stg.icr.io/cp/cpd
  version: "4.0.0"
  license:
    accept: true
    license: Standard 
EOF