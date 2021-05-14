provider "aws" {
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

data "aws_availability_zones" "azs" {}

locals {
  installer_workspace = "${path.root}/installer-files"
  availability_zone1  = var.availability_zone1 == "" ? data.aws_availability_zones.azs.names[0] : var.availability_zone1
  availability_zone2  = var.availability_zone2 == "" ? data.aws_availability_zones.azs.names[1] : var.availability_zone2
  availability_zone3  = var.availability_zone3 == "" ? data.aws_availability_zones.azs.names[2] : var.availability_zone3
  vpc_id              = var.new_or_existing_vpc_subnet == "new" ? module.network[0].vpcid : var.vpc_id
  master_subnet1_id   = var.new_or_existing_vpc_subnet == "new" ? module.network[0].master_subnet1_id : var.master_subnet1_id
  master_subnet2_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].master_subnet2_id[0] : var.master_subnet2_id
  master_subnet3_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].master_subnet3_id[0] : var.master_subnet3_id
  worker_subnet1_id   = var.new_or_existing_vpc_subnet == "new" ? module.network[0].worker_subnet1_id : var.worker_subnet1_id
  worker_subnet2_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].worker_subnet2_id[0] : var.worker_subnet2_id
  worker_subnet3_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].worker_subnet3_id[0] : var.worker_subnet3_id
  single_zone_subnets = [local.worker_subnet1_id]
  multi_zone_subnets  = [local.worker_subnet1_id, local.worker_subnet2_id, local.worker_subnet3_id]
}

resource "null_resource" "aws_configuration" {
  provisioner "local-exec" {
    command = "mkdir -p ~/.aws"
  }

  provisioner "local-exec" {
    command = <<EOF
echo '${data.template_file.aws_credentials.rendered}' > ~/.aws/credentials
echo '${data.template_file.aws_config.rendered}' > ~/.aws/config
EOF
  }
}

data "template_file" "aws_credentials" {
  template = <<-EOF
[default]
aws_access_key_id = ${var.access_key_id}
aws_secret_access_key = ${var.secret_access_key}
EOF
}

data "template_file" "aws_config" {
  template = <<-EOF
[default]
region = ${var.region}
EOF
}

/* resource "null_resource" "permission_resource_validation" {
  provisioner "local-exec" {
    command = <<EOF
  chmod +x scripts/*.sh scripts/*.py
  scripts/aws_permission_validation.sh ; if [ $? -ne 0 ] ; then echo \"Permission Verification Failed\" ; exit 1 ; fi
  echo file | scripts/aws_resource_quota_validation.sh ; if [ $? -ne 0 ] ; then echo \"Resource Quota Validation Failed\" ; exit 1 ; fi
  EOF
  }
} */

module "network" {
  count               = var.new_or_existing_vpc_subnet == "new" && var.existing_cluster == false ? 1 : 0
  source              = "./network"
  vpc_cidr            = var.vpc_cidr
  network_tag_prefix  = var.cluster_name
  tenancy             = var.tenancy
  master_subnet_cidr1 = var.master_subnet_cidr1
  master_subnet_cidr2 = var.master_subnet_cidr2
  master_subnet_cidr3 = var.master_subnet_cidr3
  worker_subnet_cidr1 = var.worker_subnet_cidr1
  worker_subnet_cidr2 = var.worker_subnet_cidr2
  worker_subnet_cidr3 = var.worker_subnet_cidr3
  az                  = var.az
  availability_zone1  = local.availability_zone1
  availability_zone2  = local.availability_zone2
  availability_zone3  = local.availability_zone3

  depends_on = [
    null_resource.aws_configuration,
  ]
}

module "ocp" {
  count                           = var.existing_cluster ? 0 : 1
  source                          = "./ocp"
  openshift_installer_url         = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
  multi_zone                      = var.az == "multi_zone" ? true : false
  cluster_name                    = var.cluster_name
  base_domain                     = var.base_domain
  region                          = var.region
  availability_zone1              = local.availability_zone1
  availability_zone2              = local.availability_zone2
  availability_zone3              = local.availability_zone3
  worker_instance_type            = var.worker_instance_type
  worker_instance_volume_iops     = var.worker_instance_volume_iops
  worker_instance_volume_type     = var.worker_instance_volume_type
  worker_instance_volume_size     = var.worker_instance_volume_size
  worker_replica_count            = var.worker_replica_count
  master_instance_type            = var.master_instance_type
  master_instance_volume_iops     = var.master_instance_volume_iops
  master_instance_volume_type     = var.master_instance_volume_type
  master_instance_volume_size     = var.master_instance_volume_size
  master_replica_count            = var.master_replica_count
  cluster_network_cidr            = var.cluster_network_cidr
  cluster_network_host_prefix     = var.cluster_network_host_prefix
  machine_network_cidr            = var.vpc_cidr
  service_network_cidr            = var.service_network_cidr
  master_subnet1_id               = local.master_subnet1_id
  master_subnet2_id               = local.master_subnet2_id
  master_subnet3_id               = local.master_subnet3_id
  worker_subnet1_id               = local.worker_subnet1_id
  worker_subnet2_id               = local.worker_subnet2_id
  worker_subnet3_id               = local.worker_subnet3_id
  private_cluster                 = var.private_cluster
  openshift_pull_secret_file_path = var.openshift_pull_secret_file_path
  public_ssh_key                  = var.public_ssh_key
  enable_fips                     = var.enable_fips
  openshift_username              = var.openshift_username
  openshift_password              = var.openshift_password
  enable_autoscaler               = var.enable_autoscaler
  installer_workspace             = local.installer_workspace
  openshift_version               = var.openshift_version

