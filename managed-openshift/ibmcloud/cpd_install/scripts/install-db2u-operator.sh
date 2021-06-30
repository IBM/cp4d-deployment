#!/bin/bash

# Case package. 
## Db2u Operator 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-db2uoperator-4.0.0-3731.2407.tgz

# # Install db2u operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-db2uoperator-4.0.0-3731.2407.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog 

cloudctl case launch --case  ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --inventory db2uOperatorSetup \
    --action installCatalog \
    --tolerance=1
    
## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --inventory db2uOperatorSetup \
    --action installOperator \
    --tolerance=1


# Checking if the DB2U operator pods are ready and running. 
# checking status of db2u-operator
./pod-status-check.sh db2u-operator ${OP_NAMESPACE}

