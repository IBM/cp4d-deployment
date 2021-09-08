#!/bin/bash

#Create directory

# Copy the required yaml files for wkc setup .. 
cd wkc-files

## Install WKC Operator
oc project ${OP_NAMESPACE}

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g wkc-sub.yaml

echo '*** executing **** oc create -f wkc-sub.yaml'
result=$(oc create -f wkc-sub.yaml)
echo $result
sleep 1m

# Checking if the wkc operator pods are ready and running. 

./../pod-status-check.sh ibm-cpd-wkc-operator ${OP_NAMESPACE}

# switch to zen namespace

oc project ${NAMESPACE}

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-iis-scc.yaml
echo '*** executing **** oc create -f wkc-iis-scc.yaml'
result=$(oc create -f wkc-iis-scc.yaml)
echo $result

# # Install wkc Customer Resource

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-cr.yaml
echo '*** executing **** oc create -f wkc-cr.yaml'
result=$(oc create -f wkc-cr.yaml)
echo $result

# check the wkc cr status
./../check-cr-status.sh wkc wkc-cr ${NAMESPACE} wkcStatus

# check the iis cr status
./../check-cr-status.sh iis iis-cr ${NAMESPACE} iisStatus

# check the ug cr status
./../check-cr-status.sh ug ug-cr ${NAMESPACE} ugStatus