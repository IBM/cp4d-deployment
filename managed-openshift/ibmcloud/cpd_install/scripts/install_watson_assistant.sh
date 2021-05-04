#!/bin/bash
NAMESPACE=$1
SCRIPTS_DIR=$(pwd)

# check if logged in
oc whoami || exit $?
oc project $NAMESPACE


cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

sleep 2
oc -n openshift-marketplace get catalogsource opencloud-operators

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: common-service

---
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: common-service
spec:
  targetNamespaces:
  - common-service

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: common-service
spec:
  channel: stable-v1 # dev channel is for development purpose only
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF

sleep 1m
oc get csv -n common-service
oc get crd | grep operandrequest


REGISTRY_USERNAME=$(oc whoami)
REGISTRY_PASSWORD=$(oc whoami -t)
REGISTRY_PREFIX='image-registry.openshift-image-registry.svc:5000'
REGISTRY_ROUTE=$(oc get route -n openshift-image-registry | tail -1 |awk '{print $2}')


cd $TEMPLATES_DIR/cpd-cli
cp $SCRIPTS_DIR/wa-install-override.yaml .


# adm
./cpd-cli adm --repo ./repo.yaml --assembly watson-assistant --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply || exit $?

# edb operator
./cpd-cli install --repo repo.yaml --assembly edb-operator --optional-modules edb-pg-base:x86_64 --namespace $NAMESPACE  --transfer-image-to $REGISTRY_ROUTE/$NAMESPACE --cluster-pull-prefix $REGISTRY_PREFIX/$NAMESPACE --target-registry-username $REGISTRY_USERNAME --target-registry-password=$REGISTRY_PASSWORD --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses || exit $?

# wa operator
./cpd-cli install --repo repo.yaml --assembly watson-assistant-operator --optional-modules watson-assistant-operand-ibm-events-operator:x86_64 --namespace $NAMESPACE --storageclass portworx-watson-assistant-sc --transfer-image-to $REGISTRY_ROUTE/$NAMESPACE --cluster-pull-prefix $REGISTRY_PREFIX/$NAMESPACE --target-registry-username $REGISTRY_USERNAME --target-registry-password=$REGISTRY_PASSWORD --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override wa-install-override.yaml || exit $?

# wa assembly
./cpd-cli install  --repo repo.yaml --assembly watson-assistant --instance wa001 --namespace $NAMESPACE --storageclass portworx-watson-assistant-sc --transfer-image-to $REGISTRY_ROUTE/$NAMESPACE --cluster-pull-prefix $REGISTRY_PREFIX/$NAMESPACE --target-registry-username $REGISTRY_USERNAME --target-registry-password=$REGISTRY_PASSWORD --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override wa-install-override.yaml || exit $?
