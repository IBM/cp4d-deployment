| Variables             | Default       | Description          |
| --------------------- | :-----------: | -------------------- |
| `region` | eu-west-2 | Region where cluster would be deployed. |
| `tenancy` | default | Amazon EC2 instances tenancy type, `default / dedicated`. See [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/dedicated-instance.html) |
| `access_key_id` | Requires input | AWS account access key id for the current user account. |
| `secret_access_key` | Requires input | AWS account secret access key for the current user account. |
| NETWORK |
| `new_or_existing_vpc_subnet` | new | For existing VPC and SUBNETS use `exist` otherwise use `new` to create a new VPC and SUBNETS, default is `new`. |
| `vpc_cidr` | 10.0.0.0/16 | The CIDR block for the VPC to be created. |
| `public_subnet_cidr1` | 10.0.0.0/20 | The CIDR block for the public subnet located in Availability Zone 1. |
| `public_subnet_cidr2` | 10.0.16.0/20 | The CIDR block for the public subnet located in Availability Zone 2. |
| `public_subnet_cidr3` | 10.0.32.0/20 | The CIDR block for the public subnet located in Availability Zone 3. |
| `private_subnet_cidr1` | 10.0.128.0/20 | The CIDR block for the private subnet located in Availability Zone 1. |
| `private_subnet_cidr2` | 10.0.144.0/20 | The CIDR block for the private subnet located in Availability Zone 2. |
| `private_subnet_cidr3` | 10.0.160.0/20 | The CIDR block for the private subnet located in Availability Zone 3. |
| `vpc_id` | "" | If existing VPC is to be used and selected `exist` as input parameter for `new_or_existing_vpc_subnet` variable, then provide a VPC id otherwise keep it blank as `“”`. NOTE: Enable DNS hostnames in existing VPC |
| `public_subnet1_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 1 |
| `public_subnet2_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 2 |
| `public_subnet3_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 3 |
| `private_subnet1_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 1 |
| `private_subnet2_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 2 |
| `private_subnet3_id` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 3 |
| ROSA |
| `openshift_version` | 4.7.12 | Openshift Cluster version |
| `cluster_name` | ibmrosa | All resources created by the Openshift Installer will have this name as prefix. |
| `rosa_token` | - | Token generated from the RedHat portal [here](https://cloud.redhat.com/openshift/token/rosa) |
| `worker_machine_type` | m5.4xlarge | The EC2 instance type for the OpenShift worker instances. Make sure your region supports the selected instance type.  Supported worker instance types [here](./INSTANCE-TYPES.md) |
| `worker_machine_count` | 3 | The desired capacity for the OpenShift worker node instances. Minimum of `3` nodes required. To decide on the number of worker nodes needed check `Resource Requirements for each service` section in [here](../README.md) |
| `private_cluster` | public | Public or Private. Set `public` to `private` to deploy a cluster which cannot be accessed from the internet. See [documentation](https://docs.openshift.com/container-platform/4.3/installing/installing_aws/installing-aws-private.html) for more details. |
| `cluster_network_cidr` | 10.128.0.0/14 | The CIDR block for the Openshift cluster overlay network cidr to be created. |
| `cluster_network_host_prefix` | 23 | Host prefix for the cluster network. |
| `service_network_cidr` | 172.30.0.0/16 | The CIDR cidr block for Openshift cluster  services |
| `az` | multi_zone | The number of Availability Zones to be used for the deployment. Keep in mind that some Regions may be limited to two Availability Zones. For a IBM Cloud Pak for Data cluster to be highly available, three Availability Zones are needed to avoid a single point of failure. Allowed values: `single_zone` and `multi_zone`. |
| `availability_zone1` | "" | Availability zone values, leave it as it is if you don't want to provide the value, in that case it will be automatically selected based on the region. For `single_zone` installation, provide only `availability_zone1` value. |
| `availability_zone2` | "" | Availability zone values, leave it as it is if you don't want to provide the value, in that case it will be automatically selected based on the region. For `single_zone` installation, provide only `availability_zone1` value. |
| `availability_zone3` | "" | Availability zone values, leave it as it is if you don't want to provide the value, in that case it will be automatically selected based on the region. For `single_zone` installation, provide only `availability_zone1` value. |
| STORAGE |
| `ocs` |`enable = true` | Set to enable, if OCS. The EC2 instance type for the OpenShift container storage (OCS) instances. Make sure your region supports the selected instance type. Supported ocs instance types [here](./INSTANCE-TYPES.md) |
| `portworx_enterprise` | `enable = false` | See PORTWORX.md on how to get the Cluster ID. |
| `portworx_essentials` | `enable = false`  | See PORTWORX-ESSENTIALS.md on how to get the Cluster ID, User ID and OSB Endpoint |
| Cloud Pak for Data |
| `accept_cpd_license` | reject | Read and accept license [here](https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DNAA-BZTPEW). Allowed values `accept / reject`. |
| `api_key` | Requires input | Enter the API Key. To generate API Key select [Entitlement Key](https://myibm.ibm.com/products-services/containerlibrary). For external registries, enter password here |
| `cpd_namespace` | zen | The OpenShift project that will be created for deploying Cloud Pak for Data. It can be any lowercase string. |
| `data_virtualization` | no | Enter `yes` to install the Data Virtualization Add-on service. If you installing this service, you need to install `data_management_console` service as well. |
| `apache_spark` | no | Enter `yes` to install the Apache Spark Add-on service. |
| `watson_knowledge_catalog` | no | Enter `yes` to install the Watson Knowledge Catalog Add-on service. |
| `watson_studio_library` | no | Enter `yes` to install the Watson Studio Add-on service. |
| `watson_machine_learning` | no | Enter `yes` to install the Watson Machine Learning Add-on service. |
| `watson_ai_openscale` | no | Enter `yes` to install the Watson OpenScale and Watson Machine Learning Add-on services. |
| `cognos_dashboard_embedded` | no | Enter `yes` to install the Cognos dashboard embedded Add-on service. |
| `datastage` | no | Enter `yes` to install the datastage Add-on service. |
| `db2-warehouse` | no | Enter `yes` to install the DB2Warehouse Add-on service. If you installing this service, you need to install `data-management-console` service as well.  |
| `data_management_console` | no | Enter `yes` to install the data management console Add-on service. |
| `cognos_analytics` | no | Enter `yes` to install the Cognos Analytics Add-on service. |
| `spss-modeler` | no | Enter `yes` to install the SPSS Modeler Add-on service. |
| `db2_oltp` | no | Enter `yes` to install the DB2OLTP service. |
| `master_data_management` | no | Enter `yes` to install the Master Data Management 360 service. |