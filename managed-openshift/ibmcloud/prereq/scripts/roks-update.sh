#!/bin/bash

cluster_name=$1
if [[ -z "${cluster_name}" ]]; then
    echo "Usage: $0 <cluster-name>" >&2
    exit 2
fi

cd $(dirname $0)

# ID for this run
id=cp4i-update-$$

# make a folder for the config map
cm=${id}-cm
mkdir ${cm}

# generate the update to registries.conf (mirrors)
#./gen-registries-conf.sh > ${cm}/registries.conf
cp -p registries.conf ${cm}

# generate the update to config.json (pull secrets)
#./gen-config-json.sh > ${cm}/config.json
cp -p config.json ${cm}

# copy scripts to apply the updates
cp -p update-registries-conf.sh ${cm}
cp -p update-config-json.sh ${cm}
cp -p update-all.sh ${cm}

# create a namespace
ns=${id}-ns
oc create ns ${ns}

# apply privileged SCC
oc adm policy add-scc-to-group privileged system:serviceaccounts:${ns}

# create a config map
oc create cm ${cm} -n ${ns} --from-file=${cm}

# run the update script as a job on each worker
workers=$(ibmcloud oc worker ls -s --cluster ${cluster_name} --json | jq -r '.[].id')
(( count=1 ))
for worker in ${workers}; do
    job=${id}-job-${count}
    sed \
        -e 's/${JOB}/'${job}'/' \
        -e 's/${NAMESPACE}/'${ns}'/' \
        -e 's/${WORKER}/'${worker}'/' \
        -e 's/${CONFIG_MAP}/'${cm}'/' \
        job.yaml | \
        oc apply -f -
    (( count=count+1 ))
done

# wait for all jobs to complete
if ! oc wait --for=condition=complete job --all -n ${ns} --timeout=600s; then
    echo "Not all jobs completed" >&2
    exit 1
fi

# delete the namespace
oc delete ns ${ns}

# reboot the cluster
./roks-reboot.sh ${cluster_name}

# remove the config map folder
rm -r ${cm}
