#!/bin/bash

# Case package. 

curl -s https://${GITUSER_SHORT}:${GIT_TOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-watson-openscale/2.0.0-190/ibm-watson-openscale-2.0.0-190.tgz -o ibm-watson-openscale-2.0.0-190.tgz


# Install OpenScale operator using CLI (OLM)

./install-openscale-operator.sh ibm-watson-openscale-2.0.0-190.tgz ibm-common-services

# Checking if the openscale operator pods are ready and running. 

# checking status of ibm-watson-openscale-operator

./pod-status-check.sh ibm-watson-openscale-operator ibm-common-services

# switch zen namespace

oc project zen

# Create openscale CR: 

echo '*** executing **** oc create -f openscale-cr.yaml'
result=$(oc create -f openscale-cr.yaml)
echo $result

# check the CCS cr status

./check-cr-status.sh WOService aiopenscale zen wosStatus