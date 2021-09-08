#!/bin/bash

cluster=$1
workers=${@:2}
if [[ -z "${cluster}" ]]; then
    echo "Usage: $0 <cluster> <workers...>" >&2
    exit 2
fi

# TEMPORARY workaround for https://github.ibm.com/cp4i/icp4i-sagan/issues/898
oc_plugin_version=$(ibmcloud plugin list | awk '/^container-service/{print $2}')
echo "Using container-service plugin ${oc_plugin_version}"
if [[ "${oc_plugin_version}" == 0.3.* ]]; then
    reboot_worker_flag=--workers
else
    reboot_worker_flag=--worker
fi

function get_status {
    private_ip=$1
    oc get node ${private_ip} --no-headers | awk '{print $2}'
}

function reboot {
    drain=true
    if [[ "$1" == "-f" ]]; then
        # already cordoned
        drain=false
        shift
    fi
    delay=$1
    worker=$2

    # this is the name under which k8s knows the node
    #for VPC Gen2 ROKS Cluster - 
    private_ip=$(ibmcloud oc worker get -s --cluster ${cluster} --worker ${worker} --json | jq -r .networkInterfaces[].ipAddress)
    
    #for Classic cluster please use the below line of code instead of above
    #private_ip=$(ibmcloud oc worker get -s --cluster ${cluster} --worker ${worker} --json | jq -r .privateIP)
    
    echo "Rebooting worker ${worker} (${private_ip}) ..."

    if ${drain}; then
        oc adm drain ${private_ip} --force --ignore-daemonsets --delete-local-data
    fi
    ibmcloud oc worker reboot -s -f --cluster ${cluster} ${reboot_worker_flag} ${worker}

    # wait up to 15 min for node to get back to Ready state
    shutdown=false
    (( end_time=SECONDS+900 ))
    while (( SECONDS < end_time )); do
        time=$(date +'%H:%M:%S')
        status=$(get_status ${private_ip})
        echo "${time} ${status}"
        case ${status} in
            Ready*)
                if ${shutdown}; then
                    break
                fi
                ;;
            NotReady*)
                shutdown=true
                ;;
        esac
        sleep 5
    done
    # wait another few min for pods to be restarted
    sleep $(( delay * 60 ))

    status=$(get_status ${private_ip})
    if [[ ${status} != Ready* ]]; then
        echo "Worker not ready: ${worker} (${status})"
        return 1
    fi

    # reopen for business
    oc adm uncordon ${private_ip}
}

if [[ -z "${workers}" ]]; then
    workers=$(ibmcloud oc worker ls -s --cluster ${cluster} --json | jq -r '.[].id')
fi

queue=(${workers})
force=

n=${#queue[*]}
# how long to wait for each worker to restart
if (( n < 5 )); then
    delay=5
elif (( n < 10)); then
    delay=3
else
    delay=1
fi

while true; do
    failed=()
    for worker in ${queue[*]}; do
        if ! reboot ${force} ${delay} ${worker}; then
            failed=(${failed[*]} ${worker})
        fi
    done
    if [[ ${#failed[*]} == 0 ]]; then
        break
    elif [[ ${#failed[*]} == ${#queue[*]} ]]; then
        # no progress
        echo "Not all nodes could be restarted (quitting)"
        exit 1
    fi
    echo "Not all nodes could be restarted (retrying)"
    queue=(${failed[*]})
    # nodes will already be cordoned so don't drain again
    force="-f"
done