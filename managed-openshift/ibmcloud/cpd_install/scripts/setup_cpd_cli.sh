#!/bin/bash

SCRIPTS_DIR=$(pwd)

cd $TEMPLATES_DIR

rm -rf cpd-cli*
wget --no-verbose https://github.com/IBM/cpd-cli/releases/download/v3.5.4/cpd-cli-linux-EE-3.5.4.tgz
mkdir -p cpd-cli
tar -xf cpd-cli-linux-*.tgz --directory cpd-cli

cd cpd-cli

# replace repo.yaml
mv repo.yaml repo.yaml.orig
sed -e "s/CPD_REGISTRY_PASSWORD/${CPD_REGISTRY_PASSWORD}/g" ${SCRIPTS_DIR}/repo.yaml > repo.yaml
