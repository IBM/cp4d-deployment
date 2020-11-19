#!/bin/bash

SERVICE=\$1
NAMESPACE=\$2
STATUS="Installing"

while [ "\$STATUS" != "Ready" ];do
    echo "\$SERVICE Installing!!!!"
    sleep 60 
    STATUS=\$(oc get cpdservice \$SERVICE-cpdservice -n \$NAMESPACE --output="jsonpath={.status.status}" | xargs) 
    if [ "\$STATUS" == "Failed" ]
    then
        echo "**********************************"
        echo "\$SERVICE Installation Failed!!!!"
        echo "**********************************"
        exit
    fi
done 
echo "*************************************"
echo "\$SERVICE Installation Finished!!!!"
echo "*************************************"
