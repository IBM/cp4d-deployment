#!/bin/bash
NAMESPACE=$1
nginxpod=$(oc -n $NAMESPACE get pod -l component=ibm-nginx -o jsonpath='{.items[0].metadata.name}')
oc -n $NAMESPACE cp $nginxpod:/nginx_data/config/default-ssl/cert.crt /cert.crt
oc -n $NAMESPACE delete route ${NAMESPACE}-cpd
oc -n $NAMESPACE create route reencrypt ${NAMESPACE}-cpd --service=ibm-nginx-svc --port=ibm-nginx-https-port --dest-ca-cert=/cert.crt
rm /cert.crt
