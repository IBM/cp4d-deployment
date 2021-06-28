#!/bin/bash
export SUDOUSER=$1
export OPENSHIFTUSER=$2
export OPENSHIFTPASSWORD=$3
export CLUSTERNAME=$4
export DOMAINNAME=$5
export LOCATION=$6
export CUSTOMDOMAIN=$7
export NFSIPADDRESS=$8

export OCSTEMPLATES=/home/$SUDOUSER/.openshift/nfs/templates
runuser -l $SUDOUSER -c "mkdir -p $OCSTEMPLATES"

runuser -l $SUDOUSER -c "cat > $OCSTEMPLATES/nfs-template.yaml <<EOF
kind: Template
apiVersion: v1
metadata:
  name: nfs-template
objects:
  - kind: ServiceAccount
    apiVersion: v1
    metadata:
      name: nfs-client-provisioner
  - kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: nfs-client-provisioner-runner
    rules:
      - apiGroups: [\"\"]
        resources: [\"persistentvolumes\"]
        verbs: [\"get\", \"list\", \"watch\", \"create\", \"delete\"]
      - apiGroups: [\"\"]
        resources: [\"persistentvolumeclaims\"]
        verbs: [\"get\", \"list\", \"watch\", \"update\"]
      - apiGroups: [\"storage.k8s.io\"]
        resources: [\"storageclasses\"]
        verbs: [\"get\", \"list\", \"watch\"]
      - apiGroups: [\"\"]
        resources: [\"events\"]
        verbs: [\"create\", \"update\", \"patch\"]
  - kind: ClusterRoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: run-nfs-client-provisioner
    subjects:
      - kind: ServiceAccount
        name: nfs-client-provisioner
        namespace: kube-system
    roleRef:
      kind: ClusterRole
      name: nfs-client-provisioner-runner
      apiGroup: rbac.authorization.k8s.io
  - kind: Role
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: leader-locking-nfs-client-provisioner
    rules:
      - apiGroups: [\"\"]
        resources: [\"endpoints\"]
        verbs: [\"get\", \"list\", \"watch\", \"create\", \"update\", \"patch\"]
  - kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: leader-locking-nfs-client-provisioner
    subjects:
      - kind: ServiceAccount
        name: nfs-client-provisioner
        namespace: kube-system
    roleRef:
      kind: Role
      name: leader-locking-nfs-client-provisioner
      apiGroup: rbac.authorization.k8s.io
  - kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: nfs
    provisioner: example.com/nfs #must match deployment's env PROVISIONER_NAME'
    parameters:
      archiveOnDelete: \"false\"
  - kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: nfs-client-provisioner
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nfs-client-provisioner
      strategy:
        type: Recreate
      template:
        metadata:
          labels:
            app: nfs-client-provisioner
        spec:
          serviceAccountName: nfs-client-provisioner
          containers:
            - name: nfs-client-provisioner
              image: quay.io/external_storage/nfs-client-provisioner:latest
              volumeMounts:
                - name: nfs-client-root
                  mountPath: /persistentvolumes
              env:
                - name: PROVISIONER_NAME
                  value: example.com/nfs
                - name: NFS_SERVER
                  value: $NFSIPADDRESS
                - name: NFS_PATH
                  value: /exports/home
          volumes:
            - name: nfs-client-root
              nfs:
                server: $NFSIPADDRESS
                path: /exports/home
EOF"

# Set url
if [[ $CUSTOMDOMAIN == "true" || $CUSTOMDOMAIN == "True" ]];then
export SUBURL="${CLUSTERNAME}.${DOMAINNAME}"
else
export SUBURL="${DOMAINNAME}.${LOCATION}.aroapp.io"
fi

#Login
var=1
while [ $var -ne 0 ]; do
echo "Attempting to login $OPENSHIFTUSER to https://api.${SUBURL}:6443"
oc login "https://api.${SUBURL}:6443" -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true
var=$?
echo "exit code: $var"
done

runuser -l $SUDOUSER -c "oc login https://api.${SUBURL}:6443 -u $OPENSHIFTUSER -p $OPENSHIFTPASSWORD --insecure-skip-tls-verify=true"
runuser -l $SUDOUSER -c "oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:kube-system:nfs-client-provisioner"
runuser -l $SUDOUSER -c "oc process -f $OCSTEMPLATES/nfs-template.yaml | oc create -n kube-system -f -"