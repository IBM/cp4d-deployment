#!/bin/bash
NAMESPACE=$1
nginxpod=$(oc -n $NAMESPACE get pod -l component=ibm-nginx -o jsonpath='{.items[0].metadata.name}')
oc -n $NAMESPACE cp $nginxpod:/etc/nginx/config/ssl/cert.crt /cert.crt || exit 1
oc -n $NAMESPACE delete route ${NAMESPACE}-cpd
oc -n $NAMESPACE create route reencrypt cpd --service=ibm-nginx-svc --port=ibm-nginx-https-port --dest-ca-cert=/cert.crt
rm /cert.crt
