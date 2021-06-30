#!/bin/bash

# Case package. 	
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cognos-analytics-prod-4.0.0.tgz

# Install ca operator using CLI (OLM)	

CASE_PACKAGE_NAME="ibm-cognos-analytics-prod-4.0.0.tgz"

## Install Catalog

cloudctl case launch --action installCatalog \
    --case ${CASE_PACKAGE_NAME} \
    --inventory ibmCaOperatorSetup \
    --namespace openshift-marketplace \
    --tolerance 1

## Install Operator

cloudctl case launch --action installOperator \
    --case ${CASE_PACKAGE_NAME} \
    --inventory ibmCaOperatorSetup \
    --namespace ${OP_NAMESPACE} \
    --tolerance 1

sleep 1m

# Checking if the ca operator pods are ready and running. 	
# checking status of ca-operator	
./pod-status-check.sh ca-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create ca CR: 	

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g ca-cr.yaml
echo '*** executing **** oc create -f ca-cr.yaml'
result=$(oc create -f ca-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh CAService ca-cr ${NAMESPACE} caAddonStatus