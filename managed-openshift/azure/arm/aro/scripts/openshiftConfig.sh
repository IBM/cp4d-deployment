#!/bin/sh
export LOCATION=$1
export DOMAINNAME=$2
export SUDOUSER=$3
export WORKERNODECOUNT=$4
export CPDNAMESPACE=$5
export STORAGEOPTION=$6
export APIKEY=$7
export OPENSHIFTUSER=$8
export OPENSHIFTPASSWORD=$9
export CUSTOMDOMAIN=$10
export CLUSTERNAME=${11}

export INSTALLERHOME=/home/$SUDOUSER/.ibm
export OCPTEMPLATES=/home/$SUDOUSER/.openshift/templates
export CPDTEMPLATES=/home//$SUDOUSER/.cpd/templates

runuser -l $SUDOUSER -c "mkdir -p $INSTALLERHOME"
runuser -l $SUDOUSER -c "mkdir -p $OCPTEMPLATES"
runuser -l $SUDOUSER -c "mkdir -p $CPDTEMPLATES"
runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/kubecredentials <<EOF
username: $OPENSHIFTUSER
password: $OPENSHIFTPASSWORD
EOF"

#setup oc and kubectl binaries
runuser -l $SUDOUSER -c "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.7.18/openshift-client-linux-4.7.18.tar.gz"
runuser -l $SUDOUSER -c "sudo tar -xvf openshift-client-linux-4.7.18.tar.gz -C /usr/bin"
runuser -l $SUDOUSER -c "rm -f openshift-client-linux-4.7.18.tar.gz"
chmod +x /usr/bin/kubectl
chmod +x /usr/bin/oc

# Set url
echo "customdomain=> $CUSTOMDOMAIN"
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
echo "suburl=> $SUBURL"
else
export SUBURL="${DOMAINNAME}.${LOCATION}.aroapp.io"
echo "suburl=> $SUBURL"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

# Create Registry Route
runuser -l $SUDOUSER -c "oc login https://api.${SUBURL}:6443 -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true"
runuser -l $SUDOUSER -c "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true, \"replicas\":$WORKERNODECOUNT}}'"
runuser -l $SUDOUSER -c "sleep 20"
runuser -l $SUDOUSER -c "oc project kube-system"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/sysctl-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 98-master-worker-sysctl
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,a2VybmVsLnNobWFsbCA9IDMzNTU0NDMyCmtlcm5lbC5zaG1tYXggPSA2ODcxOTQ3NjczNgprZXJuZWwuc2htbW5pID0gMzI3NjgKa2VybmVsLnNlbSA9IDI1MCAxMDI0MDAwIDEwMCAzMjc2OAprZXJuZWwubXNnbWF4ID0gNjU1MzYKa2VybmVsLm1zZ21uYiA9IDY1NTM2Cmtlcm5lbC5tc2dtbmkgPSAzMjc2OAp2bS5tYXhfbWFwX2NvdW50ID0gMjYyMTQ0
        filesystem: root
        mode: 0644
        path: /etc/sysctl.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/limits-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 15-security-limits
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,KiAgICAgICAgICAgICAgIGhhcmQgICAgbm9maWxlICAgICAgICAgNjY1NjAKKiAgICAgICAgICAgICAgIHNvZnQgICAgbm9maWxlICAgICAgICAgNjY1NjA=
        filesystem: root
        mode: 0644
        path: /etc/security/limits.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/crio-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-crio
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,W2NyaW9dCltjcmlvLmFwaV0Kc3RyZWFtX2FkZHJlc3MgPSAiIgpzdHJlYW1fcG9ydCA9ICIxMDAxMCIKW2NyaW8ucnVudGltZV0KZGVmYXVsdF91bGltaXRzID0gWwogICAgIm5vZmlsZT02NTUzNjo2NTUzNiIKXQpjb25tb24gPSAiL3Vzci9saWJleGVjL2NyaW8vY29ubW9uIgpjb25tb25fY2dyb3VwID0gInBvZCIKYXBwYXJtb3JfcHJvZmlsZSA9ICJjcmlvLWRlZmF1bHQiCmNncm91cF9tYW5hZ2VyID0gInN5c3RlbWQiCmhvb2tzX2RpciA9IFsKICAgICIvZXRjL2NvbnRhaW5lcnMvb2NpL2hvb2tzLmQiLApdCnBpZHNfbGltaXQgPSAxMjI4OApbY3Jpby5pbWFnZV0KZ2xvYmFsX2F1dGhfZmlsZSA9ICIvdmFyL2xpYi9rdWJlbGV0L2NvbmZpZy5qc29uIgpwYXVzZV9pbWFnZSA9ICJxdWF5LmlvL29wZW5zaGlmdC1yZWxlYXNlLWRldi9vY3AtdjQuMC1hcnQtZGV2QHNoYTI1NjoyZGMzYmRjYjJiMGJmMWQ2YzZhZTc0OWJlMDE2M2U2ZDdjYTgxM2VjZmJhNWU1ZjVkODg5NzBjNzNhOWQxMmE5IgpwYXVzZV9pbWFnZV9hdXRoX2ZpbGUgPSAiL3Zhci9saWIva3ViZWxldC9jb25maWcuanNvbiIKcGF1c2VfY29tbWFuZCA9ICIvdXNyL2Jpbi9wb2QiCltjcmlvLm5ldHdvcmtdCm5ldHdvcmtfZGlyID0gIi9ldGMva3ViZXJuZXRlcy9jbmkvbmV0LmQvIgpwbHVnaW5fZGlycyA9IFsKICAgICIvdmFyL2xpYi9jbmkvYmluIiwKXQpbY3Jpby5tZXRyaWNzXQplbmFibGVfbWV0cmljcyA9IHRydWUKbWV0cmljc19wb3J0ID0gOTUzNw==
        filesystem: root
        mode: 0644
        path: /etc/crio/crio.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/sysctl-worker.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: db2u-kubelet
