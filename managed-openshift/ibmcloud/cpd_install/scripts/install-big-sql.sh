#!/bin/bash


# Install bigsql operator 
oc project ${OP_NAMESPACE}

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g big-sql-sub.yaml

echo '*** executing **** oc create -f big-sql-sub.yaml'
result=$(oc create -f big-sql-sub.yaml)
echo $result
sleep 1m

# Checking if the bigsql operator pods are ready and running. 
# checking status of ibm-bigsql-operator
./pod-status-check.sh ibm-bigsql-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

## Install Custom Resource bigsql 

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g big-sql-cr.yaml
echo '*** executing **** oc create -f big-sql-cr.yaml'
result=$(oc create -f big-sql-cr.yaml)
echo $result

# check the bigsql cr status
./check-cr-status.sh BigsqlService bigsql-service-cr ${NAMESPACE} reconcileStatus