provider "kubernetes" {
  load_config_file = "false"
  host             = var.oc_host
  token            = var.oc_token
}

##################################################
# Create and attach block storage to worker nodes
##################################################

# Determine every worker's zone
data "ibm_container_vpc_cluster" "this" {
  name = var.cluster_id
  resource_group_id = var.resource_group_id
}
data "ibm_container_vpc_cluster_worker" "this" {
  count = var.worker_nodes

  cluster_name_id   = var.cluster_id
  resource_group_id = var.resource_group_id
  worker_id         = data.ibm_container_vpc_cluster.this.workers[count.index]
}
data "ibm_is_subnet" "this" {
  count = var.worker_nodes
  identifier = data.ibm_container_vpc_cluster_worker.this[count.index].network_interfaces[0].subnet_id
}

data "ibm_iam_auth_token" "this" {}

# Create a block storage volume per worker.
resource "ibm_is_volume" "this" {
  count = var.worker_nodes

  capacity = var.storage_capacity
  iops = var.storage_profile == "custom" ? var.storage_iops : null
  name = "${var.unique_id}-pwx-${split("-", data.ibm_container_vpc_cluster.this.workers[count.index])[4]}"
  profile = var.storage_profile
  resource_group = var.resource_group_id
  zone = data.ibm_is_subnet.this[count.index].zone
}

# locals {
#   worker_volume_map = zipmap(data.ibm_container_vpc_cluster_worker.this.*.id, ibm_is_volume.this.*.id)
# }

# Attach block storage to worker
resource "null_resource" "volume_attachment" {
  # count = length(data.ibm_container_vpc_cluster_worker.worker)
  count = var.worker_nodes
  # for_each = local.worker_volume_map
  
  triggers = {
    volume = ibm_is_volume.this[count.index].id
    worker = data.ibm_container_vpc_cluster_worker.this[count.index].id
  }

  provisioner "local-exec" {
    environment = {
      TOKEN             = data.ibm_iam_auth_token.this.iam_access_token
      REGION            = var.region
      RESOURCE_GROUP_ID = var.resource_group_id
      CLUSTER_ID        = var.cluster_id
      WORKER_ID         = data.ibm_container_vpc_cluster_worker.this[count.index].id
      VOLUME_ID         = ibm_is_volume.this[count.index].id
    }

    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/volume_attachment.sh")
  }

  # this breaks beyond terraform 0.12 because destroy provisioners are not allowed to reference other resources
  # check with ibm terraform providers team for a volume_attachment resource
  # provisioner "local-exec" {
  #   when = destroy
  #   environment = {
  #     TOKEN             = data.ibm_iam_auth_token.this.iam_access_token
  #     REGION            = var.region
  #     RESOURCE_GROUP_ID = var.resource_group_id
  #     CLUSTER_ID        = var.cluster_id
  #     WORKER_ID         = data.ibm_container_vpc_cluster_worker.this[count.index].id
  #     VOLUME_ID         = ibm_is_volume.this[count.index].id
  #   }
  #
  #   interpreter = ["/bin/bash", "-c"]
  #   command     = file("${path.module}/scripts/volume_attachment_destroy.sh")
  # }
}

#############################################
# Create 'Databases for Etcd' service instance
#############################################
resource "ibm_database" "etcd" {
  count = var.create_external_etcd ? 1 : 0
  location = var.region
  members_cpu_allocation_count = 9
  members_disk_allocation_mb = 393216
  members_memory_allocation_mb = 24576
  name = "${var.unique_id}-pwx-etcd"
  plan = "standard"
  resource_group_id = var.resource_group_id
  service = "databases-for-etcd"
  service_endpoints = "private"
  version = "3.3"
  users {
    name = var.etcd_username
    password = var.etcd_password
  }
}

# find the object in the connectionstrings list in which the `name` is var.etcd_username
locals {
  etcd_user_connectionstring = (var.create_external_etcd ?
                                ibm_database.etcd[0].connectionstrings[index(ibm_database.etcd[0].connectionstrings[*].name, var.etcd_username)] :
                                null)
}

resource "kubernetes_secret" "etcd" {
  count = var.create_external_etcd ? 1 : 0
  
  metadata {
    name = var.etcd_secret_name
    namespace = "kube-system"
  }

  data = {
    "ca.pem" = base64decode(local.etcd_user_connectionstring.certbase64)
    username = var.etcd_username
    password = var.etcd_password
  }
  
}

##################################
# Install Portworx on the cluster
##################################
resource "null_resource" "oc_login" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "oc login --token=${var.oc_token} --server=${var.oc_host} || exit $?"
  }
  
  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    command = "oc logout || true"
  }
}

# Install Portworx
resource "ibm_resource_instance" "portworx" {
  depends_on = [
    null_resource.volume_attachment,
    kubernetes_secret.etcd,
    null_resource.oc_login
  ]

  name              = "${var.unique_id}-pwx-service"
  service           = "portworx"
  plan              = "px-enterprise"
  location          = var.region
  resource_group_id = var.resource_group_id

  tags = [
    "clusterid:${var.cluster_id}",
  ]

  parameters = {
    apikey           = var.ibmcloud_api_key
    cluster_name     = "pwx"
    clusters         = var.cluster_id
    etcd_endpoint    = ( var.create_external_etcd ?
      "etcd:https://${local.etcd_user_connectionstring.hosts[0].hostname}:${local.etcd_user_connectionstring.hosts[0].port}"
      : null
    )
    etcd_secret      = var.create_external_etcd ? var.etcd_secret_name : null
    internal_kvdb    = var.create_external_etcd ? "external" : "internal"
    portworx_version = "Portworx: 2.5.7 , Stork: 2.4.4"
    secret_type      = "k8s"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/scripts/portworx_wait_until_ready.sh")
  }
  /*
  #
  # Currently, deleting the portworx service instance does not uninstall portworx
  # from the cluster.
  #
  */
}
