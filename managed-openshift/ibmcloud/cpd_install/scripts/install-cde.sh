#!/bin/bash


# Case package.
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cde-2.0.0.tgz

CASE_PACKAGE_NAME="ibm-cde-2.0.0.tgz"

## Install Operator

cloudctl case launch \
  --case ${CASE_PACKAGE_NAME} \
  --namespace ${OP_NAMESPACE} \
  --tolerance=1 \
  --action installOperator \
  --inventory cdeOperatorSetup



# Checking if the cde operator pods are ready and running. 
# checking status of ibm-cde-operator
./pod-status-check.sh ibm-cde-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# Create cde CR: 
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g cde-cr.yaml
echo '*** executing **** oc create -f cde-cr.yaml'
result=$(oc create -f cde-cr.yaml)
echo $result

# check the cde cr status
./check-cr-status.sh CdeProxyService cde-cr ${NAMESPACE} cdeStatus