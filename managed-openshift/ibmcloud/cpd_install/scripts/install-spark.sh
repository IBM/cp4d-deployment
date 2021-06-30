#!/bin/bash


# Case package. 

wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-analyticsengine-4.0.0.tgz

# # Install spark operator using CLI (OLM)
"cat > install-spark-operator.sh <<EOL\n${file("../cpd4_module/install-spark-operator.sh")}\nEOL",
"sudo chmod +x install-spark.sh",

CASE_PACKAGE_NAME="ibm-analyticsengine-4.0.0.tgz"


oc project ${OP_NAMESPACE}
## Install Catalog 

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE}\
    --inventory analyticsengineOperatorSetup \
    --action installCatalog \
    --tolerance 1

## Install Operator

cloudctl case launch --case ${CASE_PACKAGE_NAME} \
    --namespace ${OP_NAMESPACE} \
    --inventory analyticsengineOperatorSetup \
    --action install \
    --tolerance=1

# Checking if the spark operator pods are ready and running. 
# checking status of ibm-cpd-ae-operator
./pod-status-check.sh ibm-cpd-ae-operator ${OP_NAMESPACE}

#switch to zen namespace

oc project ${NAMESPACE}

# Create spark CR: 
sed -i -e s#BUILD_NUMBER#4.0.0#g spark-cr.yaml
echo '*** executing **** oc create -f spark-cr.yaml'
result=$(oc create -f spark-cr.yaml)
echo $result

# check the spark cr status
./check-cr-status.sh AnalyticsEngine analyticsengine-cr ${NAMESPACE} analyticsengineStatus