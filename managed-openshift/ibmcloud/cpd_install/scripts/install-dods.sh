#!/bin/bash



# Install dods operator

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g dods-sub.yaml

echo '*** executing **** oc create -f dods-sub.yaml'
result=$(oc create -f dods-sub.yaml)
echo $result
sleep 1m


# Checking if the dods operator pods are ready and running. 
# checking status of ibm-cpd-dods-operator
./pod-status-check.sh ibm-cpd-dods-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# Create dods CR: 
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g dods-cr.yaml
echo '*** executing **** oc create -f dods-cr.yaml'
result=$(oc create -f dods-cr.yaml)
echo $result

# check the CCS cr status
./check-cr-status.sh DODS dods-cr ${NAMESPACE} dodsStatus