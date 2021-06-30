#!/bin/bash

while true; do
    node_status=\$(oc get nodes | grep -E "SchedulingDisabled|NotReady")
    if [[ -z \$node_status ]]; then
        echo -e "\n******All nodes are running now.******"
        break
    fi
        echo -e "\n******Waiting for nodes to get ready.******"
        oc get nodes --no-headers | awk '{print \$1 " " \$2}'
        echo -e "\n******sleeping for 60Secs******"
        sleep 60
    done