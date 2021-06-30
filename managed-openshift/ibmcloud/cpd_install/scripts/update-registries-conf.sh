#!/bin/bash

updates_file=$1
if [[ -z "${updates_file}" ]]; then
    echo "Usage: $0 <updates-file>" >&2
    exit 2
fi

if [[ -s ${updates_file} ]]; then
    registries_conf=/host/etc/containers/registries.conf
    if [[ ! -f ${registries_conf} ]] || ! grep -q hyc-cip-docker-local ${registries_conf}; then
        cat ${updates_file} >> ${registries_conf}
    fi
fi
