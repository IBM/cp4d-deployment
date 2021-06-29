#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2


oc project ibm-common-services

cloudctl  case launch --case ./\${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace openshift-marketplace \
    --action installCatalog \
    --inventory wslSetup 

cloudctl case launch --case ./\${CASE_PACKAGE_NAME} \
    --tolerance 1 \
    --namespace \${NAMESPACE}         \
    --action installOperator \
    --inventory wslSetup 
    # --args "--registry cp.icr.io"
