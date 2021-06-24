#!/bin/bash

## Create yaml of machinconfigpool for worker 
echo -e "***** DB2 SYSCTL settings modifcations starting *****"
echo -e "***** editing the machineconfigpool worker *****"
oc get mcp worker -o yaml  > mcp-worker.yaml

cp mcp-worker.yaml mcp-worker-backupfile.yaml

sed -i '/\s\slabels\:/a \ \ \ \ db2u-kubelet:\ sysctl' mcp-worker.yaml

## edit the settings. 

oc replace -f mcp-worker.yaml

echo -e "***** applying set sysctl config for mcp worker *****"

cat << EOF | oc apply -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: db2u-kubelet
spec:
  machineConfigPoolSelector:
    matchLabels:
      db2u-kubelet: sysctl
  kubeletConfig:
    allowedUnsafeSysctls:
      - "kernel.msg*"
      - "kernel.shm*"
      - "kernel.sem"
EOF

sleep 60 

echo -e "***** waiting for the nodes to get ready *****"

while true; do
    MASTER_UPDATE_STATUS=$(oc get mcp | grep master | awk '{print $3}')
    WORKER_UPDATE_STATUS=$(oc get mcp | grep worker | awk '{print $3}')
    if [ $MASTER_UPDATE_STATUS == "True" ] && [ $WORKER_UPDATE_STATUS == "True" ]; then
      echo -e "\nAll nodes are running now."
      break
    fi
    echo -e "\nWaiting for nodes ready."
    sleep 120
    done

echo -e "***** DB2 SYSCTL settings completed *****"