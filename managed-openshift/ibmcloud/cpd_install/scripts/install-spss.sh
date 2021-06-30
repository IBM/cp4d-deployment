#!/bin/bash

"cat > spss-cr.yaml <<EOL\n${file("../cpd4_module/spss-cr.yaml")}\nEOL",

# Case package. 
wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-spss-1.0.0.tgz

# # Install spss operator using CLI (OLM)
CASE_PACKAGE_NAME="ibm-spss-1.0.0.tgz"

cloudctl case launch --tolerance 1 --case ./${CASE_PACKAGE_NAME} \
   --namespace ${OP_NAMESPACE}  \
   --inventory spssSetup  \
   --action installCatalog

cloudctl case launch --tolerance 1 --case ./${CASE_PACKAGE_NAME} \
   --namespace ${OP_NAMESPACE}  \
   --action installOperator \
   --inventory spssSetup  
   # --args "--registry cp.icr.io"


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