spec:
  kubeletConfig:
    evictionHard:
      imagefs.available: 15%
      memory.available: 500Mi
      nodefs.available: 10%
      nodefs.inodesFree: 5%
    systemReserved:
      memory: 2000Mi
    allowedUnsafeSysctls:
      - \"kernel.msg*\"
      - \"kernel.shm*\"
      - \"kernel.sem\"
  machineConfigPoolSelector:
    matchLabels:
      db2u-kubelet: sysctl
EOF"

runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/sysctl-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/limits-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/crio-mc.yaml"

runuser -l $SUDOUSER -c "oc label machineconfigpool.machineconfiguration.openshift.io worker db2u-kubelet=sysctl"
runuser -l $SUDOUSER -c "oc label mcp worker aro.openshift.io/limits-"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/sysctl-worker.yaml"

runuser -l $SUDOUSER -c "echo 'Sleeping for 12mins while MCs apply and the cluster restarts' "
runuser -l $SUDOUSER -c "sleep 12m"


runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/set-global-pull-secret.sh <<EOF
#!/bin/bash
ENTITLEMENT_USER=\$1
ENTITLEMENT_KEY=\$2
pull_secret=\$(echo -n \"\$ENTITLEMENT_USER:\$ENTITLEMENT_KEY\" | base64 -w0)
# Retrieve the current global pull secret
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/dockerconfig.json
sed -i -e 's|:{|:{\"cp.icr.io\":{\"auth\":\"'\$pull_secret'\"\},|' /tmp/dockerconfig.json
EOF"

# Check nodestatus if they are ready.
runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/node-status-check.sh <<EOF
while true; do
    node_status=(oc get nodes | grep -E \"SchedulingDisabled|NotReady\")
    if [[ -z node_status ]]; then
        echo -e \"\n******All nodes are running now.******\"
        break
    fi
        echo -e \"\n******Waiting for nodes to get ready.******\"
        oc get nodes --no-headers | awk '{print \$1 " " \$2}'
        echo -e \"\n******sleeping for 60Secs******\"
        sleep 60
    done
EOF"

# #CPD Config

# runuser -l $SUDOUSER -c "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz -O $INSTALLERHOME/cloudctl-linux-amd64.tar.gz"
# runuser -l $SUDOUSER -c "https://github.com/IBM/cloud-pak-cli/releases/download/v3.8.0/cloudctl-linux-amd64.tar.gz.sig -O $INSTALLERHOME/cloudctl-linux-amd64.tar.gz.sig"
# runuser -l $SUDOUSER -c "(cd $INSTALLERHOME && tar -xf cloudctl-linux-amd64.tar.gz)"
# runuser -l $SUDOUSER -c "chmod +x $INSTALLERHOME/cloudctl-linux-amd64"
# runuser -l $SUDOUSER -c "mv $INSTALLERHOME/cloudctl-linux-amd64 /usr/local/bin/cloudctl"

# # Service Account Token for CPD installation
# runuser -l $SUDOUSER -c "oc new-project $NAMESPACE"
# runuser -l $SUDOUSER -c "oc create serviceaccount cpdtoken"
# runuser -l $SUDOUSER -c "oc policy add-role-to-user admin system:serviceaccount:$NAMESPACE:cpdtoken"

# ## Installing jq
# runuser -l $SUDOUSER -c "wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O  $INSTALLERHOME/jq"
# runuser -l $SUDOUSER -c "sudo mv  $INSTALLERHOME/jq /usr/local/bin"
# runuser -l $SUDOUSER -c "sudo chmod +x /usr/local/bin/jq"

# # Update global pull secret: 

# export ENTITLEMENT_USER=cp
# export ENTITLEMENT_KEY=$APIKEY

# pull_secret=(echo -n "ENTITLEMENT_USER:ENTITLEMENT_KEY" | base64 -w0)
# # Retrieve the current global pull secret
# oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/dockerconfig.json
# sed -i -e 's|:{|:{"cp.icr.io":{"auth":"'$pull_secret'"\},|' /tmp/dockerconfig.json
# oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/dockerconfig.json

# sleep 3m

# # Check nodestatus if they are ready.

# while true; do
#     node_status=(oc get nodes | grep -E "SchedulingDisabled|NotReady")
#     if [[ -z node_status ]]; then
#         echo -e "\n******All nodes are running now.******"
#         break
#     fi
#         echo -e "\n******Waiting for nodes to get ready.******"
#         oc get nodes --no-headers | awk '{print 1 " " 2}'
#         echo -e "\n******sleeping for 60Secs******"
#         sleep 60
#     done


# # CPD commonfiles

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/pod-status-check.sh <<EOF
# #!/bin/bash
# podname=\$1
# namespace=\$2
# status=\"unknown\"
# while [ \"\$status\" != \"Running\" ]
# do
#   pod_name=\$(oc get pods -n \$namespace | grep \$podname | awk '{print \$1}' )
#   ready_status=\$(oc get pods -n \$namespace \$pod_name  --no-headers | awk '{print \$2}')
#   pod_status=\$(oc get pods -n \$namespace \$pod_name --no-headers | awk '{print \$3}')
#   echo \$pod_name State - \$ready_status, podstatus - \$pod_status
#   if [ \"\$ready_status\" == \"1/1\" ] && [ \"\$pod_status\" == \"Running\" ]
#   then 
#   status=\"Running\"
#   else
#   status=\"starting\"
#   sleep 10 
#   fi
#   echo \"\$pod_name is \$status\"
# done
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/check-subscription-status.sh <<EOF
# #!/bin/bash

# SUBSCRIPTION=\$1
# NAMESPACE=\$2
# SUBSCRIPTION_STATUS=\$3
# STATUS=\$(oc get subscription \$SUBSCRIPTION -n \$NAMESPACE -o json | jq .status.\$SUBSCRIPTION_STATUS | xargs) 

# while  [[ ! \$STATUS =~ ^(AtLatestKnown)\$ ]]; do
#     echo \"\$SUBSCRIPTION subscription is Installing!!!!\"
#     sleep 60 
#     STATUS=\$(oc get subscription \$SUBSCRIPTION -n \$NAMESPACE -o json | jq .status.\$SUBSCRIPTION_STATUS | xargs) 
#     if [ \"\$STATUS\" == \"Failed\" ]
#     then
#         echo \"**********************************\"
#         echo \"\$SUBSCRIPTION Failed!!!!\"
#         echo \"**********************************\"
#         exit
#     fi
# done 
# echo \"*************************************\"
# echo \"\$SUBSCRIPTION Finished!!!!\"
# echo \"*************************************\"

# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/check-cr-status.sh <<EOF
# #!/bin/bash
# SERVICE=\$1
# CRNAME=\$2
# NAMESPACE=\$3
# SERVICE_STATUS=\$4
# STATUS=\$(oc get \$SERVICE \$CRNAME -n \$NAMESPACE -o json | jq .status.\$SERVICE_STATUS | xargs) 

# while  [[ ! \$STATUS =~ ^(Completed|Complete)\$ ]]; do
#     echo \"\$CRNAME is Installing!!!!\"
#     sleep 60 
#     STATUS=\$(oc get \$SERVICE \$CRNAME -n \$NAMESPACE -o json | jq .status.\$SERVICE_STATUS | xargs) 
#     if [ \"\$STATUS\" == \"Failed\" ]
#     then
#         echo \"**********************************\"
#         echo \"\$CRNAME Installation Failed!!!!\"
#         echo \"**********************************\"
#         exit
#     fi
# done 
# echo \"*************************************\"
# echo \"\$CRNAME Installation Finished!!!!\"
# echo \"*************************************\"

# EOF"


# # CPD Bedrock and Platform operator install: 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-operator-catalogsource.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: CatalogSource
# metadata:
#   name: ibm-operator-catalog
#   namespace: openshift-marketplace
# spec:
#   displayName: \"IBM Operator Catalog\" 
#   publisher: IBM
#   sourceType: grpc
#   image: icr.io/cpopen/ibm-operator-catalog:latest
#   updateStrategy:
#     registryPoll:
#       interval: 45m
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-operator-og.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha2
# kind: OperatorGroup
# metadata:
#   name: operatorgroup
#   namespace: ibm-common-services
# spec:
#   targetNamespaces:
#   - ibm-common-services
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibm-operator-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: ibm-common-service-operator
#   namespace: ibm-common-services
# spec:
#   channel: v3
#   installPlanApproval: Automatic
#   name: ibm-common-service-operator
#   source: ibm-operator-catalog
#   sourceNamespace: openshift-marketplace
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/cpd-platform-operator-sub.yaml <<EOF
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   name: cpd-operator
#   namespace: ibm-common-services    # The project that contains the Cloud Pak for Data operator
# spec:
#   channel: stable-v1
#   installPlanApproval: Automatic
#   name: cpd-platform-operator
#   source: ibm-operator-catalog
#   sourceNamespace: openshift-marketplace
# EOF"

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/cpd-platform-operator-operandrequest.yaml <<EOF
# apiVersion: operator.ibm.com/v1alpha1
# kind: OperandRequest
# metadata:
#   name: empty-request
#   namespace: zen        # Replace with the project where you will install Cloud Pak for Data
# spec:
#   requests: []
# EOF"


# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-operator-catalogsource.yaml"
# runuser -l $SUDOUSER -c "chmod u+x $CPDTEMPLATES/pod-status-check.sh; $CPDTEMPLATES/pod-status-check.sh ibm-operator-catalog openshift-marketplace "
# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-operator-og.yaml"
# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/ibm-operator-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"
# runuser -l $SUDOUSER -c "chmod u+x $CPDTEMPLATES/check-subscription-status.sh; $CPDTEMPLATES/check-subscription-status.sh ibm-common-service-operator $OPERATORNAMESPACE state"

# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh ibm-namespace-scope-operator $OPERATORNAMESPACE "
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh ibm-common-service-operator $OPERATORNAMESPACE"
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh operand-deployment-lifecycle-manager $OPERATORNAMESPACE"

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/cpd-platform-operator-sub.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"

# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh cpd-platform-operator-manager $OPERATORNAMESPACE"

# runuser -l $SUDOUSER -c "oc create -f $CPDTEMPLATES/cpd-platform-operator-operandrequest.yaml"
# runuser -l $SUDOUSER -c "echo 'Sleeping for 2m' "
# runuser -l $SUDOUSER -c "sleep 2m"

# # Install Lite-cr 

# runuser -l $SUDOUSER -c "cat > $CPDTEMPLATES/ibmcpd-cr.yaml <<EOF
# apiVersion: cpd.ibm.com/v1
# kind: Ibmcpd
# metadata:
#   name: ibmcpd-cr                                         # This is the recommended name, but you can change it
#   namespace: \${NAMESPACE}                                 # Replace with the project where you will install Cloud Pak for Data
# spec:
#   license:
#     accept: true
#     license: Enterprise                                   # Specify the Cloud Pak for Data license you purchased
#   storageClass: \"REPLACE_STORAGECLASS\"                    # Replace with the name of a RWX storage class
#   zenCoreMetadbStorageClass: \"REPLACE_STORAGECLASS\"       # (Recommended) Replace with the name of a RWO storage class
#   version: \"4.0.1\"
# EOF"

# runuser -l $SUDOUSER -c "oc project $CPDNAMESPACE; oc create -f $CPDTEMPLATES/ibmcpd-cr.yaml"

# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh ibm-zen-operator $OPERATORNAMESPACE"
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh ibm-cert-manager-operator $OPERATORNAMESPACE"
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh cert-manager-cainjector $OPERATORNAMESPACE"
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh cert-manager-controller $OPERATORNAMESPACE"
# runuser -l $SUDOUSER -c "$CPDTEMPLATES/pod-status-check.sh cert-manager-webhook $OPERATORNAMESPACE"

# runuser -l $SUDOUSER -c "$CPDTEMPLATES/check-cr-status.sh ibmcpd ibmcpd-cr $CPDNAMESPACE controlPlaneStatus"


echo "$(date) - ############### Script Complete #############"