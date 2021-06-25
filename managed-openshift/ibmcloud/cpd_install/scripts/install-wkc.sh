#!/bin/bash

#Create directory

# Copy the required yaml files for wkc setup .. 
cd wkc-files


# Case package. 
## Db2u Operator 
curl -s https://${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2361/ibm-db2uoperator-4.0.0-3731.2361.tgz -o ibm-db2uoperator-4.0.0-3731.2361.tgz

# Case package. 
## Db2asaservice 
curl -s https://${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2aaservice/4.0.0-1228.749/ibm-db2aaservice-4.0.0-1228.749.tgz -o ibm-db2aaservice-4.0.0-1228.749.tgz

# ## wkc case package 
curl -s https://${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wkc/4.0.0-423/ibm-wkc-4.0.0-423.tgz -o ibm-wkc-4.0.0-423.tgz

# ## IIS case package 
curl -s https://${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-iis/4.0.0-359/ibm-iis-4.0.0-359.tgz -o ibm-iis-4.0.0-359.tgz

# # Install db2u operator using CLI (OLM)

./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ibm-common-services

# Checking if the db2u operator pods are ready and running. 
# checking status of db2u-operator

./../pod-status-check.sh db2u-operator ibm-common-services

# # Install db2aaservice operator using CLI (OLM)

./install-db2aaservice-operator.sh ibm-db2aaservice-4.0.0-1228.749.tgz ibm-common-services

# Checking if the db2aaservice operator pods are ready and running. 
# checking status of db2aaservice-operator

./../pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ibm-common-services

# switch to zen namespace

oc project zen

# Install db2aaservice Customer Resource

echo '*** executing **** oc create -f db2aaservice-cr.yaml'
result=$(oc create -f db2aaservice-cr.yaml)
echo $result

# check the db2aaservice cr status
./../check-cr-status.sh Db2aaserviceService db2aaservice-cr zen db2aaserviceStatus

# # Install wkc operator using CLI (OLM)

./install-wkc-operator.sh ibm-wkc-4.0.0-423.tgz ibm-common-services

# Checking if the wkc operator pods are ready and running. 
# checking status of ibm-wkc-operator
./../pod-status-check.sh ibm-cpd-wkc-operator ibm-common-services

# switch to zen namespace

oc project zen

# # Install wkc Customer Resource

#sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g wkc-cr.yaml
echo '*** executing **** oc create -f wkc-cr.yaml'
result=$(oc create -f wkc-cr.yaml)
echo $result

# check the wkc cr status
./../check-cr-status.sh wkc wkc-cr zen wkcStatus

## IIS cr installation 

sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-iis-scc.yaml
echo '*** executing **** oc create -f wkc-iis-scc.yaml'
result=$(oc create -f wkc-iis-scc.yaml)
echo $result

# Install IIS operator using CLI (OLM)

./install-wkc-iis-operator.sh ibm-iis-4.0.0-359.tgz ibm-common-services

# Checking if the wkc iis operator pods are ready and running. 
# checking status of ibm-cpd-iis-operator
./../pod-status-check.sh ibm-cpd-iis-operator ibm-common-services

# switch to zen namespace

oc project ${NAMESPACE}

# # Install wkc Customer Resource
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g wkc-iis-cr.yaml
echo '*** executing **** oc create -f wkc-iis-cr.yaml'
result=$(oc create -f wkc-iis-cr.yaml)
echo $result

# check the wkc cr status
./../check-cr-status.sh iis iis-cr ${NAMESPACE} iisStatus

# switch to zen namespace

oc project zen

# # Install wkc Customer Resource

echo '*** executing **** oc create -f wkc-ug-cr.yaml'
result=$(oc create -f wkc-ug-cr.yaml)
echo $result

# check the wkc cr status
./../check-cr-status.sh ug ug-cr ${NAMESPACE} ugStatus