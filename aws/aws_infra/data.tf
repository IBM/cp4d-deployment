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
    count    = var.azlist == "multi_zone" ? 1 : 0
    template = file("../openshift_module/install-config-multi-zone.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(var.pull-secret-file-path)
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        fips-enable                 = var.fips-enable
        az1                         = local.avzone[0]
        az2                         = local.avzone[1]
        az3                         = local.avzone[2]
        subnet-1                    = aws_subnet.public1.id
        subnet-2                    = aws_subnet.public2.id
        subnet-3                    = aws_subnet.public3.id
        subnet-4                    = aws_subnet.private1.id
        subnet-5                    = aws_subnet.private2.id
        subnet-6                    = aws_subnet.private3.id
        private-public              = var.private-or-public-cluster == "public" ? "External" : "Internal"
    }
}

data "template_file" "installconfig-1AZ" {
    count    = var.azlist == "single_zone" ? 1 : 0
    template = file("../openshift_module/install-config-single-zone.tpl.yaml")
    vars = {
        region                      = var.region
        pullSecret                  = file(var.pull-secret-file-path)
        sshKey                      = var.ssh-public-key
        baseDomain                  = var.dnszone
        master_replica_count        = var.master_replica_count
        worker_replica_count        = var.worker_replica_count
        worker-instance-type        = var.worker-instance-type
        master-instance-type        = var.master-instance-type
        clustername                 = var.cluster-name
        fips-enable                 = var.fips-enable
        az1                         = local.avzone[0]
        subnet-1                    = aws_subnet.public1.id
        subnet-2                    = aws_subnet.private1.id
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
    template = file("../openshift_module/machine-autoscaler.tpl.yaml")
    vars = {
        machinetype   = "worker"
        region        = var.region
        az1           = local.avzone[0]
        az2           = local.avzone[1]
        az3           = local.avzone[2]
    }
}

data "template_file" "workerocs" {
    template = file("../openshift_module/workerocs.tpl.yaml")
    vars = {
        region        = var.region
        instance-type = var.worker-ocs-instance-type
        ami_id        = lookup(var.images-rcos,var.region)
        cluster-name  = var.cluster-name
        az1           = local.avzone[0]
        az2           = local.avzone[1]
        az3           = local.avzone[2]
    }
}

data "template_file" "machinehealthcheck" {
    template = file("../openshift_module/machine-health-check.tpl.yaml")
    vars = {
        az1           = local.avzone[0]
        az2           = local.avzone[1]
        az3           = local.avzone[2]
    }
}

data "template_file" "repo" {
    template = file("../cpd_module/repo.tpl.yaml")
    vars = {
        entitlementkey = var.entitlementkey,
    }
}

data "template_file" "portworx-override" {
    template = file("../cpd_module/portworx-override.yaml")
    vars = {
        fips = var.fips-enable,
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
