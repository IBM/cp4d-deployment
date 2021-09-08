#!/bin/bash



# # Install spss operator 

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g spss-sub.yaml

echo '*** executing **** oc create -f spss-sub.yaml'
result=$(oc create -f spss-sub.yaml)
echo $result
sleep 1m

# Checking if the spss operator pods are ready and running. 
# checking status of ibm-cpd-spss-operator
./pod-status-check.sh ibm-cpd-spss-operator ${OP_NAMESPACE}

# switch to zen namespace
oc project ${NAMESPACE}

# Create spss CR: 
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g spss-cr.yaml
echo '*** executing **** oc create -f spss-cr.yaml'
result=$(oc create -f spss-cr.yaml)
echo $result

# check the CCS cr status
./check-cr-status.sh spss spss-cr ${NAMESPACE} spssmodelerStatus