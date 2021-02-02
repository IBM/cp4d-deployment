#! /bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null

INFRANAME=$(jq -r .infraID $HOME/ocpfourx/metadata.json)
for id in $(aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/$INFRANAME,Values=owned" "Name=status,Values=available" --query "Volumes[*].VolumeId" --output text); do
aws ec2 delete-volume --volume-id $id
done
