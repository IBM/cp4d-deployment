#!/bin/bash



# Install wsl operator 

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g wsl-sub.yaml

echo '*** executing **** oc create -f wsl-sub.yaml'
result=$(oc create -f wsl-sub.yaml)
echo $result
sleep 1m


# Checking if the wsl operator pods are ready and running. 

./pod-status-check.sh ibm-cpd-ws-operator ${OP_NAMESPACE}

# switch zen namespace

oc project ${NAMESPACE}

# Create wsl CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g wsl-cr.yaml
result=$(oc create -f wsl-cr.yaml)
echo $result

# check the WSL cr status

./check-cr-status.sh ws ws-cr ${NAMESPACE} wsStatus