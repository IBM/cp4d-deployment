#############################
# Optimize kernel parameters
#############################
locals {
  setkernelparams_file = local.worker_node_memory < 128 ? "setkernelparams.yaml" : "setkernelparams_128gbRAM.yaml"
  worker_node_memory = tonumber(regex("[0-9]+$", var.worker_node_flavor))
  cluster_name = var.existing_roks_cluster == null ? "${var.unique_id}-cluster" : var.existing_roks_cluster
}
resource "null_resource" "setkernelparams" {
  depends_on = [var.portworx_is_ready]
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    interpreter = ["/bin/bash", "-c"]
    command = "oc apply -n kube-system -f ${local.setkernelparams_file}"
  }
}

###########################################
# Create and annotate image registry route
###########################################
resource "null_resource" "create_registry_route" {
  depends_on = [var.portworx_is_ready]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "oc create route reencrypt --service=image-registry -n openshift-image-registry"
  }
}
resource "null_resource" "annotate_registry_route" {
  depends_on = [null_resource.create_registry_route]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "oc annotate route image-registry --overwrite haproxy.router.openshift.io/balance=source -n openshift-image-registry"
  }
}

################################
# Patch S3 endpoint
################################
# resource "null_resource" "patch_s3_endpoint" {
#   depends_on = [var.portworx_is_ready]
#
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command = "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{\"spec\": {\"storage\":{\"s3\":{\"regionEndpoint\":\"https://s3.us.cloud-object-storage.appdomain.cloud\"}}}}'"
#   }
# }
###############################################
# Increase imageregistry replicas if multizone
###############################################
# resource "null_resource" "imageregistry_multizone" {
#   depends_on = [var.portworx_is_ready]
#   count = var.multizone ? 1 : 0
#
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command = "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"replicas\":3}}'"
#   }
# }

resource "null_resource" "set_pull_secret" {
  count = var.accept_cpd_license == "yes" ? 1 : 0
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/"
    command = <<-EOF
echo "Setting pull secret on all the nodes"
./setup-global-pull-secret-bedrock.sh ${var.cpd_registry_username} ${var.cpd_registry_password}
ibmcloud login --apikey ${var.ibmcloud_api_key} -g ${var.resource_group_name} -r ${var.region}
./roks-update.sh ${local.cluster_name}
EOF
  }
  depends_on = [
    var.portworx_is_ready,
  ]
}

#######################
# Catch-all checkpoint
#######################
resource "null_resource" "prereqs_checkpoint" {
  depends_on = [
    var.portworx_is_ready,
    null_resource.setkernelparams,
    null_resource.create_registry_route,
    null_resource.annotate_registry_route,
    null_resource.set_pull_secret,
    # null_resource.imageregistry_multizone,
  ]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "echo '=== REACHED PREREQS CHECKPOINT ==='"
  }
}
