#!/bin/bash


# Install db2wh operator 
oc project ${OP_NAMESPACE}

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g db2wh-sub.yaml

echo '*** executing **** oc create -f db2wh-sub.yaml'
result=$(oc create -f db2wh-sub.yaml)
echo $result
sleep 1m


# Checking if the db2wh operator podb2wh are ready and running. 	

./pod-status-check.sh ibm-db2wh-cp4d-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create db2wh CR: 	
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g db2wh-cr.yaml

echo '*** executing **** oc create -f db2wh-cr.yaml'
result=$(oc create -f db2wh-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh db2whService db2wh-cr ${NAMESPACE} db2whStatus