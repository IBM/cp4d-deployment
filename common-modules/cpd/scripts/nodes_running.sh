#!/bin/bash

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