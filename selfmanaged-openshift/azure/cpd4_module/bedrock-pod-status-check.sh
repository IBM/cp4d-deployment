#!/bin/bash


podname=\$1
namespace=\$2

status="unknown"
while [ "\$status" != "Running" ]
do
  ready_status=\$(oc get pods -n \$namespace -l name=\$podname  --no-headers | awk '{print \$2}')
  pod_status=\$(oc get pods -n \$namespace -l name=\$podname --no-headers | awk '{print \$3}')
  echo \$podname State - \$ready_status, podstatus - \$pod_status
  if [ "\$ready_status" == "1/1" ] && [ "\$pod_status" == "Running" ]
  then 
  status="Running"
  else
  status="starting"
  sleep 10 
  fi
  echo "\$podname is \$status"
done

