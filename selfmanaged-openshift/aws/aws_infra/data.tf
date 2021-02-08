data "template_file" "awscreds" {
    template = file("./aws_cred")
    vars = {
        access_key = var.access_key_id
        secret_access_key = var.secret_access_key
    }
}

data "template_file" "awsregion" {
    template = file("./aws_region")
    vars = {
        aws_region = var.region
    }
}

data "template_file" "installconfig" {
    count    = var.azlist == "multi_zone" && var.only-private-subnets == "no" ? 1 : 0
    template = file("../openshift_module/install-config-multi-zone.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(trimspace(var.pull-secret-file-path))
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        clusternetworkcidr          = var.cluster_network_cidr
        vpccidr                     = var.vpc_cidr
        fips-enable                 = var.fips-enable
        az1                         = coalesce(var.availability-zone1, local.avzone[0])
        az2                         = coalesce(var.availability-zone2, local.avzone[1])
        az3                         = coalesce(var.availability-zone3, local.avzone[2])
        public-subnet-1             = coalesce(var.subnetid-public1,join("",aws_subnet.public1[*].id))
        public-subnet-2             = coalesce(var.subnetid-public2,join("",aws_subnet.public2[*].id))
        public-subnet-3             = coalesce(var.subnetid-public3,join("",aws_subnet.public3[*].id))
        private-subnet-1            = coalesce(var.subnetid-private1,join("",aws_subnet.private1[*].id))
        private-subnet-2            = coalesce(var.subnetid-private2,join("",aws_subnet.private2[*].id))
        private-subnet-3            = coalesce(var.subnetid-private3,join("",aws_subnet.private3[*].id))
        private-public              = var.private-or-public-cluster == "public" ? "External" : "Internal"
    }
}

data "template_file" "installconfig-1AZ" {
    count    = var.azlist == "single_zone" && var.only-private-subnets == "no" ? 1 : 0
    template = file("../openshift_module/install-config-single-zone.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(trimspace(var.pull-secret-file-path))
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        clusternetworkcidr          = var.cluster_network_cidr
        vpccidr                     = var.vpc_cidr
        fips-enable                 = var.fips-enable
        az1                         = coalesce(var.availability-zone1, local.avzone[0])
        public-subnet-1             = coalesce(var.subnetid-public1,join("",aws_subnet.public1[*].id))
        private-subnet-1            = coalesce(var.subnetid-private1,join("",aws_subnet.private1[*].id))
        private-public              = var.private-or-public-cluster == "public" ? "External" : "Internal"
    }
}

data "template_file" "installconfig-private" {
    count    = var.azlist == "multi_zone" && var.only-private-subnets == "yes" ? 1 : 0
    template = file("../openshift_module/install-config-multi-zone-private-subnet.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(trimspace(var.pull-secret-file-path))
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        clusternetworkcidr          = var.cluster_network_cidr
        vpccidr                     = var.vpc_cidr
        fips-enable                 = var.fips-enable
        az1                         = coalesce(var.availability-zone1, local.avzone[0])
        az2                         = coalesce(var.availability-zone2, local.avzone[1])
        az3                         = coalesce(var.availability-zone3, local.avzone[2])
        private-subnet-1            = coalesce(var.subnetid-private1,join("",aws_subnet.private1[*].id))
        private-subnet-2            = coalesce(var.subnetid-private2,join("",aws_subnet.private2[*].id))
        private-subnet-3            = coalesce(var.subnetid-private3,join("",aws_subnet.private3[*].id))
        private-public              = var.private-or-public-cluster == "public" ? "External" : "Internal"
    }
}

