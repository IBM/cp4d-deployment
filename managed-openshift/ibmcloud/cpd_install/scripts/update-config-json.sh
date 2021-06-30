#!/bin/bash

updates_file=$1
if [[ -z "${updates_file}" ]]; then
    echo "Usage: $0 <updates-file>" >&2
    exit 2
fi

if [[ -s ${updates_file} ]]; then
    curl -sSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > /usr/local/bin/jq
    chmod +x /usr/local/bin/jq

    config_json=/host/.docker/config.json
    if jq -s '.[0] * .[1]' ${config_json} ${updates_file} > ${config_json}.TMP; then
        if [[ ! -f ${config_json}.ORIG ]]; then
            cp -p ${config_json} ${config_json}.ORIG
        fi
        mv -f ${config_json}.TMP ${config_json}
    fi
fi
