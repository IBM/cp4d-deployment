#!/bin/bash

oc get secret pull-secret -n openshift-config -o json | jq -r '.data[".dockerconfigjson"]' | base64 -d
