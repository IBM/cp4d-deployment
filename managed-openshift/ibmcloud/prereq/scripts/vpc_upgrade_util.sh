#!/bin/bash

# Usage: vpc_upgrade_util.sh  clustername  command_name  workerids
#example : ./vpc_upgrade_util.sh  mycluster  replace/upgrade  worker/worker-pool (workerid1 workerid2) / (worker-pool-id1 worker-pool-id2) ....
# If the worker ids not provided then all the workers in the cluster will be replaced/upgraded
#
shopt -s expand_aliases
alias ic="ibmcloud"

CLUSTER=$1

[[ -z "$1" ]] && { echo "Cluster name is empty, specify a cluster name."; exit; }
[[ -z "$2" ]] && { echo "Command name is empty. specify the command"; exit; }
vol_ids=()

if [[ "$2" == "replace" || $2 == "upgrade" ]] ; then
       command_name=$2
else
        echo "Usage: vpc_upgrade_util.sh  clustername command_name  workerid1 workerid2 ......"
        exit 1
fi

  if [[ "$3" == "worker" || $3 == "worker-pool" ]] ; then
    if [ $#  -gt 3 ]; then
      for ((argindex=4,index=0; argindex<=$#; argindex++,index++)); do
	    if [[  $3 == "worker-pool" ]] ; then
	      WORKER_IDS[index]=$(ic cs workers --cluster $CLUSTER --worker-pool ${!argindex} --json | jq -r '.[] | .id')
	      len=${#WORKER_IDS[@]}
	      index=$(( len + index ))
	    else
              WORKER_IDS[index]=${!argindex}
	      ((index++))
	    fi
      done
    else
       echo "Usage: vpc_upgrade_util.sh  clustername command_name  workerid1 workerid2 ......"
       exit 1
    fi
  else
     echo "Worker ids/worker pools  are not specified upgrade/replace done for all workers"
     WORKER_IDS=$(ic cs workers --cluster $CLUSTER  --json | jq -r '.[] | .id')
  fi

echo "worker ids = ${WORKER_IDS[*]}"

##Check JQ is intalled ot not 

if ! which jq &>/dev/null
then
        echo "Jq is not installed... exiting"
	exit 1
fi

##Check ibmcloud instaled or not
if ! which ibmcloud &>/dev/null
then
        echo "IBM Cloud is not installed. Please install ibmcloud..... exiting"
	exit 1
fi

px_label_check=""




CLUSTER_CHECK=$(kubectl -n kube-system get cm cluster-info -o jsonpath='{.data.cluster-config\.json}' | jq -r '.name')
echo "${CLUSTER_CHECK}"
[[ -z "$CLUSTER_CHECK" ]] && { echo "Unable to determine cluster name, Either the cluser does not exist or kube config is not set."; exit; }

echo "Gathering information for cluster ${CLUSTER} ..."
VPC_ID=$(ic cs cluster get --cluster $CLUSTER --json | jq -r '.vpcs[0]')
CLUSTER_ID=$(ic cs cluster get --cluster ${CLUSTER} --json | jq -r '.id')
JOB_COMMAND="/bin/systemctl restart  portworx;sleep 60"
provisioning_worker_id=0


waitforthenode () {

DESIREDSTATE="deployed"
ACTUALSTATE=""
LIMIT=90
SLEEP_TIME=60

   ALLREADY=0
   repeat=0

   worker_id=$1
   repeat=0

   while [ $repeat -lt $LIMIT ] && [ "$ACTUALSTATE" != "$DESIREDSTATE" ]; do
      ACTUALSTATE=$(ic cs worker get --cluster   $CLUSTER  --worker $worker_id --json  | jq -r .lifecycle.actualState)
      DESIREDSTATE=$(ic cs worker get --cluster   $CLUSTER  --worker $worker_id --json  | jq -r .lifecycle.desiredState)
      worker_ip=$(ic cs worker get --cluster   $CLUSTER  --worker $worker_id --json  | jq -r .[] | .ipAddress)
      if [[ $ACTUALSTATE == "Deployed" ]]; then
            echo "New worker Upgrade/Replace  is done and All worker nodes are in ready state...."
            if [ ! -z "${px_label_check}" ]; then
               echo "Worker is  labled to restrict PX pods"
	       kubectl label node $worker_ip px/enabled=false
             fi
       else
         echo "The new  worker: $worker_id still in proviisoning state.... waiting for new worker provision to complete"
      fi
      sleep $SLEEP_TIME
      repeat=$(( $repeat + 1 ))
    done 
}

restartPortworxService () {
   NAMESPACE="ibm-system"
   WORKER_IP=$1
   echo " Restarting the Portworx Service on worker node $WORKER_IP"
   JOB_NAME=$(LC_CTYPE=C cat /dev/urandom | base64 | tr -dc a-z0-9 | fold -w 32 | head -n 1)
   (cat << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: runon-shell
spec:
  template:
    spec:
      tolerations:
        - operator: "Exists"
      nodeSelector:
        kubernetes.io/hostname:  $WORKER_IP
      containers:
        - name: runon
          image: "alpine:3.10"
          command:
            - sh
            - -c
            - nsenter -t 1 -m -u -i -n -p  -- bash -c "${JOB_COMMAND}"
          securityContext:
            privileged: true
      hostPID: true
      restartPolicy: Never
EOF
) | if ! kubectl create -f - 2>&1 > /dev/null; then

  echo "unable to Restart the Portworx service on worker node, bailing out"
  exit 1
fi


# get the uid

ID=$(kubectl get job ${JOB_NAME} -n ${NAMESPACE} -o 'jsonpath={.metadata.uid}')
if [ -z "${ID}" ]; then
  echo "ERR unable to get job id"
  exit 1
fi
}



waitforportworxpods() {
RUNNING=0
LIMIT=20
SLEEP_TIME=30
DESIRED=$(kubectl get ds/portworx -n kube-system -o json | jq .status.desiredNumberScheduled)
repeat=0

while [ $repeat -lt $LIMIT ] && [ $DESIRED -ne $RUNNING ]; do 
    RUNNING=$(kubectl get pods -n kube-system -l name=portworx --field-selector status.phase=Running -o json | jq '.items | length') 
    if [ $DESIRED -eq $RUNNING ]; then 
        echo "(Attempt $i of $LIMIT) Portworx pods: Desired $DESIRED, Running $RUNNING"
    else 
        echo "(Attempt $i of $LIMIT) Portworx pods: Desired $DESIRED, Running $RUNNING, sleeping $SLEEP_TIME"
        sleep $SLEEP_TIME
    fi 
    repeat=$(( $repeat + 1 ))
done
echo "All the pods moved to running state" 
}

waitfortheworkerdelete() {


    NODE_DEPLOYING=0
    DESIRED=1
    LIMIT=90
    SLEEP_TIME=60

    repeat=0


    #### retrive the new worker id 
    while [ $NODE_DEPLOYING -ne $DESIRED  ] && [  $repeat -lt $LIMIT ]; do
       WORKER_IDS_NEW=$(ic cs workers --cluster $CLUSTER  --json | jq -r '.[] | .id')
       for id in ${WORKER_IDS_NEW}
       do
	   IFS='-' read -r -a WORKER_VALS <<< "$id"
	   zone=$(ic cs worker get --worker $id --cluster $CLUSTER --json | jq -r .location)
	   worker_state=$(ic cs worker get --cluster   $CLUSTER  --worker $id  --json | jq -r .lifecycle.actualState)
	   if [[ $worker_state  == "deploying" ]]; then
	        echo "New worker deployment started"
		provisioning_worker_id=$id
		NODE_DEPLOYING=1
		break
           else
		echo "Worker deletion is in progress...sleeping"
	   fi 
       done
        sleep $SLEEP_TIME
         repeat=$(( $repeat + 1 ))
         if [ $repeat == $LIMIT ]; then
           echo "Upgrade/replace of  the worker taking too long ..Exiting ......."
           exit 1
         fi
     done
}


executereplaceorupgrade () {
    
    waitfortheworkerdelete
    waitforthenode  $provisioning_worker_id
    if [  -z "${px_label_check}" ]; then
      waitforportworxpods
    fi

    ##Check broken volumes and  reattch to the worker
    index="0"
    for vol_id in ${vol_ids[@]}; do
    volume_attch_check=$(ic is vol ${vol_id} --json | jq -r '.volume_attachments[] .instance | .name')
     if [ -z "$volume_attch_check" ]; then
        echo "Volume: ${vol_id} is not attched to any node"
        zone=$(ic cs worker get --worker $id --cluster $CLUSTER --json | jq -r .location) 
        echo "Attaching the volume ....cluster $CLUSTER_ID worker ${id} volid ${vol_id}"
	volume_attched=""
	retry_count=0
	while [  $retry_count -le 3 ]
        do
          ic cs storage attachment create --cluster ${CLUSTER_ID} --worker ${provisioning_worker_id} --volume ${vol_id}
          volume_attched=$(ic is vol ${vol_id} --json | jq -r '.volume_attachments[] .instance | .name')
	  if [ -z "$volume_attched" ]; then
                echo "Volume attchment failed .. retrying again"
                ((retry_count++))
          else
                echo "Volume ${vol_id} is attached to the worker ${id}"
                break
          fi
        done	
	 if [ -z "${px_label_check}" ]; then
          restartPortworxService $provisioning_worker_id
	 fi
    fi
   done
}
         



#####Before upgrade bring the volume ids using the worker id
volindex=0
for id in "${WORKER_IDS[@]}"
do
   IFS='-' read -r -a WORKER_VALS <<< "$id"
   echo "worker id : $id"
   zone=$(ic ks worker get --worker $id --cluster $CLUSTER --json | jq -r .location)
   volid_perworker=$(ic is vols --json | jq -r --arg WORKER_NAME "$id" '.[]|select(.volume_attachments[] .instance.name==$WORKER_NAME) | .id')
   echo "volid :${volid_perworker[*]} is attched to the worker :${id}"
   vol_ids[volindex]=${volid_perworker[@]}
   ((volindex++))
  sleep 20
  px_label_check=$(kubectl get nodes -l px/enabled=false -o json |  grep  $id)
  ic cs worker $command_name  --cluster  $CLUSTER --worker $id
  echo "The worker being deleted waiting for the new worker ............"
  executereplaceorupgrade 
done