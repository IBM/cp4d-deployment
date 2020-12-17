########################################################
# Create custom storage classes for Cloud Pak for Data
########################################################

# IBM Cloud Portworx creates a default db2 sc that needs to be deleted to avoid a naming conflict with px-sc.sh
resource "null_resource" "delete_db2_sc" {
  depends_on = [ibm_resource_instance.portworx]
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "oc delete sc portworx-db2-sc"
  }
}

# px-sc.sh comes from https://github.ibm.com/PrivateCloud-analytics/portworx-util/blob/px-2.5.5/cpd-portworx/px-install-4.x/px-sc.sh
resource "null_resource" "px_sc" {
  depends_on = [ibm_resource_instance.portworx, null_resource.delete_db2_sc]
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = file("${path.module}/scripts/px-sc.sh")
  }
}
