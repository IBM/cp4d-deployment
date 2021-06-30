#!/bin/bash


podname=\$1
namespace=\$2

status="unknown"
while [ "\$status" != "Running" ]
do
  pod_name=\$(oc get pods -n \$namespace | grep \$podname | awk '{print \$1}' )
  ready_status=\$(oc get pods -n \$namespace \$pod_name  --no-headers | awk '{print \$2}')
  pod_status=\$(oc get pods -n \$namespace \$pod_name --no-headers | awk '{print \$3}')
  echo \$pod_name State - \$ready_status, podstatus - \$pod_status
  if [ "\$ready_status" == "1/1" ] && [ "\$pod_status" == "Running" ]
  then 
  status="Running"
  else
  status="starting"
  sleep 10 
  fi
  echo "\$pod_name is \$status"
done

