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
export CPDTEMPLATES=/mnt/.cpd/templates

runuser -l $SUDOUSER -c "mkdir -p $INSTALLERHOME"
runuser -l $SUDOUSER -c "mkdir -p $OCPTEMPLATES"
runuser -l $SUDOUSER -c "sudo mkdir -p $CPDTEMPLATES"
runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/kubecredentials <<EOF
username: $OPENSHIFTUSER
password: $OPENSHIFTPASSWORD
EOF"

#setup oc and kubectl binaries
runuser -l $SUDOUSER -c "wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.10.15/openshift-client-linux-4.10.15.tar.gz"
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
      version: 3.2.0
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
      version: 3.2.0
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
      version: 3.2.0
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
    aro.openshift.io/limits: \"\"
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
      aro.openshift.io/limits: \"\"
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/kubelet.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-kubelet
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain,%7B%0A%20%20%22kind%22%3A%20%22KubeletConfiguration%22%2C%0A%20%20%22apiVersion%22%3A%20%22kubelet.config.k8s.io%2Fv1beta1%22%2C%0A%20%20%22staticPodPath%22%3A%20%22%2Fetc%2Fkubernetes%2Fmanifests%22%2C%0A%20%20%22syncFrequency%22%3A%20%220s%22%2C%0A%20%20%22fileCheckFrequency%22%3A%20%220s%22%2C%0A%20%20%22httpCheckFrequency%22%3A%20%220s%22%2C%0A%20%20%22tlsCipherSuites%22%3A%20%5B%0A%20%20%20%20%22TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256%22%2C%0A%20%20%20%20%22TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256%22%2C%0A%20%20%20%20%22TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384%22%2C%0A%20%20%20%20%22TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384%22%2C%0A%20%20%20%20%22TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256%22%2C%0A%20%20%20%20%22TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256%22%0A%20%20%5D%2C%0A%20%20%22tlsMinVersion%22%3A%20%22VersionTLS12%22%2C%0A%20%20%22rotateCertificates%22%3A%20true%2C%0A%20%20%22serverTLSBootstrap%22%3A%20true%2C%0A%20%20%22authentication%22%3A%20%7B%0A%20%20%20%20%22x509%22%3A%20%7B%0A%20%20%20%20%20%20%22clientCAFile%22%3A%20%22%2Fetc%2Fkubernetes%2Fkubelet-ca.crt%22%0A%20%20%20%20%7D%2C%0A%20%20%20%20%22webhook%22%3A%20%7B%0A%20%20%20%20%20%20%22cacheTTL%22%3A%20%220s%22%0A%20%20%20%20%7D%2C%0A%20%20%20%20%22anonymous%22%3A%20%7B%0A%20%20%20%20%20%20%22enabled%22%3A%20false%0A%20%20%20%20%7D%0A%20%20%7D%2C%0A%20%20%22authorization%22%3A%20%7B%0A%20%20%20%20%22webhook%22%3A%20%7B%0A%20%20%20%20%20%20%22cacheAuthorizedTTL%22%3A%20%220s%22%2C%0A%20%20%20%20%20%20%22cacheUnauthorizedTTL%22%3A%20%220s%22%0A%20%20%20%20%7D%0A%20%20%7D%2C%0A%20%20%22clusterDomain%22%3A%20%22cluster.local%22%2C%0A%20%20%22clusterDNS%22%3A%20%5B%0A%20%20%20%20%22172.30.0.10%22%0A%20%20%5D%2C%0A%20%20%22streamingConnectionIdleTimeout%22%3A%20%220s%22%2C%0A%20%20%22nodeStatusUpdateFrequency%22%3A%20%220s%22%2C%0A%20%20%22nodeStatusReportFrequency%22%3A%20%220s%22%2C%0A%20%20%22imageMinimumGCAge%22%3A%20%220s%22%2C%0A%20%20%22volumeStatsAggPeriod%22%3A%20%220s%22%2C%0A%20%20%22systemCgroups%22%3A%20%22%2Fsystem.slice%22%2C%0A%20%20%22cgroupRoot%22%3A%20%22%2F%22%2C%0A%20%20%22cgroupDriver%22%3A%20%22systemd%22%2C%0A%20%20%22cpuManagerReconcilePeriod%22%3A%20%220s%22%2C%0A%20%20%22runtimeRequestTimeout%22%3A%20%220s%22%2C%0A%20%20%22maxPods%22%3A%20250%2C%0A%20%20%22kubeAPIQPS%22%3A%2050%2C%0A%20%20%22kubeAPIBurst%22%3A%20100%2C%0A%20%20%22serializeImagePulls%22%3A%20false%2C%0A%20%20%22evictionHard%22%3A%20%7B%0A%20%20%20%20%22imagefs.available%22%3A%20%2215%25%22%2C%0A%20%20%20%20%22memory.available%22%3A%20%22500Mi%22%2C%0A%20%20%20%20%22nodefs.available%22%3A%20%2210%25%22%2C%0A%20%20%20%20%22nodefs.inodesFree%22%3A%20%225%25%22%0A%20%20%7D%2C%0A%20%20%22evictionPressureTransitionPeriod%22%3A%20%220s%22%2C%0A%20%20%22featureGates%22%3A%20%7B%0A%20%20%20%20%22APIPriorityAndFairness%22%3A%20true%2C%0A%20%20%20%20%22DownwardAPIHugePages%22%3A%20true%2C%0A%20%20%20%20%22LegacyNodeRoleBehavior%22%3A%20false%2C%0A%20%20%20%20%22NodeDisruptionExclusion%22%3A%20true%2C%0A%20%20%20%20%22RotateKubeletServerCertificate%22%3A%20true%2C%0A%20%20%20%20%22ServiceNodeExclusion%22%3A%20true%2C%0A%20%20%20%20%22SupportPodPidsLimit%22%3A%20true%0A%20%20%7D%2C%0A%20%20%22containerLogMaxSize%22%3A%20%2250Mi%22%2C%0A%20%20%22systemReserved%22%3A%20%7B%0A%20%20%20%20%22ephemeral-storage%22%3A%20%221Gi%22%0A%20%20%7D%2C%0A%20%20%22allowedUnsafeSysctls%22%3A%20%5B%0A%20%20%20%20%22kernel.msg*%22%2C%0A%20%20%20%20%22kernel.shm*%22%2C%0A%20%20%20%20%22kernel.sem%22%0A%20%20%5D%2C%0A%20%20%22logging%22%3A%20%7B%7D%2C%0A%20%20%22shutdownGracePeriod%22%3A%20%220s%22%2C%0A%20%20%22shutdownGracePeriodCriticalPods%22%3A%20%220s%22%0A%7D%0A
        mode: 420
        overwrite: true
        path: /etc/kubernetes/kubelet.conf
EOF"

runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/sysctl-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/limits-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/crio-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/kubelet.yaml"

runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/sysctl-worker.yaml"
#runuser -l $SUDOUSER -c "oc label machineconfigpool.machineconfiguration.openshift.io worker db2u-kubelet=sysctl"
#runuser -l $SUDOUSER -c "oc patch kubeletconfig aro-limits --type merge -p '{\"spec\":{\"kubeletConfig\":{\"allowedUnsafeSysctls\":[\"kernel.msg*\",\"kernel.shm*\",\"kernel.sem\"]}}}'"
#runuser -l $SUDOUSER -c "oc label mcp worker aro.openshift.io/limits-"


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