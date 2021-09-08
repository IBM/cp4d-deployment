#!/bin/bash

# Install db2oltp operator 
oc project ${OP_NAMESPACE}

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g db2oltp-sub.yaml

echo '*** executing **** oc create -f db2oltp-sub.yaml'
result=$(oc create -f db2oltp-sub.yaml)
echo $result
sleep 1m

# Checking if the db2oltp operator podb2oltp are ready and running. 	

./pod-status-check.sh ibm-db2oltp-cp4d-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create db2oltp CR: 	
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g db2oltp-cr.yaml

echo '*** executing **** oc create -f db2oltp-cr.yaml'
result=$(oc create -f db2oltp-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh Db2oltpService db2oltp-cr ${NAMESPACE} db2oltpStatus