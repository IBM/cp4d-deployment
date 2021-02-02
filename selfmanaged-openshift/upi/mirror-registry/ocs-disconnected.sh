#! /bin/bash

MIRROR_REGISTRY_DNS=$1
AUTH_FILE="./pull-secret.json"

#Build the catalog for redhat-operators
echo "****************************************"
echo "Build the catalog for redhat-operators"
echo "****************************************"
oc adm catalog build --appregistry-org redhat-operators \
  --from=registry.redhat.io/openshift4/ose-operator-registry:v4.5 \
  --to=${MIRROR_REGISTRY_DNS}/olm/redhat-operators:v1 \
  --registry-config=${AUTH_FILE} \
  --filter-by-os="linux/amd64" --insecure


#Mirror the catalog for redhat-operators
echo "*******************************************************"
echo "Mirror the catalog for redhat-operators"
echo "This is a long operation, will take more then 5 hours"
echo "*******************************************************"
oc adm catalog mirror ${MIRROR_REGISTRY_DNS}/olm/redhat-operators:v1 \
${MIRROR_REGISTRY_DNS} --registry-config=${AUTH_FILE} --insecure

