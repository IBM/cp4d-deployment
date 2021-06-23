#!/bin/bash

CASE_PACKAGE_NAME=$1
NAMESPACE=$2
GITUSER=$3
GITTOKEN=$4


export CASECTL_RESOLVERS_LOCATION=resolvers.yaml
export CASECTL_RESOLVERS_AUTH_LOCATION=resolversAuth.yaml

mkdir saved
  
cloudctl case save --case ibm-wsl \
    --version 2.0.0-367 \
    --repo https://${GITTOKEN}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev \
    --outputdir ./saved -t 1


oc project ibm-common-services

cloudctl  case launch --case saved/ibm-wsl-2.0.0-367.tgz \
    --tolerance 1 \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory wslSetup \
    --args '--recursive --inputDir ./saved'

cloudctl case launch --case saved/ibm-wsl-2.0.0-367.tgz \
    --tolerance 1 \
    --namespace ibm-common-services \
    --action installOperator \
    --inventory wslSetup \
    --args "--registry cp.stg.icr.io"