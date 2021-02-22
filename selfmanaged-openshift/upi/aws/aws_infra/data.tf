data "template_file" "awscreds" {
  template = file("./aws_cred")
  vars = {
    access_key        = var.access_key_id
    secret_access_key = var.secret_access_key
  }
}

data "template_file" "awsregion" {
  template = file("./aws_region")
  vars = {
    aws_region = var.region
  }
}

data "template_file" "vpc-subnet" {
  template = file("../infra-templates/vpc-parameter.tpl.json")
  vars = {
    vpccidr    = var.vpc_cidr
    azcount    = lookup(var.image-replica, var.azlist)
    subnetbits = var.subnet-bits
  }
}

data "template_file" "installconfig" {
  count    = var.disconnected-cluster == "no" ? 1 : 0
  template = file("../openshift_module/install-config.tpl.yaml")
  vars = {
    baseDomain           = var.dnszone
    master_replica_count = var.master_replica_count
    clustername          = var.cluster-name
    clusternetworkcidr   = var.cluster_network_cidr
    vpccidr              = var.vpc_cidr
    region               = var.region
    pullSecret           = file(var.pull-secret-file-path)
    fips-enable          = var.fips-enable
    sshKey               = var.ssh-public-key
    private-public       = var.private-or-public-cluster == "public" ? "External" : "Internal"
  }
}

data "template_file" "installconfig-disconnected" {
  count    = var.disconnected-cluster == "yes" ? 1 : 0
  template = file("../openshift_module/install-config-disconnected.tpl.yaml")
  vars = {
    baseDomain           = var.dnszone
    master_replica_count = var.master_replica_count
    clustername          = var.cluster-name
    clusternetworkcidr   = var.cluster_network_cidr
    vpccidr              = var.vpc_cidr
    region               = var.region
    pullSecret           = file(var.pull-secret-file-path)
    fips-enable          = var.fips-enable
    sshKey               = var.ssh-public-key
    private-public       = var.private-or-public-cluster == "public" ? "External" : "Internal"
    certificate          = jsonencode(file(var.certificate-file-path))
    local_registry_repo  = var.local-registry-repository
  }
}

data "template_file" "nlb" {
  template = file("../infra-templates/nlb-parameter.tpl.json")
  vars = {
    clustername    = var.cluster-name
    hostedzoneid   = var.hosted-zoneid
    hostedzonename = var.dnszone
    publicsubnets  = coalesce(chomp(data.local_file.publicsubnet.content), local.public-subnet-exist)
    privatesubnets = coalesce(chomp(data.local_file.privatesubnet.content), local.private-subnet-exist)
    vpcid          = local.vpcid
  }
}

data "template_file" "sg-role" {
  template = file("../infra-templates/sg-role-parameter.tpl.json")
  vars = {
    vpccidr        = var.vpc_cidr
    privatesubnets = coalesce(chomp(data.local_file.privatesubnet.content), local.private-subnet-exist)
    vpcid          = local.vpcid
  }
}

data "template_file" "bootstrap" {
  template = file("../infra-templates/bootstrap-parameter.tpl.json")
  vars = {
    amiid        = lookup(var.images-rcos, var.region)
    publicsubnet = coalesce(local.subnetspub[0], var.subnetid-public1)
    vpcid        = local.vpcid
    bucket       = format("${var.cluster-name}-%s", "infra")
  }
}

data "template_file" "controlplane" {
  template = file("../infra-templates/controlplane-parameter.tpl.json")
  vars = {
    amiid                = lookup(var.images-rcos, var.region)
    clustername          = var.cluster-name
    domain-name          = var.dnszone
    private-subnet1      = coalesce(local.subnetspri[0], var.subnetid-private1)
    private-subnet2      = coalesce(local.subnetspri[1], var.subnetid-private2)
    private-subnet3      = coalesce(local.subnetspri[2], var.subnetid-private3)
    master-instance-type = var.master-instance-type
  }
}

