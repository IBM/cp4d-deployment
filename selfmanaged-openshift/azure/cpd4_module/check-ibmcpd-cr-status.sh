#!/bin/bash

SERVICE=\$1
CRNAME=\$2
NAMESPACE=\$3
SERVICE_STATUS=\$4
STATUS=\$(oc get \$SERVICE \$CRNAME -n \$NAMESPACE -o json | jq .status | grep "\"reason\": \"Successful\"" | xargs) 



while [ "\$STATUS" != "reason: Successful," ];do
    echo "\$CRNAME is Installing!!!!"
    sleep 60 
    STATUS=\$(oc get \$SERVICE \$CRNAME -n \$NAMESPACE -o json | jq .status | grep "\"reason\": \"Successful\"" | xargs) 
    if [ "\$STATUS" == "reason: Failed," ]
    then
        echo "**********************************"
        echo "\$CRNAME Installation Failed!!!!"
        echo "**********************************"
        exit
    fi
done 
echo "*************************************"
echo "\$CRNAME Installation Finished!!!!"
echo "*************************************"