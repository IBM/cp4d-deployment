#!/bin/bash

# "cat > wsl-catalog-source.yaml <<EOL\n${file("../cpd4_module/wsl-catalog-source.yaml")}\nEOL",
# "cat > wsl-sub.yaml <<EOL\n${file("../cpd4_module/wsl-sub.yaml")}\nEOL",
#cat > wsl-cr.yaml <<EOL\n${file("../cpd4_module/wsl-cr.yaml")}\nEOL

# Download the case package for wsl

#curl -s https://${var.gituser}:${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/local/case-repo-local/ibm-wsl/2.0.0-372/ibm-wsl-2.0.0-372.tgz -o ibm-wsl-2.0.0-372.tgz


# Install wsl operator using CLI (OLM)

./install-wsl-operator.sh ibm-wsl-2.0.0-372.tgz ibm-common-services ${GITUSER} ${GIT_TOKEN}

# Checking if the wsl operator pods are ready and running. 

# checking status of ibm-cpd-ws-operator


# "OPERATOR_POD_NAME=$(oc get pods -n ibm-common-services | grep ibm-cpd-ws-operator | awk '{print $1}')",

./pod-status-check.sh ibm-cpd-ws-operator ibm-common-services

# switch zen namespace

oc project zen

# Create wsl CR: 

result=$(oc create -f wsl-cr.yaml)
echo $result

# check the CCS cr status

./check-cr-status.sh ws ws-cr zen wsStatus

oc get ws ws-cr -o jsonpath="{.status.wsStatus}"