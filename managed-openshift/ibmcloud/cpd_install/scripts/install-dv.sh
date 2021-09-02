#!/bin/bash

oc project ${OP_NAMESPACE}

## Install Operator

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g dv-sub.yaml

echo '*** executing **** oc create -f dv-sub.yaml'
result=$(oc create -f dv-sub.yaml)
echo $result
sleep 1m

# Checking if the dv operator pods are ready and running. 

./pod-status-check.sh ibm-dv-operator ${OP_NAMESPACE}


# switch to zen namespace
oc project ${NAMESPACE}

# # Install dv Customer Resource


sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g dv-cr.yaml
echo '*** executing **** oc create -f dv-cr.yaml'
result=$(oc create -f dv-cr.yaml)
echo $result

#patch for dmc issue
# sleep 12m
# oc patch -n ibm-common-services sub ibm-dmc-operator --type=merge --patch='{"spec": {"source": "ibm-operator-catalog"}}'


# check the dv cr status
./check-cr-status.sh dvservice dv-service ${NAMESPACE} reconcileStatus
