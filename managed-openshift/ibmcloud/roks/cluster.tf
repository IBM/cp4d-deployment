locals {
  # zone_count = var.multizone ? 3 : 1
  # zones = ["${var.region}-1", "${var.region}-2", "${var.region}-3"]
}

resource "ibm_resource_instance" "cos_instance" {
  count = var.cos_instance_crn == null ? 1 : 0
  
  location = "global"
  name     = "${var.unique_id}-cos-instance"
  plan     = "standard"
  resource_group_id = var.resource_group_id
  service  = "cloud-object-storage"
}

# resource "ibm_cos_bucket" "imageregistry" {
#   bucket_name          = var.unique_id
#   endpoint_type        = "public"
#   resource_instance_id = ibm_resource_instance.cos_instance[0].id
#   region_location      = var.region
#   storage_class        = "standard"
# }

data "ibm_is_subnet" "this" {
  count = length(var.vpc_subnets)
  identifier = var.vpc_subnets[count.index]
}

locals {
  zone_subnet_map = zipmap(data.ibm_is_subnet.this.*.zone, var.vpc_subnets)
}

#Create the ROKS cluster
resource "ibm_container_vpc_cluster" "this" {
  count = var.existing_roks_cluster == null ? 1 : 0

  cos_instance_crn                = var.cos_instance_crn == null ? ibm_resource_instance.cos_instance[0].crn : var.cos_instance_crn
  disable_public_service_endpoint = var.disable_public_service_endpoint
  entitlement                     = var.entitlement
  flavor                          = var.worker_node_flavor
  name                            = "${var.unique_id}-cluster"
  kube_version                    = var.kube_version
  resource_group_id               = var.resource_group_id
  vpc_id                          = var.vpc_id
  worker_count                    = var.worker_nodes_per_zone
  
  dynamic "zones" {
    for_each = local.zone_subnet_map
    content {
      name = zones.key
      subnet_id = zones.value
    }
  }
}

data "ibm_container_vpc_cluster" "this" {
  name              = var.existing_roks_cluster == null ? ibm_container_vpc_cluster.this[0].id : var.existing_roks_cluster
  resource_group_id = var.resource_group_id
}

data "ibm_container_cluster_config" "this" {
  cluster_name_id = data.ibm_container_vpc_cluster.this.id
  config_dir = pathexpand("~")
  resource_group_id = var.resource_group_id
}

resource "null_resource" "make_kubeconfig_symlink" {
  triggers = {
    config_file_path =  data.ibm_container_cluster_config.this.config_file_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "mkdir -p ~/.kube && rm -f ~/.kube/config && ln -s ${self.triggers.config_file_path} ~/.kube/config"
  }
}
