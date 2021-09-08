#!/bin/bash

# Install wml operator 
sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g wml-sub.yaml

echo '*** executing **** oc create -f wml-sub.yaml'
result=$(oc create -f wml-sub.yaml)
echo $result
sleep 1m

# Checking if the wml operator pods are ready and running. 

# checking status of ibm-watson-wml-operator

./pod-status-check.sh ibm-cpd-wml-operator ${OP_NAMESPACE}

# switch zen namespace

oc project ${NAMESPACE}

# Create wml CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g wml-cr.yaml
echo '*** executing **** oc create -f wml-cr.yaml'
result=$(oc create -f wml-cr.yaml)
echo $result

# check the WML cr status

./check-cr-status.sh WmlBase wml-cr ${NAMESPACE} wmlStatus