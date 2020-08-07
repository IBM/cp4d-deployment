locals {
    cidr-prefix = split(".", var.virtual-network-cidr)[0]
}

data "template_file" "azurecreds" {
    template = file("../openshift_module/osServicePrincipal.tpl.json")
    vars = {
        subscription-id = var.azure-subscription-id
        client-id = var.azure-client-id
        client-secret = var.azure-client-secret
        tenant-id = var.azure-tenant-id
    }
}

data "template_file" "installconfig" {
    template = file("../openshift_module/${local.install-config-file}")
    vars = {
        baseDomainResourceGroupName = var.dnszone-resource-group
        region = var.region
        pullSecret = file("${var.pull-secret-file-path}")
        sshKey = var.ssh-public-key
        baseDomain = var.dnszone
        worker-instance-type = var.worker-instance-type
        master-instance-type = var.master-instance-type
        clustername = var.cluster-name
        virtualNetwork = var.virtual-network-name
        controlPlaneSubnet = var.master-subnet-name
        computeSubnet = var.worker-subnet-name
        networkResourceGroupName = local.resource-group

        cluster-network-cidr = "${local.cidr-prefix}.128.0.0/14"
        host-prefix = 23
        virtual-network-cidr = var.virtual-network-cidr
        service-network-cidr = "192.30.0.0/16"

        private-public = var.private-or-public-cluster == "public" ? "External" : "Internal"

        deploymentZone = var.zone
        workerNodeCount = var.worker-node-count
        masterNodeCount = var.master-node-count

        fips = var.fips
    }
}

data "template_file" "clusterautoscaler" {
    template = file("../openshift_module/cluster-autoscaler.tpl.yaml")
    vars = {
        max-total-nodes = 24
        pod-priority = -10
        min-cores = 48
        max-cores = 128
        min-memory = 128
        max-memory = 512
        scaledown-enabled = true 
        delay-after-add = "3m"
        delay-after-delete = "2m" 
        delay-after-failure = "30s" 
        unneeded-time = "60s"
    }
}

data "template_file" "machineautoscaler" {
    template = file("../openshift_module/machine-autoscaler.tpl.yaml")
    vars = {
        clusterid = random_id.randomId.hex
        region = var.region
    }
}

data "template_file" "machine-health-check" {
    template = file("../openshift_module/machine-health-check.tpl.yaml")
    vars = {
        clusterid = random_id.randomId.hex
        region = var.region
    }
}

data "template_file" "master-machineset" {
    template = file("../openshift_module/master-machineset.tpl.yaml")
    vars = {
        clusterid = random_id.randomId.hex
        region = var.region
        instance-type = var.master-instance-type
        vnet = var.virtual-network-name
        subnet = var.master-subnet-name
        networkResourceGroupName = local.resource-group
    }
}

data "template_file" "htpasswd" {
    template = file("../openshift_module/auth.yaml")
}

#OCS: Not supported on Azure yet
# data "template_file" "workerocs" {
#     template = "${file("../openshift_module/workerocs.tpl.yaml")}"
#     vars = {
#         clusterid = random_id.randomId.hex
#         machinetype = "worker"
#         region = "${var.region}"
#         instance-type = "${var.worker-instance-type}"
#     }
# }

data "template_file" "px-install" {
    template = file("../portworx_module/px-install.yaml")
}

data "template_file" "px-storageclasses" {
    template = file("../portworx_module/px-storageclasses.yaml")
}

data "template_file" "nfs-template" {
    count = var.storage == "nfs" ? 1 : 0
    template = file("../nfs_module/nfs-template.tpl.yaml")
    vars = {
        nfsserver = "${azurerm_network_interface.nfs[count.index].private_ip_address}"
        nfspath = "/exports/home"
    }
}
    
data "template_file" "repo" {
    template = file("../cpd_module/repo.tpl.yaml")
    vars = {
        apikeyusername = "cp"
        apikey = var.apikey
    }
}

data "template_file" "cpd-override" {
    template = file("../cpd_module/cpd-override.yaml")
    vars = {
        fips = var.fips
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
        minio-sec-obj1 = base64encode(var.openshift-username)
        minio-sec-obj2 = base64encode(var.openshift-password)
    }
}

data "template_file" "postgre-secret" {
    template = file("../cpd_module/postgre-secret.tpl.yaml")
    vars = {
        pg-sec-obj1 = base64encode(var.openshift-username)
        pg-sec-obj2 = base64encode(var.openshift-password)
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

data "template_file" "limits-mc" {
    template = file("../openshift_module/limits-machineconfig.yaml")
    vars = {
        limits-config-data = base64encode(file("../openshift_module/limits.conf"))
    }
}

data "template_file" "sysctl-mc" {
    template = file("../openshift_module/sysctl-machineconfig.yaml")
    vars = {
        sysctl-config-data = base64encode(file("../openshift_module/sysctl.conf"))
    }
}

data "template_file" "chrony-mc" {
    template = file("../openshift_module/chrony-machineconfig.yaml")
    vars = {
        chrony-config-data = base64encode(file("../openshift_module/chrony.conf"))
    }
}