#!/bin/bash


# Setup global_pull secret 

./setup-global-pull-secret-bedrock.sh ${ENTITLEMENT_USER} ${ENTITLEMENT_KEY}

ibmcloud login --apikey ${IBMCLOUD_APIKEY} -g ${IBMCLOUD_RG_NAME} -r ${REGION}


./roks-update.sh ${CLUSTER_NAME}


# # create bedrock catalog source 

echo '*** executing **** oc create -f bedrock-catalog-source.yaml'

result=$(oc create -f ibm-op-catalog-source.yaml)
echo $result
sleep 1m

echo '*** executing **** oc create -f db2u-op-catalog.yaml'

result=$(oc create -f db2u-op-catalog.yaml)
echo $result

sleep 30

while true; do
if oc get catalogsource -n openshift-marketplace | grep ibm-operator-catalog >/dev/null 2>&1; then
  echo -e "\nIBM Operator Catalog was successfully created."
  break
fi
sleep 10
done
  
while true; do
if oc get catalogsource -n openshift-marketplace | grep ibm-db2uoperator-catalog >/dev/null 2>&1; then
  echo -e "\nIBM Db2U Catalog was successfully created."
  break
fi
sleep 10
done

  
# Creating the ibm-common-services namespace: 

oc new-project ${OP_NAMESPACE}
oc project ${OP_NAMESPACE}

# Create bedrock operator group: 

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g bedrock-operator-group.yaml

echo '*** executing **** oc create -f bedrock-operator-group.yaml'

result=$(oc create -f bedrock-operator-group.yaml)
echo $result
sleep 1m


#oc patch NamespaceScope common-service -n ibm-common-services --type=merge --patch='{"spec": {"csvInjector": {"enable": true} } }'

sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g cpd-operator-sub.yaml
echo '*** executing **** oc create -f cpd-operator-sub.yaml'
result=$(oc create -f cpd-operator-sub.yaml)
echo $result
sleep 60


while true; do
if oc get sub -n ${OP_NAMESPACE} cpd-operator -o jsonpath='{.status.installedCSV} {"\n"}' | grep cpd-platform-operator.v2.0.3 >/dev/null 2>&1; then
  echo -e "\ncpd-platform-operator.v2.0.3 was successfully created."
  break
fi
sleep 10
done

while true; do
if oc get csv -n ${OP_NAMESPACE} cpd-platform-operator.v2.0.3 -o jsonpath='{ .status.phase } : { .status.message} {"\n"}' | grep "Succeeded : install strategy completed with no errors" >/dev/null 2>&1; then
  echo -e "\nInstall strategy completed with no errors"
  break
fi
sleep 10
done

while true; do
if oc get deployments -n ${OP_NAMESPACE} -l olm.owner="cpd-platform-operator.v2.0.3" -o jsonpath="{.items[0].status.availableReplicas} {'\n'}" | grep 1 >/dev/null 2>&1; then
  echo -e "\ncpd-platform-operator.v2.0.3 is ready."
  break
fi
sleep 10
done

while true; do
if oc get pods -n ${OP_NAMESPACE} | grep ibm-namespace-scope-operator >/dev/null 2>&1; then
  echo -e "\nibm-namespace-scope-operator pods running"
  break
fi
sleep 10
done

while true; do
if oc get pods -n ${OP_NAMESPACE} | grep cpd-platform-operator-manager >/dev/null 2>&1; then
  echo -e "\ncpd-platform-operator-manager pods running"
  break
fi
sleep 10
done


#for reinstall, namespace-scope configmap will be deleted when ibm-common-service-operator first running. need to delete this pod to force recreate Configmap namespace-scope.
while true; do
# local cm_ns_status=$(oc get cm namespace-scope -n ibm-common-services)
cm_ns_status=$(oc get cm namespace-scope -n $OP_NAMESPACE)
if [[ -n $cm_ns_status ]]; then
  echo "Config Map namespace-scope exist."
  break
fi
sleep 30
oc get pods -n ${OP_NAMESPACE} -l name=ibm-common-service-operator | awk '{print $1}' | grep -Ev NAME | xargs oc delete pods -n $OP_NAMESPACE
sleep 30
done

sleep 60


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

./check-subscription-status.sh cpd-operator ${OP_NAMESPACE} state
./pod-status-check.sh cpd-platform-operator-manager ${OP_NAMESPACE}

./pod-status-check.sh ibm-namespace-scope-operator ${OP_NAMESPACE}

# checking status of operand-deployment-lifecycle-manager

./pod-status-check.sh operand-deployment-lifecycle-manager ${OP_NAMESPACE}

# checking status of ibm-common-service-operator

./pod-status-check.sh ibm-common-service-operator ${OP_NAMESPACE}



# Create zen namespace

oc new-project ${NAMESPACE}
oc project ${NAMESPACE}

# Create the zen operator 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g cpd-operandrequest.yaml

echo '*** executing **** oc create -f cpd-operandrequest.yaml'
result=$(oc create -f cpd-operandrequest.yaml)
echo $result
sleep 30




# Create lite CR: 
sed -i -e s#CPD_NAMESPACE#${NAMESPACE}#g ibmcpd-cr.yaml
echo '*** executing **** oc create -f ibmcpd-cr.yaml'
result=$(oc create -f ibmcpd-cr.yaml)
echo $result

# check if the zen operator pod is up and running.

./pod-status-check.sh ibm-zen-operator ${OP_NAMESPACE}
./pod-status-check.sh ibm-cert-manager-operator ${OP_NAMESPACE}

./pod-status-check.sh cert-manager-cainjector ${OP_NAMESPACE}
./pod-status-check.sh cert-manager-controller ${OP_NAMESPACE}
./pod-status-check.sh cert-manager-webhook ${OP_NAMESPACE}

# check the lite cr status

./check-cr-status.sh ibmcpd ibmcpd-cr ${NAMESPACE} controlPlaneStatus