#!/bin/bash

#cat > wml-cr.yaml <<EOL\n${file("../cpd4_module/wml-cr.yaml")}\nEOL

# Case package. 
### Currently the case package is in ibm internal site. Hence downloading it and keeping it as part of the repo.

# "curl -s https://${var.gituser-short}:${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wml/1.0.0-153/ibm-wml-1.0.0-153.tgz -o ibm-wml-1.0.0-153.tgz",


###### If CCS is installed already , the ccs catalog source would be already created. 
###### If not we need to create CCS catalog source as the first step before we proceed here. 
######

# # Install wml operator using CLI (OLM)


./install-wml-operator.sh ibm-wml-cpd-4.0.0-1486.tgz ibm-common-services

# Checking if the wml operator pods are ready and running. 

# checking status of ibm-watson-wml-operator

./pod-status-check.sh ibm-cpd-wml-operator ibm-common-services

# switch zen namespace

oc project zen

# Create wml CR: 

echo '*** executing **** oc create -f wml-cr.yaml'
result=$(oc create -f wml-cr.yaml)
echo $result

# check the WML cr status

./check-cr-status.sh WmlBase wml-cr zen wmlStatus