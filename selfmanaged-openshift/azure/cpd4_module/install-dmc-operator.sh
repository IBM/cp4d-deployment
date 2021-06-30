#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2
STORAGECLASS=\$3
CPD_NAMESPACE=\$4

oc project \${NAMESPACE}

## Install Catalog 

cloudctl case launch --action installCatalog \
    --case \${CASE_PACKAGE_NAME} \
    --inventory dmcOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch  --action installOperator \
    --case \${CASE_PACKAGE_NAME} \
    --inventory dmcOperatorSetup \
    --namespace \${NAMESPACE} \
    --tolerance 1

sleep 5m

oc project \${CPD_NAMESPACE} 

cat << EOF | oc apply -f -
apiVersion: dmc.databases.ibm.com/v1
kind: Dmcaddon
metadata:
  name: dmcaddon-cr
spec:
  namespace: zen
  storageClass: \${STORAGECLASS}
  pullPrefix: cp.icr.io/cp/cpd
  version: "4.0.0"
  license:
    accept: true
    license: Enterprise 
EOF



