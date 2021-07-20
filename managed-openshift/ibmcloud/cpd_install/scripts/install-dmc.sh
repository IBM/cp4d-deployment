#!/bin/bash

# Case package. 

wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dmc-4.0.0.tgz


CASE_PACKAGE_NAME="ibm-dmc-4.0.0.tgz"

oc project ${OP_NAMESPACE}

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
    --namespace ${OP_NAMESPACE} \
    --tolerance 1

sleep 5m

oc project ${NAMESPACE} 

# Create dmc CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g dmc-cr.yaml
echo '*** executing **** oc create -f dmc-cr.yaml'
result=$(oc create -f dmc-cr.yaml)
echo $result

# checking status of dmc-operator
./pod-status-check.sh ibm-dmc-controller ${OP_NAMESPACE}

# check the mc cr status
./check-cr-status.sh dmcaddon dmcaddon-cr ${NAMESPACE} dmcAddonStatus
