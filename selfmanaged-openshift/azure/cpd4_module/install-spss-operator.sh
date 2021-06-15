#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

cloudctl case launch --tolerance 1 --case ./\${CASE_PACKAGE_NAME} \
   --namespace \${NAMESPACE}  \
   --inventory spssSetup  \
   --action installCatalog

cloudctl case launch --tolerance 1 --case ./\${CASE_PACKAGE_NAME} \
   --namespace \${NAMESPACE}  \
   --action installOperator \
   --inventory spssSetup  \
   --args "--registry cp.stg.icr.io"

