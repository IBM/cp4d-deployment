#!/bin/bash


# Case package. 

## DV case 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dv-case-1.7.0.tgz

# # Install dv operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-dv-case-1.7.0.tgz"

oc project ${OP_NAMESPACE}

## Install Catalog 

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory dv \
    --tolerance 1

## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --action installOperator \
    --inventory dv \
    --tolerance 1 

# Checking if the dv operator pods are ready and running. 

./pod-status-check.sh ibm-dv-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# # Install dv Customer Resource

## Install Customer Resources dv 
cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${NAMESPACE} \
    --action applyCustomResources \
    --inventory dv \
    --tolerance 1

# check the dv cr status
./check-cr-status.sh dvservice dv-service ${NAMESPACE} reconcileStatus
