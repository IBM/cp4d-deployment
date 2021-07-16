#!/bin/bash

#Create directory

# Copy the required yaml files for wkc setup .. 
cd wkc-files

# Case package. 

# wkc case package 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-wkc-4.0.0.tgz

# ## IIS case package 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-iis-4.0.0.tgz


CASE_PACKAGE_NAME="ibm-wkc-4.0.0.tgz"

## Install Operator

cloudctl case launch --case  ${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace ${OP_NAMESPACE} \
    --action installOperator \
    --inventory wkcOperatorSetup

# Checking if the wkc operator pods are ready and running. 

./../pod-status-check.sh ibm-cpd-wkc-operator ${OP_NAMESPACE}

# switch to zen namespace

oc project ${NAMESPACE}


# # Install wkc Customer Resource

#sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g wkc-cr.yaml
echo '*** executing **** oc create -f wkc-cr.yaml'
result=$(oc create -f wkc-cr.yaml)
echo $result

while [ "$(oc get sts -n ${NAMESPACE} | grep c-db2oltp-wkc-db2u)" = "" ]; do echo "waiting for c-db2oltp-wkc-db2u statefulset."; sleep 60; done
oc patch sts c-db2oltp-wkc-db2u -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'; echo "patch for c-db2oltp-wkc-db2u is appied."

# check the wkc cr status
./../check-cr-status.sh wkc wkc-cr ${NAMESPACE} wkcStatus

## IIS cr installation 

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-iis-scc.yaml
echo '*** executing **** oc create -f wkc-iis-scc.yaml'
result=$(oc create -f wkc-iis-scc.yaml)
echo $result

# Install IIS operator using CLI (OLM)

CASE_PACKAGE_NAME="ibm-iis-4.0.0.tgz"

## Install Operator

cloudctl case launch --case  ${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace ${OP_NAMESPACE} \
    --action installOperator \
    --inventory iisOperatorSetup

# Checking if the wkc iis operator pods are ready and running. 
# checking status of ibm-cpd-iis-operator
./../pod-status-check.sh ibm-cpd-iis-operator ${OP_NAMESPACE}

# switch to zen namespace

oc project ${NAMESPACE}

# # Install wkc Customer Resource
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-iis-cr.yaml
echo '*** executing **** oc create -f wkc-iis-cr.yaml'
result=$(oc create -f wkc-iis-cr.yaml)
echo $result

while [ "$(oc get sts -n ${NAMESPACE} | grep c-db2oltp-iis-db2u)" = "" ]; do echo "waiting for c-db2oltp-iis-db2u statefulset."; sleep 60; done
oc patch sts c-db2oltp-iis-db2u -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'; echo "patch for c-db2oltp-iis-db2u is appied."


# check the wkc cr status
./../check-cr-status.sh iis iis-cr ${NAMESPACE} iisStatus

# switch to zen namespace

oc project ${NAMESPACE}

# # Install wkc Customer Resource

echo '*** executing **** oc create -f wkc-ug-cr.yaml'
result=$(oc create -f wkc-ug-cr.yaml)
echo $result

# check the wkc cr status
./../check-cr-status.sh ug ug-cr ${NAMESPACE} ugStatus