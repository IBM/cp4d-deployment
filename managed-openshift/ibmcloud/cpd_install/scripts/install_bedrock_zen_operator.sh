#!/bin/bash


# Setup global_pull secret 
./setup-global-pull-secret-bedrock.sh ${ENTITLEMENT_USER} ${ENTITLEMENT_KEY}

ibmcloud login --apikey ${IBMCLOUD_APIKEY} -g ${IBMCLOUD_RG_NAME} -r ${REGION}

./roks-update.sh ${CLUSTER_NAME}


# # create bedrock catalog source 

echo '*** executing **** oc create -f bedrock-catalog-source.yaml'

result=$(oc create -f bedrock-catalog-source.yaml)
echo $result
sleep 1m


# Creating the ibm-common-services namespace: 

oc new-project ${OP_NAMESPACE}
oc project ${OP_NAMESPACE}

# Create bedrock operator group: 

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g bedrock-operator-group.yaml

echo '*** executing **** oc create -f bedrock-operator-group.yaml'


result=$(oc create -f bedrock-operator-group.yaml)
echo $result
sleep 1m


# Create bedrock subscription. This will deploy the bedrock: 
sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g bedrock-sub.yaml

echo '*** executing **** oc create -f bedrock-sub.yaml'

result=$(oc create -f bedrock-sub.yaml)
echo $result
sleep 1m


#for reinstall, namespace-scope configmap will be deleted when ibm-common-service-operator first running. need to delete this pod to force recreate Configmap namespace-scope.
while true; do
# local cm_ns_status=$(oc get cm namespace-scope -n ibm-common-services)
cm_ns_status=$(oc get cm namespace-scope -n ${OP_NAMESPACE})
if [[ -n $cm_ns_status ]]; then
  echo "Config Map namespace-scope exist."
  break
fi
sleep 30
oc get pods -n ${OP_NAMESPACE} -l name=ibm-common-service-operator | awk '{print $1}' | grep -Ev NAME | xargs oc delete pods -n ${OP_NAMESPACE}
sleep 30
done


echo "Waiting for Bedrock operator pods ready"
while true; do
pod_status=$(oc get pods -n ${OP_NAMESPACE} | grep -Ev "NAME|1/1|2/2|3/3|5/5|Comp")
if [[ -z $pod_status ]]; then
  echo "All pods are running now"
  break
fi
echo "Waiting for Bedrock operator pods ready"
oc get pods -n ${OP_NAMESPACE}
sleep 30
if [[ `oc get po -n ${OP_NAMESPACE}` =~ "Error" ]]; then
  oc delete `oc get po -o name | grep ibm-common-service-operator`
else
  echo "No pods with Error"
fi
done
  
sleep 60

# Checking if the bedrock operator pods are ready and running. 

# checking status of ibm-namespace-scope-operator

./check-subscription-status.sh ibm-common-service-operator ${OP_NAMESPACE} state
./pod-status-check.sh ibm-namespace-scope-operator ${OP_NAMESPACE}

# checking status of operand-deployment-lifecycle-manager

./pod-status-check.sh operand-deployment-lifecycle-manager ${OP_NAMESPACE}

# checking status of ibm-common-service-operator

./pod-status-check.sh ibm-common-service-operator ${OP_NAMESPACE}

# Creating zen catalog source 

echo '*** executing **** oc create -f zen-catalog-source.yaml'
result=$(oc create -f zen-catalog-source.yaml)
echo $result

sleep 1m

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g cpd-operator-sub.yaml
echo '*** executing **** oc create -f cpd-operator-sub.yaml'
result=$(oc create -f cpd-operator-sub.yaml)
echo $result
sleep 60



# Create zen namespace

oc new-project ${NAMESPACE}
oc project ${NAMESPACE}

# Create the zen operator 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g zen-operandrequest.yaml

echo '*** executing **** oc create -f zen-operandrequest.yaml'
result=$(oc create -f zen-operandrequest.yaml)
echo $result
sleep 30




# Create lite CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g zen-lite-cr.yaml
echo '*** executing **** oc create -f zen-lite-cr.yaml'
result=$(oc create -f zen-lite-cr.yaml)
echo $result

# check if the zen operator pod is up and running.

./pod-status-check.sh ibm-zen-operator ${OP_NAMESPACE}
./pod-status-check.sh ibm-cert-manager-operator ${OP_NAMESPACE}

./pod-status-check.sh cert-manager-cainjector ${OP_NAMESPACE}
./pod-status-check.sh cert-manager-controller ${OP_NAMESPACE}
./pod-status-check.sh cert-manager-webhook ${OP_NAMESPACE}

# check the lite cr status

./check-cr-status.sh ibmcpd ibmcpd-cr ${NAMESPACE} controlPlaneStatus


wget https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz
wget https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz.sig
tar -xvf cloudctl-linux-amd64.tar.gz -C /usr/local/bin
mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl