#!/bin/bash


# Download the case package for dods
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dods-4.0.0.tgz

# Install dods operator using CLI (OLM)


CASE_PACKAGE_NAME="ibm-dods-4.0.0.tgz"

cloudctl case launch --tolerance 1 \
    --case ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --inventory dodsOperatorSetup \
    --action installCatalog 


cloudctl case launch --tolerance 1 \
    --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --inventory dodsOperatorSetup \
    --action installOperator

# Checking if the dods operator pods are ready and running. 
# checking status of ibm-cpd-dods-operator
./pod-status-check.sh ibm-cpd-dods-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# Create dods CR: 

echo '*** executing **** oc create -f dods-cr.yaml'
result=$(oc create -f dods-cr.yaml)
echo $result

# check the CCS cr status
./check-cr-status.sh DODS dods-cr ${NAMESPACE} dodsStatus