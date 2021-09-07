#!/bin/bash

SERVICE=$1
CRNAME=$2
NAMESPACE=$3
SERVICE_STATUS=$4
STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

while [[ $STATUS != "Complete" && $STATUS != "Completed" ]];do
    echo "Installing $CRNAME - Status: $STATUS !!!!"
    sleep 120 
    STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
    if [ "$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "$CRNAME Installation Failed!!!!"
        echo "**********************************"
        exit 1
    fi
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"