data "template_file" "workernode" {
  template = file("../infra-templates/workernode-parameter.tpl.json")
  vars = {
    amiid                = lookup(var.images-rcos, var.region)
    clustername          = var.cluster-name
    domain-name          = var.dnszone
    worker-instance-type = var.worker-instance-type
  }
}

data "template_file" "clusterautoscaler" {
  template = file("../openshift_module/cluster-autoscaler.tpl.yaml")
  vars = {
    max-total-nodes     = 24
    pod-priority        = -10
    min-cores           = 48
    max-cores           = 128
    min-memory          = 128
    max-memory          = 512
    scaledown-enabled   = true
    delay-after-add     = "3m"
    delay-after-delete  = "2m"
    delay-after-failure = "3m"
    unneeded-time       = "300m"
  }
}

data "template_file" "machinehealthcheck" {
  count    = var.azlist == "multi_zone" ? 1 : 0
  template = file("../openshift_module/machine-health-check.tpl.yaml")
  vars = {
    az1 = local.avzone[0]
    az2 = local.avzone[1]
    az3 = local.avzone[2]
  }
}

data "template_file" "machinehealthcheck-1AZ" {
  count    = var.azlist == "single_zone" ? 1 : 0
  template = file("../openshift_module/machine-health-check-1AZ.tpl.yaml")
  vars = {
    az1 = local.avzone[0]
  }
}

data "template_file" "cpd-service" {
    template = file("../cpd_module/cpd-service.tpl.yaml")
    vars = {
        cpd-version         = var.cpd-version
        override-storage    = local.override-value 
        autopatch           = "false"
        license-accept      = "true"
    }
}

data "template_file" "cpd-service-no-override" {
    template = file("../cpd_module/cpd-service-no-override.tpl.yaml")
    vars = {
        cpd-version         = var.cpd-version
        autopatch           = "false"
        license-accept      = "true"
    }
}

data "template_file" "repo" {
    template = file("../cpd_module/repo.tpl.yaml")
    vars = {
        apikey = var.api-key,
    }
}

data "template_file" "redhat-operator" {
  template = file("../ocs_module/redhat-operator-catalogsource.yaml")
  vars = {
    registry = var.local-registry,
  }
}

data "template_file" "minio-secret" {
  template = file("../cpd_module/minio-secret.tpl.yaml")
  vars = {
    minio-access-key = base64encode(var.openshift-username)
    minio-secret-key = base64encode(var.openshift-password)
  }
}

data "template_file" "postgre-secret" {
  template = file("../cpd_module/postgre-secret.tpl.yaml")
  vars = {
    pg-repl-passwd = base64encode(var.openshift-username)
    pg-su-passwd   = base64encode(var.openshift-password)
  }
}

data "template_file" "registry-conf" {
  template = file("../openshift_module/registries.tpl.conf")
  vars = {
    registry-route = "default-route-openshift-image-registry.apps.${var.cluster-name}.${var.dnszone}"
  }
}

data "template_file" "registry-mc" {
  template = file("../openshift_module/insecure-registry-machineconfig.yaml")
  vars = {
    config-data = base64encode(data.template_file.registry-conf.rendered)
  }
}

data "template_file" "crio-mc" {
  template = file("../openshift_module/crio-machineconfig.yaml")
  vars = {
    crio-config-data = base64encode(file("../openshift_module/crio.conf"))
  }
}

data "template_file" "security-limits-mc" {
  template = file("../openshift_module/security-limits-machineconfig.yaml")
  vars = {
    limits-config-data = base64encode(file("../openshift_module/limits.conf"))
  }
}

data "template_file" "sysctl-machineconfig" {
  template = file("../openshift_module/sysctl-machineconfig.yaml")
  vars = {
    sysctl-config-data = base64encode(file("../openshift_module/sysctl.conf"))
  }
}

data "template_file" "efs-configmap" {
  template = file("../efs_module/efs-configmap.yaml")
  vars = {
    region = var.region,
  }
}
