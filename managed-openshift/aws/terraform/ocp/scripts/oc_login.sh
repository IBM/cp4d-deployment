#!/bin/bash
login_cmd=$1
login_state="Failed"
counter=0
while [[ $counter  -lt 20 && $login_state == "Failed" ]]; do
    sleep 60
    counter=$(( counter + 1 ))
    echo -e "\n Login to rosa cluster as cluster-admin"
    $login_cmd --insecure-skip-tls-verify
    if [  $? == 0 ]; then
    login_state="Success"
    fi       
done