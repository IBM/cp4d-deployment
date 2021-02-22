#!/bin/bash

APIKEY=$1
MIRROR_REGISTRY=$2
MIRROR_REGISTRY_USER=$3
MIRROR_REGISTRY_PWD=$4
OPT_NAMESPACE=cpd-meta-ops

export PRIVATE_REGISTRY=$MIRROR_REGISTRY
export PRIVATE_REGISTRY_USER=$MIRROR_REGISTRY_USER
export PRIVATE_REGISTRY_PASSWORD=$MIRROR_REGISTRY_PWD
export CPD_REGISTRY=cp.icr.io/cp/cpd
export CPD_REGISTRY_USER=cp
export CPD_REGISTRY_PASSWORD=$APIKEY
export NAMESPACE=$OPT_NAMESPACE

# Authenticate to your external registry from the IBM Cloud Pak CLI.
cloudctl-linux-amd64 case launch                    \
  --case ibm-cp-datacore                            \
  --inventory cpdMetaOperatorSetup                  \
  --action configure-creds-airgap                   \
  --tolerance=1                                     \
  --args "--registry ${PRIVATE_REGISTRY} --user ${PRIVATE_REGISTRY_USER} --pass ${PRIVATE_REGISTRY_PASSWORD}"


# Mirror the Cloud Pak for Data Operator images to your external registry.
cloudctl-linux-amd64 case launch                      \
  --case ibm-cp-datacore                              \
  --inventory cpdMetaOperatorSetup                    \
  --action mirror-images                              \
  --tolerance=1                                       \
  --args "--cpdservices CPDSERVICESLIST --repo ./repo.yaml --registry ${PRIVATE_REGISTRY} --user ${PRIVATE_REGISTRY_USER} --pass ${PRIVATE_REGISTRY_PASSWORD}"


# Enable your air-gapped cluster to access the images in your external registry.
# This command configures your cluster to use your external registry as a mirror of 
# the images that are hosted in the online registries and enables your cluster to access those images. 
cloudctl-linux-amd64 case launch                      \
      --case ibm-cp-datacore                          \
      --namespace ${NAMESPACE}                        \
      --inventory cpdMetaOperatorSetup                \
      --action configure-cluster-airgap               \
      --tolerance=1                                   \
      --args "--secret external-cpd-registry --registry ${PRIVATE_REGISTRY} --user ${PRIVATE_REGISTRY_USER} --pass ${PRIVATE_REGISTRY_PASSWORD}"

# It will take a few minutes for the cluster nodes to be restarted with the new settings.
echo "Sleeping for 12 minutes while the cluster nodes restarts with new settings"
sleep 12m


# Installing the catalog and the Cloud Pak for Data Operator.
cloudctl-linux-amd64 case launch                      \
    --case ibm-cp-datacore                            \
    --namespace ${NAMESPACE}                          \
    --inventory cpdMetaOperatorSetup                  \
    --action install-catalog                          \
    --tolerance=1                                     \
    --args "--registry ${PRIVATE_REGISTRY} --user ${PRIVATE_REGISTRY_USER} --pass ${PRIVATE_REGISTRY_PASSWORD}"

# It will take a few minutes for the Cloud Pak for Data Operator to appear as a custom provider in the Operator Hub Catalog.
echo "Sleeping for 3 minutes for the Cloud Pak for Data Operator to appear as a custom provider in the Operator Hub Catalog"
sleep 3m


#Install the Cloud Pak for Data Operator
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cp-data-operator-cluster-role
    app.kubernetes.io/managed-by: ibm-cp-data-operator
    app.kubernetes.io/name: ibm-cp-data-operator-cluster-role
  name: cpd-meta-ops-operatorgroup
  namespace: cpd-meta-ops
spec:
  serviceAccount:
    metadata:
      creationTimestamp: null
EOF

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    app.kubernetes.io/instance: ibm-cp-data-operator-subscription
    app.kubernetes.io/managed-by: ibm-cp-data-operator
    app.kubernetes.io/name: ibm-cp-data-operator-subscription
  generation: 1
  name: ibm-cp-data-operator
  namespace: cpd-meta-ops
spec:
  channel: v1.0
  installPlanApproval: Automatic
  name: ibm-cp-data-operator
  source: ibm-cp-data-operator-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-cp-data-operator.v1.0.0
EOF

echo "Sleeping for 5 minutes for the Cloud Pak for Data Operator to be in running state"
sleep 5m
