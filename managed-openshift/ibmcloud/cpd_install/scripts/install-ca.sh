#!/bin/bash



# Install ca operator 
oc project ${OP_NAMESPACE}

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g ca-sub.yaml

echo '*** executing **** oc create -f ca-sub.yaml'
result=$(oc create -f ca-sub.yaml)
echo $result
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