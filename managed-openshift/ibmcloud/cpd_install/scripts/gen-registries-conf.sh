#!/bin/bash

function print_registry_entry {
    source=$1
    mirrors="$2"

    echo
    echo '[[registry]]'
    echo '  prefix = ""'
    echo '  location = "'${source}'"'
    echo '  mirror-by-digest-only = true'

    for mirror in ${mirrors}; do
        echo
        echo '  [[registry.mirror]]'
        echo '    location = "'${mirror}'"'
    done
}

oc get imagecontentsourcepolicy mirror-config -o json | \
    jq -r '.spec.repositoryDigestMirrors[]|[.source,.mirrors[]]|join(" ")' | \
    while read source mirrors; do
        print_registry_entry "${source}" "${mirrors}"
    done
