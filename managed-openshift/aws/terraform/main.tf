provider "aws" {
  region     = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key
}

locals {
  rootpath            = abspath(path.root)
  installer_workspace = "${local.rootpath}/installer-files"
  availability_zone1  = var.availability_zone1 == "" ? data.aws_availability_zones.azs.names[0] : var.availability_zone1
  availability_zone2  = var.az == "multi_zone" && var.availability_zone2 == "" ? data.aws_availability_zones.azs.names[1] : var.availability_zone2
  availability_zone3  = var.az == "multi_zone" && var.availability_zone3 == "" ? data.aws_availability_zones.azs.names[2] : var.availability_zone3
  vpc_id              = var.new_or_existing_vpc_subnet == "new" ? module.network[0].vpcid : var.vpc_id
  public_subnet1_id   = var.new_or_existing_vpc_subnet == "new" ? module.network[0].public_subnet1_id : var.public_subnet1_id
  public_subnet2_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].public_subnet2_id[0] : var.public_subnet2_id
  public_subnet3_id   = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].public_subnet3_id[0] : var.public_subnet3_id
  private_subnet1_id  = var.new_or_existing_vpc_subnet == "new" ? module.network[0].private_subnet1_id : var.private_subnet1_id
  private_subnet2_id  = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].private_subnet2_id[0] : var.private_subnet2_id
  private_subnet3_id  = var.new_or_existing_vpc_subnet == "new" && var.az == "multi_zone" ? module.network[0].private_subnet3_id[0] : var.private_subnet3_id
  single_zone_subnets = var.private_cluster ? [local.private_subnet1_id] : [local.public_subnet1_id, local.private_subnet1_id]
  multi_zone_subnets  = var.private_cluster ? [local.private_subnet1_id, local.private_subnet2_id, local.private_subnet3_id] : [local.public_subnet1_id, local.private_subnet1_id, local.public_subnet2_id, local.private_subnet2_id, local.public_subnet3_id, local.private_subnet3_id]
  login_cmd           = module.ocp.login_cmd
  cluster_type        = "managed"
}

data "aws_availability_zones" "azs" {}

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
  count                = var.new_or_existing_vpc_subnet == "new" ? 1 : 0
  source               = "./network"
  vpc_cidr             = var.vpc_cidr
  network_tag_prefix   = var.cluster_name
  tenancy              = var.tenancy
  public_subnet_cidr1  = var.public_subnet_cidr1
  public_subnet_cidr2  = var.public_subnet_cidr2
  public_subnet_cidr3  = var.public_subnet_cidr3
  private_subnet_cidr1 = var.private_subnet_cidr1
  private_subnet_cidr2 = var.private_subnet_cidr2
  private_subnet_cidr3 = var.private_subnet_cidr3
  az                   = var.az
  availability_zone1   = local.availability_zone1
  availability_zone2   = local.availability_zone2
  availability_zone3   = local.availability_zone3

  depends_on = [
    null_resource.aws_configuration,
  ]
}

module "ocp" {
  source                      = "./ocp"
  rosa_token                  = var.rosa_token
  worker_machine_type         = var.worker_machine_type
  worker_machine_count        = var.worker_machine_count
  cluster_name                = var.cluster_name
  region                      = var.region
  multi_zone                  = var.az == "multi_zone" ? true : false
  private_cluster             = var.private_cluster
  cluster_network_cidr        = var.cluster_network_cidr
  cluster_network_host_prefix = var.cluster_network_host_prefix
  machine_network_cidr        = var.vpc_cidr
  service_network_cidr        = var.service_network_cidr
  installer_workspace         = local.installer_workspace
  openshift_version           = var.openshift_version
  subnet_ids                  = var.az == "multi_zone" ? local.multi_zone_subnets : local.single_zone_subnets
  vpc_id                      = local.vpc_id

  depends_on = [
    null_resource.aws_configuration,
    module.network,
  ]
}

module "portworx" {
  count                 = var.portworx_enterprise.enable || var.portworx_essentials.enable || var.portworx_ibm.enable ? 1 : 0
  source                = "./portworx"
  installer_workspace   = local.installer_workspace
  region                = var.region
  aws_access_key_id     = var.access_key_id
  aws_secret_access_key = var.secret_access_key
  portworx_enterprise   = var.portworx_enterprise
  portworx_essentials   = var.portworx_essentials
  portworx_ibm          = var.portworx_ibm
  login_cmd             = "${local.login_cmd}"

  depends_on = [
    null_resource.create_workspace,
    module.ocp,
  ]
}

module "ocs" {
  count               = var.ocs.enable ? 1 : 0
  source              = "./ocs"
  installer_workspace = local.installer_workspace
  cluster_name        = var.cluster_name
  ocs_instance_type   = var.ocs.ocs_instance_type
  login_cmd           = "${local.login_cmd}"

  depends_on = [
    null_resource.create_workspace,
    module.ocp,
  ]
}

module "cpd" {
  count                     = var.accept_cpd_license == "accept" ? 1 : 0
  source                    = "./cpd"
  installer_workspace       = local.installer_workspace
  accept_cpd_license        = var.accept_cpd_license
  cpd_api_key               = var.cpd_api_key
  cpd_namespace             = var.cpd_namespace
  cloudctl_version          = var.cloudctl_version
  storage_option            = var.ocs.enable ? "ocs" : "portworx"
  cpd_platform              = var.cpd_platform
  data_virtualization       = var.data_virtualization
  analytics_engine          = var.analytics_engine
  watson_knowledge_catalog  = var.watson_knowledge_catalog
  watson_studio             = var.watson_studio
  watson_machine_learning   = var.watson_machine_learning
  watson_ai_openscale       = var.watson_ai_openscale
  cognos_dashboard_embedded = var.cognos_dashboard_embedded
  datastage                 = var.datastage
  db2_warehouse             = var.db2_warehouse
  cognos_analytics          = var.cognos_analytics
  spss_modeler              = var.spss_modeler
  data_management_console   = var.data_management_console
  db2_oltp                  = var.db2_oltp
  master_data_management    = var.master_data_management
  db2_aaservice             = var.db2_aaservice
  decision_optimization     = var.decision_optimization
  planning_analytics        = var.planning_analytics
  bigsql                    = var.bigsql
  cluster_type              = local.cluster_type
  login_string              = "${local.login_cmd} --insecure-skip-tls-verify=true"
  
  depends_on = [
    null_resource.create_workspace,
    module.portworx,
    module.ocp,
    module.ocs
  ]
}
