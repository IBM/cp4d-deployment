## Required and frequently used variables are listed here.
## Other variables from vars.tf may also be overridden in this file.

ibmcloud_api_key = <ibmcloud_key>
region = <region>

resource_group_name = <resource_group>

accept_cpd_license = "yes" # see vars.tf for a link to the license
cpd_registry_password = "<xxx_cpd_entitlement_key_xxx>" # retrieve from https://myibm.ibm.com/products-services/containerlibrary
operator_namespace = "ibm-common-services"

multizone = true

kube_version = "4.8_openshift"

worker_nodes_per_zone = "1"  #same as no. of workers per zone in the existing cluster 

no_of_zones = "3"

existing_vpc_id = "<existing_vpc_id>"
existing_vpc_subnets = ["<subnet_ID_1>", "<subnet_ID_2>", "<subnet_ID_3>"] 
existing_roks_cluster = <existing_cluster_name>

create_external_etcd = true

data_virtualization             = {"enable":"yes", "version":"1.7.2", "channel":"v1.7"}

watson_studio     = {"enable":"no", "version":"4.0.2", "channel":"v2.0"}

cpd_platform             = {"enable":"yes", "version":"4.0.2", "channel":"v2.0"}

cognos_dashboard_embedded     = {"enable":"no", "version":"4.0.2", "channel":"v1.0"}