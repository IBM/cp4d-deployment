#Adding the Portworx service accounts to the privileged security context
oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:px-account
oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:portworx-pvc-controller-account
oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:px-lh-account
oc adm policy add-scc-to-user anyuid system:serviceaccount:kube-system:px-lh-account
oc adm policy add-scc-to-user anyuid system:serviceaccount:default:default
oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:px-csi-account

#Portworx Operator will install pods only on nodes that have the label node-role.kubernetes.io/compute=true
WORKER_NODES=`oc get nodes | grep worker | awk '{print $1}'`
for wnode in ${WORKER_NODES[@]}; do
oc label nodes $wnode node-role.kubernetes.io/compute=true
done
