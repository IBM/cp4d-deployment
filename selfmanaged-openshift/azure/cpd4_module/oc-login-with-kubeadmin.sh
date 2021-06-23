#!/bin/bash

export OCAUTHPOD=\$(oc get pods -n openshift-authentication -o jsonpath='{.items[0].metadata.name}')

cd /home/core/ocpfourx
oc rsh -n openshift-authentication \${OCAUTHPOD} cat /run/secrets/kubernetes.io/serviceaccount/ca.crt > ingress-ca.crt

chmod 755 ingress-ca.crt
cp ingress-ca.crt ingress-ca.crt-backup

