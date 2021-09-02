#!/bin/bash

oc project ${OP_NAMESPACE}

## Install DS Operator

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g ds-sub.yaml

echo '*** executing **** oc create -f ds-sub.yaml'
result=$(oc create -f ds-sub.yaml)
echo $result
sleep 1m

# Checking if the ds operator pods are ready and running. 	
# checking status of ds-operator	
./pod-status-check.sh datastage-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create ds CR: 	
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g ds-cr.yaml
echo '*** executing **** oc create -f ds-cr.yaml'
result=$(oc create -f ds-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh DataStageService datastage-cr ${NAMESPACE} dsStatus