#!/bin/bash

SUBSCRIPTION=\$1
NAMESPACE=\$2
SUBSCRIPTION_STATUS=\$3
STATUS=\$(oc get subscription \$SUBSCRIPTION -n \$NAMESPACE -o json | jq .status.\$SUBSCRIPTION_STATUS | xargs) 

while  [[ ! \$STATUS =~ ^(AtLatestKnown)\$ ]]; do
    echo "\$SUBSCRIPTION subscription is Installing!!!!"
    sleep 60 
    STATUS=\$(oc get subscription \$SUBSCRIPTION -n \$NAMESPACE -o json | jq .status.\$SUBSCRIPTION_STATUS | xargs) 
    if [ "\$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "\$SUBSCRIPTION Failed!!!!"
        echo "**********************************"
        exit
    fi
done 
echo "*************************************"
echo "\$SUBSCRIPTION Finished!!!!"
echo "*************************************"