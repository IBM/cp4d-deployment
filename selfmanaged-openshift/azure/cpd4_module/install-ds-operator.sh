#!/bin/bash

CASE_PACKAGE_NAME=\$1
NAMESPACE=\$2

oc project \${NAMESPACE}

## Install Operator

cloudctl case launch --action installOperator \
--case \${CASE_PACKAGE_NAME} \
--inventory datastageOperatorSetup \
--namespace \${NAMESPACE} \
--tolerance 1

sleep 1m
