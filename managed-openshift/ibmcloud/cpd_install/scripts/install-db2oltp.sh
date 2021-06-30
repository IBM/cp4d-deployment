#!/bin/bash


# Case package for db2oltp
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-db2oltp-4.0.0.tgz


# Install db2oltp operator using CLI (OLM)	
CASE_PACKAGE_NAME="ibm-db2oltp-4.0.0.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog 

cloudctl case launch --action installCatalog \
    --case ${CASE_PACKAGE_NAME} \
    --inventory db2oltpOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch  --action installOperator \
    --case ${CASE_PACKAGE_NAME} \
    --inventory db2oltpOperatorSetup \
    --namespace ${OP_NAMESPACE} \
    --tolerance 1
    
sleep 1m 

# Checking if the db2oltp operator podb2oltp are ready and running. 	
# checking status of db2oltp-operator	
./pod-status-check.sh ibm-db2oltp-cp4d-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create db2oltp CR: 	
echo '*** executing **** oc create -f db2oltp-cr.yaml'
result=$(oc create -f db2oltp-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh Db2oltpService db2oltp-cr ${NAMESPACE} db2oltpStatus