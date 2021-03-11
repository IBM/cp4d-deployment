locals {
  cidr-prefix = split(".", var.virtual-network-cidr)[0]
}

data "template_file" "azurecreds" {
  template = file("../openshift_module/osServicePrincipal.tpl.json")
  vars = {
    subscription-id = var.azure-subscription-id
    client-id       = var.azure-client-id
    client-secret   = var.azure-client-secret
    tenant-id       = var.azure-tenant-id
  }
}

data "template_file" "installconfig" {
  count    = var.disconnected-cluster == "no" ? 1 : 0
  template = file("../openshift_module/install-config.tpl.yaml")
  vars = {
    baseDomainResourceGroupName = var.dnszone-resource-group
    region                      = var.region
    pullSecret                  = file(var.pull-secret-file-path)
    sshKey                      = var.ssh-public-key
    baseDomain                  = var.dnszone
    //worker-instance-type = var.worker-instance-type
    //master-instance-type = var.master-instance-type
    clustername = var.cluster-name
    //virtualNetwork = var.virtual-network-name
    controlPlaneSubnet = var.master-subnet-name
    computeSubnet      = var.worker-subnet-name
    //networkResourceGroupName = local.resource-group

    cluster-network-cidr = "${local.cidr-prefix}.128.0.0/14"
    host-prefix          = 23
    virtual-network-cidr = var.virtual-network-cidr
    service-network-cidr = "172.30.0.0/16"

    private-public = var.private-or-public-cluster == "public" ? "External" : "Internal"

    //deploymentZone = var.zone
    workerNodeCount = var.worker-node-count
    masterNodeCount = var.master-node-count


  }
}

data "template_file" "installconfig-disconnected" {
  count    = var.disconnected-cluster == "yes" ? 1 : 0
  template = file("../openshift_module/install-config-disconnected.tpl.yaml")
  vars = {
    baseDomainResourceGroupName = var.dnszone-resource-group
    region                      = var.region
    pullSecret                  = file(var.pull-secret-json-path)
    sshKey                      = var.ssh-public-key
    baseDomain                  = var.dnszone
    //worker-instance-type = var.worker-instance-type
    //master-instance-type = var.master-instance-type
    clustername = var.cluster-name
    //virtualNetwork = var.virtual-network-name
    controlPlaneSubnet = var.master-subnet-name
    computeSubnet      = var.worker-subnet-name
    //networkResourceGroupName = local.resource-group

    cluster-network-cidr = "${local.cidr-prefix}.128.0.0/14"
    host-prefix          = 23
    virtual-network-cidr = var.virtual-network-cidr
    service-network-cidr = "172.30.0.0/16"

    private-public = var.private-or-public-cluster == "public" ? "External" : "Internal"

    //deploymentZone = var.zone
    workerNodeCount     = var.worker-node-count
    masterNodeCount     = var.master-node-count
    certificate         = jsonencode(file(var.certificate-file-path))
    local_registry_repo = var.local-registry-repository

  }
}

data "template_file" "dnsconfig" {
  template = file("../openshift_module/cluster-dns-02-config.tpl.yml")
  vars = {
    baseDomain = var.dnszone
  }
}

data "template_file" "vnet" {
  template = file("../openshift_module/01_vnet.tpl.json")
  vars = {
    cluster-vnet-cidr-range  = var.cluster-cidr
    master-subnet-cidr-range = var.master-subnet-cidr
    worker-subnet-cidr-range = var.worker-subnet-cidr
  }
}

data "template_file" "storage" {
  template = file("../openshift_module/02_storage.tpl.json")
  vars = {
  }
}

data "template_file" "infra" {
  template = file("../openshift_module/03_infra.tpl.json")
  vars = {
  }
}

data "template_file" "bootstrap" {
  template = file("../openshift_module/04_bootstrap.tpl.json")
  vars = {
  }
}

data "template_file" "masters" {
  template = file("../openshift_module/05_masters.tpl.json")
  vars = {
    master_instance_type = var.master-instance-type
  }
}

data "template_file" "workers" {
  template = file("../openshift_module/06_workers.tpl.json")
  vars = {
    worker_instance_type = var.worker-instance-type
  }
}

data "template_file" "htpasswd" {
  template = file("../openshift_module/auth.yaml")
}

data "template_file" "nfs-template" {
  count    = var.storage == "nfs" ? 1 : 0
  template = file("../nfs_module/nfs-template.tpl.yaml")
  vars = {
    nfspath = "/exports/home"
  }
}

data "template_file" "cpd-service" {
  template = file("../cpd-module/cpd-service.tpl.yaml")
  vars = {
    cpd-version    = var.cpd-version
    overrideValue  = local.override-value
    autopatch      = "false"
    license-accept = "true"
  }
}

data "template_file" "cpd-service-no-override" {
  template = file("../cpd-module/cpd-service-no-override.tpl.yaml")
  vars = {
    cpd-version    = var.cpd-version
    autopatch      = "false"
    license-accept = "true"
  }
}

data "template_file" "machine-health-check" {
  template = file("../openshift_module/${local.machine-health-check-file}")
  vars = {
    clusterid = random_id.randomId.hex
    region    = var.region
    zone      = var.zone
  }
}

data "template_file" "repo" {
  template = file("../cpd-module/repo.tpl.yaml")
  vars = {
    apikey = var.apikey,
  }
}

data "template_file" "px-install" {
    template = file("../portworx_module/px-install.yaml")
}

data "template_file" "px-storageclasses" {
    template = file("../portworx_module/px-storageclasses.yaml")
}