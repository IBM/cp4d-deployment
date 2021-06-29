#!/bin/bash

#go to directory

cd dv-files

# Case package. 

## DMC Operator 
curl -s https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dmc/4.0.0/ibm-dmc-4.0.0.tgz -o ibm-dmc-4.0.0.tgz

## DV case 
curl -s https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-dv-case-1.7.0.tgz -o ibm-dv-case-1.7.0.tgz


# # Install db2u operator using CLI (OLM)
# "cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
# "sudo chmod +x install-db2u-operator.sh",
# "./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ${var.operator-namespace}",

# Checking if the DB2U operator pods are ready and running. 
# checking status of db2u-operator


# # Install dmc operator using CLI (OLM)

#./install-dmc-operator.sh ibm-dmc-4.0.0.tgz ibm-common-services

# Checking if the dmc operator pods are ready and running. 
# checking status of dmc-operator
./../pod-status-check.sh ibm-dmc-controller ibm-common-services

# # Install dv operator using CLI (OLM)

#./install-dv-operator.sh ibm-dv-case-1.7.0.tgz ibm-common-services

# Checking if the dv operator pods are ready and running. 
# checking status of ibm-dv-operator
./../pod-status-check.sh ibm-dv-operator ibm-common-services

# switch to zen namespace
oc project ${NAMESPACE}

# # Install dv Customer Resource

./install-dv-cr.sh ibm-dv-case-1.7.0.tgz ${NAMESPACE}

# check the dv cr status
./../check-cr-status.sh dvservice dv-service ${NAMESPACE} reconcileStatus
