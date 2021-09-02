#!/bin/bash

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g wos-sub.yaml

echo '*** executing **** oc create -f wos-sub.yaml'
result=$(oc create -f wos-sub.yaml)
echo $result
sleep 1m

# Checking if the wos operator pods are ready and running. 

./pod-status-check.sh ibm-cpd-wos-operator ${OP_NAMESPACE}


# switch zen namespace
oc project ${NAMESPACE}

# Create WOS CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g wos-cr.yaml
result=$(oc create -f wos-cr.yaml)
echo $result

# check the WOS CR status

./check-cr-status.sh WOService aiopenscale ${NAMESPACE} wosStatus