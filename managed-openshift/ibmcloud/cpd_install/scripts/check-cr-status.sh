#!/bin/bash

SERVICE=$1
CRNAME=$2
NAMESPACE=$3
SERVICE_STATUS=$4
STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

while [ "$STATUS" != "Completed" ];do
    echo "$CRNAME is Installing!!!!"
    sleep 60 
    STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
    if [ "$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "$CRNAME Installation Failed!!!!"
        echo "**********************************"
        exit
    fi
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"