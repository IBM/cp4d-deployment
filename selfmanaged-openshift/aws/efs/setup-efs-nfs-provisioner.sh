#!/usr/bin/env bash

CLUSTER_URL=$1
CLUSTER_ADMIN_USERNAME=$2
CLUSTER_ADMIN_PASSWORD=$3

echo "Setting up efs storage" 

# Extract cluster name from url

CLUSTER_NAME=$(echo "$CLUSTER_URL" | sed -e 's|https://api\.\([^\.]*\).*|\1|')
echo "CLUSTER_NAME=$CLUSTER_NAME"
<<<<<<< HEAD
CLUSTER_VPCID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") or (.Value | test("'$CLUSTER_NAME'-vpc"))))) | .VpcId')
=======
CLUSTER_VPCID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'-vpc"))))) | .VpcId')
>>>>>>> cc129ae4 (updated the efs setup in self-managed)
echo "CLUSTER_VPCID=$CLUSTER_VPCID"
if [ -z "$CLUSTER_VPCID" ]
then 
CLUSTER_VPCID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'.*-vpc"))))) | .VpcId')
echo "CLUSTER_VPCID=$CLUSTER_VPCID"
fi

CLUSTER_VPC_CIDR=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'-vpc"))))) | .CidrBlock')
echo "CLUSTER_VPC_CIDR=$CLUSTER_VPC_CIDR"
if [ -z "$CLUSTER_VPC_CIDR" ]
then
CLUSTER_VPC_CIDR=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'.*-vpc"))))) | .CidrBlock')
echo "CLUSTER_VPC_CIDR=$CLUSTER_VPC_CIDR"
fi
CLUSTER_WORKER_SECURITY_GROUPID=$(aws ec2 describe-security-groups | jq -r '.SecurityGroups[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'-.*-worker-sg"))))) | .GroupId')
echo "CLUSTER_WORKER_SECURITY_GROUPID=$CLUSTER_WORKER_SECURITY_GROUPID"
CLUSTER_PRIVATE_SUBNETID=$(aws ec2 describe-subnets | jq -r '.Subnets[] | select(has("Tags") and (.Tags[] | select((.Key=="Name") and (.Value | test("'$CLUSTER_NAME'-.*-private-.*"))))) | .SubnetId')
echo "CLUSTER_PRIVATE_SUBNETID=$CLUSTER_PRIVATE_SUBNETID"

echo "Add NFS inbound rule to Workers security group"

OUTPUT=$(\
aws ec2 authorize-security-group-ingress \
--group-id $CLUSTER_WORKER_SECURITY_GROUPID \
--protocol tcp \
--port 2049 \
--cidr $CLUSTER_VPC_CIDR \
2>&1 || true
)
if [[ "$OUTPUT" == *"already exists"* ]]; then
    echo "rule already exists"
else
    echo "Security group ingress rule created successfully"
    echo $OUTPUT
fi

echo "Create filesystem '${CLUSTER_NAME}-efs'"

OUTPUT=$(\
aws efs create-file-system \
--creation-token ${CLUSTER_NAME}-efs \
--encrypted \
--no-backup \
--tags Key=Name,Value=${CLUSTER_NAME}-efs \
2>&1 || true
)
if [[ "$OUTPUT" == *"already exists"* ]]; then
    echo "File system already exists"
else
    echo "File system created successfully"
    echo $OUTPUT
fi

sleep 5
    FILESYSTEMID=`echo $OUTPUT | jq '.' | awk '/FileSystemId/ {print $2}'`
    CLUSTER_FILESYSTEMID=`echo $FILESYSTEMID | tr -d '",'` 
    #CLUSTER_FILESYSTEMID=$(aws efs describe-file-systems | jq -r .FileSystems[].FileSystemId) 
    echo "CLUSTER_FILESYSTEMID=$CLUSTER_FILESYSTEMID"

    echo "Create filesystem mount target for workers"
    OUTPUT=$(\
     aws efs create-mount-target \
    --file-system-id $CLUSTER_FILESYSTEMID \
    --subnet-id $CLUSTER_PRIVATE_SUBNETID \
    --security-group $CLUSTER_WORKER_SECURITY_GROUPID \
    2>&1 || true
    )
    if [[ "$OUTPUT" == *"already exists"* ]]; then
        echo "mount target already exists"
    else
        echo "Mount target created successfully"
        echo $OUTPUT
    fi 
sleep 5

    IPADDRESS=`echo $OUTPUT | jq '.' | awk '/IpAddress/ {print $2}'`
    FILESYSTEM_IPADRESS=`echo $IPADDRESS | tr -d '",'`
    echo "FILESYSTEM_IPADRESS:"$FILESYSTEM_IPADRESS

echo "Setting up NFS-Subdir-Provisioner"

oc login $CLUSTER_URL --insecure-skip-tls-verify -u $CLUSTER_ADMIN_USERNAME -p $CLUSTER_ADMIN_PASSWORD
WORKER_NODE=`oc get nodes | grep worker | tail -1 | awk '/compute.internal/ {print $1}'` 
echo  "WORKER_NODE:"$WORKER_NODE
AWS_REGION=`echo "$WORKER_NODE" | cut -d'.' -f2`
echo "AWS_REGION:" $AWS_REGION
echo "waiting for the creation of  Mount-target "
sleep 30

<<<<<<< HEAD
FILESYSTEM_DNS_NAME=$CLUSTER_FILESYSTEMID.efs.$AWS_REGION.amazononaws.com 
=======
FILESYSTEM_DNS_NAME=$CLUSTER_FILESYSTEMID.efs.$AWS_REGION.cpdonawsonline.com 
>>>>>>> cc129ae4 (updated the efs setup in self-managed)
# echo "Setting up NFS-Subdir-Provisioner"
echo "FILESYSTEM_DNS_NAME:--->" $FILESYSTEM_DNS_NAME
NAMESPACE=`oc project -q`
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner

# Create RBAC
cat <<EOF |oc create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

echo "==========Creating Deployment=========="
sleep 60


# Create deployment

cat <<EOF | oc create -f - 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2 
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: $FILESYSTEM_DNS_NAME
            - name: NFS_PATH
              value: /
      volumes:
        - name: nfs-client-root
          nfs:
            server: $FILESYSTEM_DNS_NAME
            path: /
EOF
sleep 10

cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
EOF

# To restart the deployment
# oc rollout restart deployment/nfs-client-provisioner