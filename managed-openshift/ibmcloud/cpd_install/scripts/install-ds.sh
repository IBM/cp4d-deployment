#!/bin/bash

oc project ${NAMESPACE}
oc patch zenservice lite-cr --type merge --patch '{"spec":{"image_digests": {"icp4data_nginx_repo": "sha256:c4124c8e4a9ebe902ae58b612fd4f08b5dd1d1e677cd72b922de227177e0171b", "icpd_requisite": "sha256:6bf10d1c9866595011310b049580368fa9a778e762cc4ed71b4334f09078f426", "influxdb": "sha256:848ef74e5d201470dc6d095ccd2c5c38ccd44b68ae31bc7eae248ad4308e8070", "privatecloud_usermgmt": "sha256:8eec0e953589207ba082a57cb87b6071a1e20c671eb74c6569d6c6da2bb94333", "zen_audit": "sha256:3d1a487933e628e42bc4c1e11422e0428408e9b3e402d9fdc90f1eb44a6aeb06", "zen_core": "sha256:c9dcb0001cfc683cc958e65a059c0a2163fd85c7b23066bf5d14d3e71f3b3b2e", "zen_core_api": "sha256:849d40d8ab78ff76b80bea251c67433c39a308a1e4ddd07b975e078d9b4a2e6f", "zen_data_sorcerer": "sha256:e75f67e2ed56ef578950c5f0a31f8dc5d96962d3b419ccd8d48df10c93149da1", "zen_iam_config": "sha256:dbfc3bce4861b670a7ab31124fac357c0e33f6e7d42bc1ad4b1dc91719d35ed3", "zen_metastoredb": "sha256:c228b0a18c5c0d4c0440820ae911eed896941deccbe07b1a7fd71606f049a6aa", "zen_watchdog": "sha256:acfde984704f140e908dcfd574d1dcb25e62021fa3f80ce64d41c6dbef6a154e"}  }}' -n ${NAMESPACE}

## Install DS Operator

oc project ${OP_NAMESPACE}
sed -i -e s#OPERATOR_NAMESPACE#${OP_NAMESPACE}#g ds-sub.yaml

echo '*** executing **** oc create -f ds-sub.yaml'
result=$(oc create -f ds-sub.yaml)
echo $result
sleep 1m

# Checking if the ds operator pods are ready and running. 	
# checking status of ds-operator	
./pod-status-check.sh datastage-operator ${OP_NAMESPACE}

# switch to zen namespace	
oc project ${NAMESPACE}

# Create ds CR: 	
sed -i -e s#REPLACE_NAMESPACE#${NAMESPACE}#g ds-cr.yaml
echo '*** executing **** oc create -f ds-cr.yaml'
result=$(oc create -f ds-cr.yaml)
echo $result

# check the CCS cr status	
./check-cr-status.sh DataStageService datastage-cr ${NAMESPACE} dsStatus