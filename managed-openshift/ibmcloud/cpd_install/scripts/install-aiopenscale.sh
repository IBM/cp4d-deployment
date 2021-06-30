#!/bin/bash

wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-watson-openscale-2.0.0.tgz

# Install WOS operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-watson-openscale-2.0.0.tgz"

oc project ${OP_NAMESPACE}


cloudctl case launch --case ./${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE}                                   \
    --tolerance 1

# Checking if the wos operator pods are ready and running. 

./pod-status-check.sh ibm-cpd-wos-operator ${OP_NAMESPACE}

# switch zen namespace

oc project ${NAMESPACE}

# Create wsl CR: 

result=$(oc create -f openscale-cr.yaml)
echo $result

# check the CCS cr status

./check-cr-status.sh WOService aiopenscale ${NAMESPACE} wosStatus