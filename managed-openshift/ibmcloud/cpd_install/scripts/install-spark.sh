#!/bin/bash




## Install Operator

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g spark-sub.yaml

echo '*** executing **** oc create -f spark-sub.yaml'
result=$(oc create -f spark-sub.yaml)
echo $result
sleep 1m

# Checking if the spark operator pods are ready and running. 
# checking status of ibm-cpd-ae-operator
./pod-status-check.sh ibm-cpd-ae-operator ${OP_NAMESPACE}

#switch to zen namespace

oc project ${NAMESPACE}

# Create spark CR: 
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g spark-cr.yaml
echo '*** executing **** oc create -f spark-cr.yaml'
result=$(oc create -f spark-cr.yaml)
echo $result

# check the spark cr status
./check-cr-status.sh AnalyticsEngine analyticsengine-cr ${NAMESPACE} analyticsengineStatus