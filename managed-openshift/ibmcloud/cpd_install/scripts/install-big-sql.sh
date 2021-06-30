#!/bin/bash

# Case package. 
## bigsql case package 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-bigsql-case-7.2.0.tgz

# # Install bigsql operator using CLI (OLM)
CASE_PACKAGE_NAME="ibm-bigsql-case-7.2.0.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog 

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory bigsql \
    --tolerance 1

## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --action installOperator \
    --inventory bigsql \
    --tolerance 1 

# Checking if the bigsql operator pods are ready and running. 
# checking status of ibm-bigsql-operator
./pod-status-check.sh ibm-bigsql-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

## Install Custom Resource bigsql 
cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${NAMESPACE} \
    --action applyCustomResources \
    --inventory bigsql \
    --tolerance 1

# check the bigsql cr status
./check-cr-status.sh bigsqlservice bigsql-service ${NAMESPACE} reconcileStatus