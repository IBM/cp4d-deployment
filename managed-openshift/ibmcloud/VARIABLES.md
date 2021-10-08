|Variable name                      |Default                                                  |Description |
|-----------------------------------|:-------------------------------------------------------:|------------|
|`ibmcloud_api_key`                 | Required                                                 | IBM Cloud API key. Steps to create the api_key - https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui#create_user_key
|`region`                           | Required                                                 | IBM Cloud region where all resources will be deployed
|`resource_group_name`              | `default`                                                | Name of the IBM Cloud resource group in which resources should be created
|`unique_id`                        | `cp4d-roks-tf`                                           | Unique string for naming resources
|`accept_cpd_license`               | Required                                                 | I have read and agree to the license terms for IBM Cloud Pak for Data at https://ibm.biz/BdfEkc [yes/no]
|`cpd_registry_username`            | `cp`                                                     |
|`cpd_registry_password`            | Required                                                 | Can be fetched from https://myibm.ibm.com/products-services/containerlibrary
|`cpd_registry`                     | `cp.icr.io/cp/cpd`                                       |
|`cpd-namespace`                 | `zen`                                                    | Name of the project (namespace) in which CP4D will be installed
|`operator_namespace`                  | `ibm-common-services`                                                   | namespace to install operators in
|`openshift-username`                  | `admin`                                                   | username for ocp console. At this point we don't support custom admin name
|`openshift_api`                  | `null`                                                   | must not be set!
|`openshift_token`                  | `null`                                                   | must not be set!
|`cpd_storageclass`                  | `portworx`                                                   | storageclass for the cluster. Currently only portworx is supported.
|`cpd_platform`                  | `yes`                                                   | to install the cpd platform
|`watson_knowledge_catalog`                  | `{ "enable" : "no", "version" : "4.0.2", "channel" : "v1.0" }`                                                   | to install the Watson Knowledge Catalog service. Similar for all the services mentioned in vars.tf
|`existing_vpc_id`                  | `null`                                                   | ID of the VPC, if you wish to install CP4D in an existing VPC
|`existing_vpc_subnets`             | `null`                                                   | List of subnet IDs in an existing VPC in which the cluster will be installed. Required when `existing_vpc_id` has been provided.
|`enable_public_gateway`            | `true`                                                   | Attach a public gateway to the worker node subnets? [true/false] Currently unsupported.
|`multizone`                        | `false`                                                  | Create a multizone cluster spanning three zones? [true/false]
|`no_of_zones`            | `3`                                                      | Number of zones for the ROKS cluster. for single: 1, for multi: consitent with no. of desired zones. The deployment might fail, if this variable is not set correctly.
|`allowed_cidr_range`               | `["0.0.0.0/0"]`                                          | List of IPv4 or IPv6 CIDR blocks that you want to allow access to your infrastructure. Currently unsupported.
|`acl_rules`                        | See `vars.tf`                                            | List of rules for the network ACL attached to every subnet. Refer to https://cloud.ibm.com/docs/terraform?topic=terraform-vpc-gen2-resources#network-acl-input for the format.
|`zone_address_prefix_cidr`         | `["10.240.0.0/18", "10.240.64.0/18", "10.240.128.0/18"]` | List of private IPv4 CIDR blocks for the address prefix of the VPC zones
|`subnet_ip_range_cidr`             | `["10.240.0.0/21", "10.240.64.0/21", "10.240.128.0/21"]` | List of private IPv4 CIDR blocks for the subnets. Must be a subset of its respective `zone_address_prefix_cidr` block.
|`storage_capacity`                 | `1000`                                                   | Storage capacity of the block volumes
|`storage_profile`                  | `10iops-tier`                                            | The storage profile for the block storage
|`storage_iops`                     | `10000`                                                  | The IOPS for the block storage. Only used for the 'custom' storage profile.
|`create_external_etcd`             | `true`                                                   | Create a 'Databases for etcd' service instance to keep Portworx metadata separate from the operational data of your cluster? [true/false]
|`cos_instance_crn`                 | `null`                                                   | OpenShift requires an object store to back up the internal registry of your cluster. You may supply an existing COS, or the module will create a new one.
|`existing_roks_cluster`            | `null`                                                   | ID or name of an existing OpenShift on IBM Cloud (VPC Gen 2) cluster, should you wish to install in an existing cluster.
|`disable_public_service_endpoint`  | `false`                                                  | Disable the ROKS public service endpoint? [true/false]. Currently not supported.
|`entitlement`                      | `cloud_pak`                                              | Set this argument to 'cloud_pak' only if you use the cluster with a Cloud Pak that has an OpenShift entitlement.
|`kube_version`                     | `4.8_openshift`                                          |
|`worker_node_flavor`               | `bx2.16x64`                                              |
|`worker_nodes_per_zone`            | `3`                                                      | Number of initial worker nodes per zone for the ROKS cluster. Select at least 3 for single zone and 2 for multizone clusters.