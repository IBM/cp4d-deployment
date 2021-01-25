#!/bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

NOOBAA_BUCKETS=`aws s3 ls | grep nb\.* | awk '{print $3}'`
for bucket in ${NOOBAA_BUCKETS[@]}; do
aws s3 rb s3://$bucket --force
done
