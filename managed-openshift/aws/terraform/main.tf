provider "aws" {
  version    = "~> 2.0"
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

locals {
  installer_workspace = "${path.root}/installer-files"
  availability_zone1  = var.availability_zone1 == "" ? data.aws_availability_zones.azs.names[0] : var.availability_zone1
  availability_zone2  = var.availability_zone2 == "" ? data.aws_availability_zones.azs.names[1] : var.availability_zone2
  availability_zone3  = var.availability_zone3 == "" ? data.aws_availability_zones.azs.names[2] : var.availability_zone3
  vpc_id              = var.new_or_existing_vpc_subnet == "new" ? module.network[0].vpcid : var.vpc_id
  public_subnet1_id   = var.new_or_existing_vpc_subnet == "new" ? module.network[0].public_subnet1_id : var.public_subnet1_id
  public_subnet2_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].public_subnet2_id[0] : var.public_subnet2_id
  public_subnet3_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].public_subnet3_id[0] : var.public_subnet3_id
  private_subnet1_id   = var.new_or_existing_vpc_subnet == "new" ? module.network[0].private_subnet1_id : var.private_subnet1_id
  private_subnet2_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].private_subnet2_id[0] : var.private_subnet2_id
  private_subnet3_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].private_subnet3_id[0] : var.private_subnet3_id
  single_zone_subnets = [local.public_subnet1_id, local.private_subnet1_id]
  multi_zone_subnets  = [local.public_subnet1_id, local.private_subnet1_id, local.public_subnet2_id, local.private_subnet2_id, local.public_subnet3_id, local.private_subnet3_id]
}
resource "null_resource" "create_workspace" {
  provisioner "local-exec" {
    command = <<EOF
test -e ${local.installer_workspace} || mkdir -p ${local.installer_workspace}
EOF
  }
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

module "network" {
  count               = var.new_or_existing_vpc_subnet == "new" ? 1 : 0
  source              = "./network"
  vpc_cidr            = var.vpc_cidr
  network_tag_prefix  = var.cluster_name
  tenancy             = var.tenancy
  public_subnet_cidr1 = var.public_subnet_cidr1
  public_subnet_cidr2 = var.public_subnet_cidr2
  public_subnet_cidr3 = var.public_subnet_cidr3
  private_subnet_cidr1 = var.private_subnet_cidr1
  private_subnet_cidr2 = var.private_subnet_cidr2
  private_subnet_cidr3 = var.private_subnet_cidr3
  az                  = var.az
  availability_zone1  = local.availability_zone1
  availability_zone2  = local.availability_zone2
  availability_zone3  = local.availability_zone3

  depends_on = [
    null_resource.aws_configuration,
  ]
}

module "ocp" {
  source = "./ocp"
  rosa_token = var.rosa_token
  worker_machine_type = var.worker_machine_type
  worker_machine_count = var.worker_machine_count
  cluster_name = var.cluster_name
  region = var.region
  multi_zone                      = var.az == "multi_zone" ? true : false
  public_subnet1_id               = local.public_subnet1_id
  public_subnet2_id               = local.public_subnet2_id
  public_subnet3_id               = local.public_subnet3_id
  private_subnet1_id               = local.private_subnet1_id
  private_subnet2_id               = local.private_subnet2_id
  private_subnet3_id               = local.private_subnet3_id
  private_cluster                 = var.private_cluster
  cluster_network_cidr            = var.cluster_network_cidr
  cluster_network_host_prefix     = var.cluster_network_host_prefix
  machine_network_cidr            = var.vpc_cidr
  service_network_cidr            = var.service_network_cidr
  installer_workspace             = local.installer_workspace
  openshift_version               = var.openshift_version
  subnets = var.az == "multi_zone" ? local.multi_zone_subnets : local.single_zone_subnets

  depends_on = [
    null_resource.aws_configuration,
    module.network,
  ]
}

module "portworx" {
  count                 = var.portworx_enterprise.enable || var.portworx_essentials.enable || var.portworx_ibm.enable ? 1 : 0
  source                = "./portworx"
  openshift_api         = var.openshift_api
  openshift_username    = var.openshift_username
  openshift_password    = var.openshift_password
  openshift_token       = var.openshift_token
  installer_workspace   = local.installer_workspace
  region                = var.region
  aws_access_key_id     = var.access_key_id
  aws_secret_access_key = var.secret_access_key
  portworx_enterprise   = var.portworx_enterprise
  portworx_essentials   = var.portworx_essentials
  portworx_ibm          = var.portworx_ibm

  depends_on = [
    null_resource.create_workspace,
    module.ocp,
  ]
}

module "ocs" {
  count               = var.ocs.enable == "ocs" ? 1 : 0
  source              = "./ocs"
  openshift_username  = var.openshift_username
  openshift_password  = var.openshift_password
  openshift_api       = var.openshift_api
  openshift_token     = var.openshift_token
  installer_workspace = local.installer_workspace
  cluster_name = var.cluster_name
  ocs_instance_type = var.ocs.ocs_instance_type
}

module "cpd" {
  count                     = var.accept_cpd_license == "accept" ? 1 : 0
  source                    = "./cpd"
  vpc_id                    = var.vpcid
  openshift_api             = var.openshift_api
  openshift_username        = var.openshift_username
  openshift_password        = var.openshift_password
  openshift_token           = var.openshift_token
  installer_workspace       = local.installer_workspace
  accept_cpd_license        = var.accept_cpd_license
  cpd_external_registry     = ""
  cpd_external_username     = ""
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
    null_resource.create_workspace,
    module.portworx,
    module.ocp,
    module.efs,
  ]
}
