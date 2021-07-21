#!/bin/bash

wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-wsl-2.0.0.tgz

# Install wsl operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-wsl-2.0.0.tgz"

oc project ${OP_NAMESPACE}

cloudctl  case launch --case ./${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory wslSetup 

cloudctl case launch --case ./${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace ${OP_NAMESPACE}         \
    --action installOperator \
    --inventory wslSetup 
    # --args "--registry cp.icr.io"

# Checking if the wsl operator pods are ready and running. 

./pod-status-check.sh ibm-cpd-ws-operator ${OP_NAMESPACE}

# switch zen namespace

oc project ${NAMESPACE}

# Create wsl CR: 

result=$(oc create -f wsl-cr.yaml)
echo $result

# check the CCS cr status

./check-cr-status.sh ws ws-cr ${NAMESPACE} wsStatus