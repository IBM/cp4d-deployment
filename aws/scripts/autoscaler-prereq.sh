#Finding the cluster id
CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
sed -i s/CLUSTERID/$CLUSTERID/g ~/ocpfourxtemplates/machineset-worker-ocs.yaml
sed -i s/CLUSTERID/$CLUSTERID/g ~/ocpfourxtemplates/machine-autoscaler.yaml
sed -i s/CLUSTERID/$CLUSTERID/g ~/ocpfourxtemplates/machine-health-check.yaml
