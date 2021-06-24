#!/bin/bash

#Create directory

# Copy the required yaml files for wkc setup .. 
cd wkc-files


# Creating the db2 sysctl config shell script.

"cat > sysctl-config-db2.sh <<EOL\n${file("../cpd4_module/sysctl-config-db2.sh")}\nEOL",
"sudo chmod +x sysctl-config-db2.sh",
"./sysctl-config-db2.sh",

# Case package. 
## Db2u Operator 
"curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2uoperator/4.0.0-3731.2361/ibm-db2uoperator-4.0.0-3731.2361.tgz -o ibm-db2uoperator-4.0.0-3731.2361.tgz",

# Case package. 
## Db2asaservice 
"curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-db2aaservice/4.0.0-1228.749/ibm-db2aaservice-4.0.0-1228.749.tgz -o ibm-db2aaservice-4.0.0-1228.749.tgz",


# ## wkc case package 
"curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-wkc/4.0.0-416/ibm-wkc-4.0.0-416.tgz -o ibm-wkc-4.0.0-416.tgz",

# ## IIS case package 
"curl -s https://${var.gittoken}@raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/4.0.0/dev/case-repo-dev/ibm-iis/4.0.0-355/ibm-iis-4.0.0-355.tgz -o ibm-iis-4.0.0-355.tgz",

# # Install db2u operator using CLI (OLM)
"cat > install-db2u-operator.sh <<EOL\n${file("../cpd4_module/install-db2u-operator.sh")}\nEOL",
"sudo chmod +x install-db2u-operator.sh",
"./install-db2u-operator.sh ibm-db2uoperator-4.0.0-3731.2361.tgz ${var.operator-namespace}",

# Checking if the db2u operator pods are ready and running. 
# checking status of db2u-operator
"/home/${var.admin-username}/cpd-common-files/pod-status-check.sh db2u-operator ${var.operator-namespace}",

# # Install db2aaservice operator using CLI (OLM)
"cat > install-db2aaservice-operator.sh <<EOL\n${file("../cpd4_module/install-db2aaservice-operator.sh")}\nEOL",
"sudo chmod +x install-db2aaservice-operator.sh",
"./install-db2aaservice-operator.sh ibm-db2aaservice-4.0.0-1228.749.tgz ${var.operator-namespace}",

# Checking if the db2aaservice operator pods are ready and running. 
# checking status of db2aaservice-operator
"/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-db2aaservice-cp4d-operator-controller-manager ${var.operator-namespace}",

# switch to zen namespace

"oc project ${var.cpd-namespace}",

# Install db2aaservice Customer Resource

"echo '*** executing **** oc create -f db2aaservice-cr.yaml'",
"result=$(oc create -f db2aaservice-cr.yaml)",
"echo $result",

# check the db2aaservice cr status
"/home/${var.admin-username}/cpd-common-files/check-cr-status.sh Db2aaserviceService db2aaservice-cr ${var.cpd-namespace} db2aaserviceStatus",

# # Install wkc operator using CLI (OLM)
"cat > install-wkc-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-operator.sh")}\nEOL",
"sudo chmod +x install-wkc-operator.sh",
"./install-wkc-operator.sh ibm-wkc-4.0.0-416.tgz ${var.operator-namespace}",

# Checking if the wkc operator pods are ready and running. 
# checking status of ibm-wkc-operator
"/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-wkc-operator ${var.operator-namespace}",

# switch to zen namespace

"oc project ${var.cpd-namespace}",

# # Install wkc Customer Resource

"sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-cr.yaml",
"echo '*** executing **** oc create -f wkc-cr.yaml'",
"result=$(oc create -f wkc-cr.yaml)",
"echo $result",

# check the wkc cr status
"/home/${var.admin-username}/cpd-common-files/check-cr-status.sh wkc wkc-cr ${var.cpd-namespace} wkcStatus",

## IIS cr installation 

"sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g /home/${var.admin-username}/wkc-files/wkc-iis-scc.yaml",
"echo '*** executing **** oc create -f wkc-iis-scc.yaml'",
"result=$(oc create -f wkc-iis-scc.yaml)",
"echo $result",

# Install IIS operator using CLI (OLM)

"cat > install-wkc-iis-operator.sh <<EOL\n${file("../cpd4_module/install-wkc-iis-operator.sh")}\nEOL",
"sudo chmod +x install-wkc-iis-operator.sh",
"./install-wkc-iis-operator.sh ibm-iis-4.0.0-355.tgz ${var.operator-namespace}",

# Checking if the wkc iis operator pods are ready and running. 
# checking status of ibm-cpd-iis-operator
"/home/${var.admin-username}/cpd-common-files/pod-status-check.sh ibm-cpd-iis-operator ${var.operator-namespace}",

# switch to zen namespace

"oc project ${var.cpd-namespace}",

# # Install wkc Customer Resource

"sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-iis-cr.yaml",
"sed -i -e s#REPLACE_NAMESPACE#${var.cpd-namespace}#g /home/${var.admin-username}/wkc-files/wkc-iis-cr.yaml",
"echo '*** executing **** oc create -f wkc-iis-cr.yaml'",
"result=$(oc create -f wkc-iis-cr.yaml)",
"echo $result",

# check the wkc cr status
"/home/${var.admin-username}/cpd-common-files/check-cr-status.sh iis iis-cr ${var.cpd-namespace} iisStatus",

# switch to zen namespace

"oc project ${var.cpd-namespace}",

# # Install wkc Customer Resource

"sed -i -e s#REPLACE_STORAGECLASS#${local.cpd-storageclass}#g /home/${var.admin-username}/wkc-files/wkc-ug-cr.yaml",
"echo '*** executing **** oc create -f wkc-ug-cr.yaml'",
"result=$(oc create -f wkc-ug-cr.yaml)",
"echo $result",

# check the wkc cr status
"/home/${var.admin-username}/cpd-common-files/check-cr-status.sh ug ug-cr ${var.cpd-namespace} ugStatus",