# Script to check cr status for Watson Assistant.
#!/bin/bash

SERVICE=$1
CRNAME=$2
NAMESPACE=$3
SERVICE_STATUS=$4
STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 

while [[ $STATUS != "Complete" && $STATUS != "Completed" ]];do
    echo "Installing $CRNAME !!!!"
    sleep 120 
    STATUS=$(oc get $SERVICE $CRNAME -n $NAMESPACE -o json | jq .status.$SERVICE_STATUS | xargs) 
done 
echo "*************************************"
echo "$CRNAME Installation Finished!!!!"
echo "*************************************"