  depends_on = [
    module.network,
    null_resource.aws_configuration,
  ]
}

module "portworx" {
  count               = var.storage_option == "portworx" ? 1 : 0
  source              = "./portworx"
  openshift_api       = var.existing_cluster ? var.existing_openshift_api : module.ocp[0].openshift_api
  openshift_username  = var.existing_cluster ? var.existing_openshift_username : module.ocp[0].openshift_username
  openshift_password  = var.existing_cluster ? var.existing_openshift_password : module.ocp[0].openshift_password
  openshift_token     = var.existing_openshift_token
  installer_workspace = local.installer_workspace
  region              = var.region
  aws_access_key_id        = var.access_key_id
  aws_secret_access_key = var.secret_access_key
  px_generated_cluster_id = var.px_generated_cluster_id
  px_encryption = var.px_encryption

  depends_on = [
    module.ocp,
    module.network,
    null_resource.aws_configuration,
  ]
}

module "ibm-portworx" {
  count               = var.storage_option == "ibm-portworx" ? 1 : 0
  source              = "./ibm-portworx"
  openshift_api       = var.existing_cluster ? var.existing_openshift_api : module.ocp[0].openshift_api
  openshift_username  = var.existing_cluster ? var.existing_openshift_username : module.ocp[0].openshift_username
  openshift_password  = var.existing_cluster ? var.existing_openshift_password : module.ocp[0].openshift_password
  openshift_token     = var.existing_openshift_token
  installer_workspace = local.installer_workspace
  region              = var.region
  aws_access_key_id        = var.access_key_id
  aws_secret_access_key = var.secret_access_key

  depends_on = [
    module.ocp,
    module.network,
    null_resource.aws_configuration,
  ]
}

module "ocs" {
  count               = var.storage_option == "ocs" ? 1 : 0
  source              = "./ocs"
  openshift_api       = var.existing_cluster ? var.existing_openshift_api : module.ocp[0].openshift_api
  openshift_username  = var.existing_cluster ? var.existing_openshift_username : module.ocp[0].openshift_username
  openshift_password  = var.existing_cluster ? var.existing_openshift_password : module.ocp[0].openshift_password
  openshift_token     = var.existing_openshift_token
  installer_workspace = local.installer_workspace

  depends_on = [
    module.ocp,
    module.network,
    null_resource.aws_configuration,
  ]
}

module "efs" {
  count               = var.storage_option == "efs" ? 1 : 0
  source              = "./efs"
  vpc_id              = local.vpc_id
  vpc_cidr            = var.vpc_cidr
  efs_name            = "${var.cluster_name}-efs"
  openshift_api       = var.existing_cluster ? var.existing_openshift_api : module.ocp[0].openshift_api
  openshift_username  = var.existing_cluster ? var.existing_openshift_username : module.ocp[0].openshift_username
  openshift_password  = var.existing_cluster ? var.existing_openshift_password : module.ocp[0].openshift_password
  openshift_token     = var.existing_openshift_token
  installer_workspace = local.installer_workspace
  region              = var.region
  subnets             = var.az == "multi_zone" ? local.multi_zone_subnets : local.single_zone_subnets

  depends_on = [
    module.ocp,
    module.network,
    null_resource.aws_configuration,
  ]
}

module "cpd" {
  count                     = var.accept_cpd_license == "accept" ? 1 : 0
  source                    = "./cpd"
  openshift_api             = var.existing_cluster ? var.existing_openshift_api : module.ocp[0].openshift_api
  openshift_username        = var.existing_cluster ? var.existing_openshift_username : module.ocp[0].openshift_username
  openshift_password        = var.existing_cluster ? var.existing_openshift_password : module.ocp[0].openshift_password
  openshift_token           = var.existing_openshift_token
  installer_workspace       = local.installer_workspace
  accept_cpd_license        = var.accept_cpd_license
  cpd_external_registry     = var.cpd_external_registry
  cpd_external_username     = var.cpd_external_username
  api_key                   = var.api_key
  cpd_namespace             = var.cpd_namespace
  cloudctl_version          = var.cloudctl_version
  datacore_version          = var.datacore_version
  storage_option            = var.storage_option
  data_virtualization       = var.data_virtualization
  apache_spark              = var.apache_spark
  watson_knowledge_catalog  = var.watson_knowledge_catalog
  watson_studio_library     = var.watson_studio_library
  watson_machine_learning   = var.watson_machine_learning
  watson_ai_openscale       = var.watson_ai_openscale
  cognos_dashboard_embedded = var.cognos_dashboard_embedded
  streams                   = var.streams
  streams_flows             = var.streams_flows
  datastage                 = var.datastage
  db2_warehouse             = var.db2_warehouse
  db2_advanced_edition      = var.db2_advanced_edition
  data_management_console   = var.data_management_console
  datagate                  = var.datagate
  decision_optimization     = var.decision_optimization
  cognos_analytics          = var.cognos_analytics
  spss_modeler              = var.spss_modeler
  db2_bigsql                = var.db2_bigsql
  planning_analytics        = var.planning_analytics

  depends_on = [
    module.ocp,
    module.network,
    module.portworx,
    module.ibm-portworx,
    module.ocs,
    module.efs,
    null_resource.aws_configuration,
  ]
}
