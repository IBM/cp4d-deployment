#!/bin/sh
set -x

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
runuser -l $SUDOUSER -c "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.8.11/openshift-client-linux-4.8.11.tar.gz"
runuser -l $SUDOUSER -c "sudo tar -xvf openshift-client-linux-*.tar.gz -C /usr/bin"
runuser -l $SUDOUSER -c "rm -f openshift-client-linux-*.tar.gz"
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

cp -rf .kube /home/$SUDOUSER/
chown -R $SUDOUSER:$SUDOUSER /home/$SUDOUSER/.kube
runuser -l $SUDOUSER -c "oc login https://api.${SUBURL}:6443 -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true"
# Create Registry Route
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
  labels:
    db2u-kubelet: sysctl
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

echo "$(date) - ############### Script Complete #############"