data "template_file" "installconfig-1AZ-private" {
    count    = var.azlist == "single_zone" && var.only-private-subnets == "yes" ? 1 : 0
    template = file("../openshift_module/install-config-single-zone-private-subnet.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(trimspace(var.pull-secret-file-path))
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        clusternetworkcidr          = var.cluster_network_cidr
        vpccidr                     = var.vpc_cidr
        fips-enable                 = var.fips-enable
        az1                         = coalesce(var.availability-zone1, local.avzone[0])
        private-subnet-1            = coalesce(var.subnetid-private1,join("",aws_subnet.private1[*].id))
        private-public              = var.private-or-public-cluster == "public" ? "External" : "Internal"
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

data "template_file" "machineautoscaler" {
    count    = var.azlist == "multi_zone" ? 1 : 0
    template = file("../openshift_module/machine-autoscaler.tpl.yaml")
    vars = {
        machinetype   = "worker"
        region        = var.region
        az1           = coalesce(var.availability-zone1, local.avzone[0])
        az2           = coalesce(var.availability-zone2, local.avzone[1])
        az3           = coalesce(var.availability-zone3, local.avzone[2])
    }
}

data "template_file" "machineautoscaler-1AZ" {
    count    = var.azlist == "single_zone" ? 1 : 0
    template = file("../openshift_module/machine-autoscaler-1AZ.tpl.yaml")
    vars = {
        machinetype   = "worker"
        region        = var.region
        az1           = coalesce(var.availability-zone1, local.avzone[0])
    }
}

data "template_file" "workerocs" {
    count    = var.azlist == "multi_zone" ? 1 : 0
    template = file("../openshift_module/workerocs.tpl.yaml")
    vars = {
        region        = var.region
        instance-type = var.worker-ocs-instance-type
        ami_id        = lookup(var.images-rcos,var.region)
        cluster-name  = var.cluster-name
        az1           = coalesce(var.availability-zone1, local.avzone[0])
        az2           = coalesce(var.availability-zone2, local.avzone[1])
        az3           = coalesce(var.availability-zone3, local.avzone[2])
    }
}

data "template_file" "workerocs-1AZ" {
    count    = var.azlist == "single_zone" ? 1 : 0
    template = file("../openshift_module/workerocs.tpl.yaml")
    vars = {
        region        = var.region
        instance-type = var.worker-ocs-instance-type
        ami_id        = lookup(var.images-rcos,var.region)
        cluster-name  = var.cluster-name
        az1           = coalesce(var.availability-zone1, local.avzone[0])
        az2           = coalesce(var.availability-zone1, local.avzone[0])
        az3           = coalesce(var.availability-zone1, local.avzone[0])
    }
}

data "template_file" "machinehealthcheck" {
    count    = var.azlist == "multi_zone" ? 1 : 0
    template = file("../openshift_module/machine-health-check.tpl.yaml")
    vars = {
        az1           = coalesce(var.availability-zone1, local.avzone[0])
        az2           = coalesce(var.availability-zone2, local.avzone[1])
        az3           = coalesce(var.availability-zone3, local.avzone[2])
    }
}

data "template_file" "machinehealthcheck-1AZ" {
    count    = var.azlist == "single_zone" ? 1 : 0
    template = file("../openshift_module/machine-health-check-1AZ.tpl.yaml")
    vars = {
        az1           = coalesce(var.availability-zone1, local.avzone[0])
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

data "template_file" "portworx-override" {
    template = file("../cpd_module/portworx-override.yaml")
    vars = {
        fips = var.fips-enable,
    }
}

data "template_file" "watson-asst-override" {
    template = file("../cpd_module/watson-asst-override.tpl.yaml")
    vars = {
        storageclass = local.watson-asst-storageclass
    }
}

data "template_file" "watson-discovery-override" {
    template = file("../cpd_module/watson-discovery-override.tpl.yaml")
    vars = {
        storageclass = local.watson-discovery-storageclass
        k8_host = "api.${var.cluster-name}.${var.dnszone}"
    }
}

data "template_file" "watson-language-translator-override" {
    template = file("../cpd_module/watson-language-translator-override.tpl.yaml")
    vars = {
        storageclass = local.watson-lt-storageclass
        namespace = var.cpd-namespace
    }
}

data "template_file" "watson-speech-override" {
    template = file("../cpd_module/watson-speech-override.tpl.yaml")
    vars = {
        namespace = var.cpd-namespace
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
        pg-su-passwd = base64encode(var.openshift-password)
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
