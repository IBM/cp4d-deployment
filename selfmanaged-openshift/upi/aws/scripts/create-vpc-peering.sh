#! /bin/bash

#Install aws CLI
curl -O https://bootstrap.pypa.io/get-pip.py > /dev/null
python3 get-pip.py --user > /dev/null
export PATH="~/.local/bin:$PATH"
source ~/.bash_profile > /dev/null
pip install awscli --upgrade --user > /dev/null
pip install pssh > /dev/null

MIRROR_VPC_ID=$1	
AIRGAP_VPC_ID=$2
MIRROR_VPC_CIDR=$3
AIRGAP_VPC_CIDR=$4
MIRROR_VPC_REGION=$5
AIRGAP_VPC_REGION=$6
BOOTNODE_SG_ID=$7
MIRROR_SG_ID=$8
MIRROR_ROUTEID=$9

# VPC Peering connection creation
VPC_PEERING_CONNECTION_ID=$(aws ec2 create-vpc-peering-connection --vpc-id $AIRGAP_VPC_ID --peer-vpc-id $MIRROR_VPC_ID --peer-region $MIRROR_VPC_REGION --query 'VpcPeeringConnection.VpcPeeringConnectionId' --output text)
sleep 10

# Accepting the vpc peering connection:
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $VPC_PEERING_CONNECTION_ID --region $MIRROR_VPC_REGION
aws ec2 create-tags --resources $VPC_PEERING_CONNECTION_ID  --tags Key=Name,Value=vpc-peering-cp4d-cluster --region $AIRGAP_VPC_REGION

# Creating Routes for vpc peering at cluster and mirror machines
AIRGAP_ROUTETABLE_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$AIRGAP_VPC_ID --region $AIRGAP_VPC_REGION --query 'RouteTables[*].RouteTableId' --output text)
for ROUTE in ${AIRGAP_ROUTETABLE_ID[@]}; do
aws ec2 create-route --route-table-id $ROUTE --destination-cidr-block $MIRROR_VPC_CIDR --vpc-peering-connection-id $VPC_PEERING_CONNECTION_ID
done
aws ec2 create-route --route-table-id $MIRROR_ROUTEID --destination-cidr-block $AIRGAP_VPC_CIDR --vpc-peering-connection-id $VPC_PEERING_CONNECTION_ID --region $MIRROR_VPC_REGION

# Expose ports on bootnode, master, worker and mirror machine Security group:
# Expose port 80/443 on worker sg to both CIDR Ranges:
# Expose ports on Worker Security group
MASTER_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=tag:aws:cloudformation:logical-id,Values=MasterSecurityGroup --region $AIRGAP_VPC_REGION  --query "SecurityGroups[*].{Name:GroupId}" --output text)
WORKER_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=tag:aws:cloudformation:logical-id,Values=WorkerSecurityGroup --region $AIRGAP_VPC_REGION  --query "SecurityGroups[*].{Name:GroupId}" --output text)
aws ec2 authorize-security-group-ingress --group-id $MASTER_GROUP_ID --region $AIRGAP_VPC_REGION --protocol all --cidr $MIRROR_VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --region $AIRGAP_VPC_REGION --protocol tcp --port 80 --cidr $MIRROR_VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --region $AIRGAP_VPC_REGION --protocol tcp --port 443 --cidr $MIRROR_VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $WORKER_GROUP_ID --region $AIRGAP_VPC_REGION  --protocol tcp --port 30000-32767 --cidr $AIRGAP_VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $BOOTNODE_SG_ID --region $AIRGAP_VPC_REGION --protocol all --cidr $MIRROR_VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $MIRROR_SG_ID --region $MIRROR_VPC_REGION --protocol all --cidr $AIRGAP_VPC_CIDR

# Allowing dns resolution from mirror vpc
aws ec2 modify-vpc-peering-connection-options --vpc-peering-connection-id $VPC_PEERING_CONNECTION_ID --region $MIRROR_VPC_REGION --accepter-peering-connection AllowDnsResolutionFromRemoteVpc=true
aws ec2 modify-vpc-peering-connection-options --vpc-peering-connection-id $VPC_PEERING_CONNECTION_ID --region $AIRGAP_VPC_REGION --requester-peering-connection-options AllowDnsResolutionFromRemoteVpc=true

# Associatinng Mirror vpc with hosted zone
HOSTEDZONE_ID=$(aws route53 list-hosted-zones-by-vpc --vpc-id $AIRGAP_VPC_ID --vpc-region $AIRGAP_VPC_REGION --query 'HostedZoneSummaries[*].HostedZoneId' --output text)
aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $HOSTEDZONE_ID --vpc VPCRegion=$MIRROR_VPC_REGION,VPCId=$MIRROR_VPC_ID
