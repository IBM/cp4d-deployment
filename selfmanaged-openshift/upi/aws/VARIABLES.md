| Variables             | Default       | Description          |
| --------------------- | :-----------: | -------------------- |
| `region` | us-west-2 | Region where cluster would be deployed.
| `azlist` | multi_zone | The number of Availability Zones to be used for the deployment. Keep in mind that some Regions may be limited to two Availability Zones. For a IBM Cloud Pak for Data cluster to be highly available, three Availability Zones are needed to avoid a single point of failure. Allowed values: `single_zone` and `multi_zone`. |
| `new-or-existing-vpc-subnet` | new | For existing VPC and SUBNETS use `exist` otherwise use `new` to create a new VPC and SUBNETS, default is `new`. |
| `disconnected-cluster` | no | For creating an disconnected cluster, select `yes` otherwise `no`, default if `no`. |
| `vpc_cidr` | 10.0.0.0/16 | The CIDR block for the VPC to be created. |
| `cluster_network_cidr` | 10.128.0.0/14 | The CIDR block for the network cidr to be created. |
| `subnet-bits` | 12 | The size of each subnet in each availability zone. Specify an integer between 5 and 13, where 5 is /27 and 13 is /19. |
| `public-subnet-cidr1` | 10.0.0.0/20 | The CIDR block for the public subnet located in Availability Zone 1. |
| `public-subnet-cidr2` | 10.0.16.0/20 | The CIDR block for the public subnet located in Availability Zone 2. |
| `public-subnet-cidr3` | 10.0.32.0/20 | The CIDR block for the public subnet located in Availability Zone 3. |
| `private-subnet-cidr1` | 10.0.128.0/20 | The CIDR block for the private subnet located in Availability Zone 1. |
| `private-subnet-cidr2` | 10.0.144.0/20 | The CIDR block for the private subnet located in Availability Zone 2. |
| `private-subnet-cidr3` | 10.0.160.0/20 | The CIDR block for the private subnet located in Availability Zone 3. |
| `vpcid-existing` | "" | If existing VPC is to be used and selected `exist` as input parameter for `new-or-exist` variable, then provide a VPC id otherwise if creating a new VPC and selected `new` for `new-or-exist` then keep it blank as `“”`. Enable DNS hostnames in existing VPC |
| `subnetid-public1` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 1. |
| `subnetid-public2` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 2. |
| `subnetid-public3` | "" | In case of existing VPC and SUBNETS, Subnet Id for public subnet in zone 3. |
| `subnetid-private1` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 1. |
| `subnetid-private2` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 2. |
| `subnetid-private3` | "" | In case of existing VPC and SUBNETS, Subnet Id for private subnet in zone 3. |
| `private-subnet-tag-name` | Requires input | Private subnets Tag Name, all Private Subnets should be Tagged with same Name and Value. |
| `private-subnet-tag-value` | Requires input | Private subnets Tag Value, all Private Subnets should be Tagged with same Name and Value. |
| `key_name` | Requires input | The name of a key pair, which allows you to securely connect to your instance after it launches. |
| `tenancy` | default | Amazon EC2 instances tenancy type, `default / dedicated`. See [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/dedicated-instance.html) |
| `access_key_id` | Requires input | AWS account access key id for the current user account. |
| `secret_access_key` | Requires input | AWS account secret access key for the current user account. |
| `master_replica_count` | 3 | The desired capacity for the OpenShift master instances. It must be an odd number, a minimum of `3` replica is required for both `single` and `multi` zone deployments. |
| `worker_replica_count` | 3 | The desired capacity for the OpenShift worker node instances, minimum of `3` nodes required. Make sure you have suffecient worker nodes to support all your cp4d services as UPI installation doesn't support `auto scaling` feature. To decide on the number of worker nodes needed check `Resource Requirements for each service` section in [here](../README.md) |
| `master-instance-type` | m5.2xlarge | The EC2 instance type for the OpenShift master instances. Make sure your region supports the selected instance type. Supported master instance types [here](./INSTANCE-TYPES.md) |
| `worker-instance-type` | m5.4xlarge | The EC2 instance type for the OpenShift worker instances. Make sure your region supports the selected instance type.  Supported worker instance types [here](./INSTANCE-TYPES.md) |
| `bootnode-instance-type` | m5.xlarge | The EC2 instance type for the bootnode instances. |
| `cluster-name` | Requires input  | All resources created by the Openshift Installer will have this name as prefix. |
| `private-or-public-cluster` | public | Public or Private. Set `public` to `private` to deploy a cluster which cannot be accessed from the internet. See [documentation](https://docs.openshift.com/container-platform/4.3/installing/installing_aws/installing-aws-private.html) for more details. |
| `fips-enable` | true | If FIPS mode is enabled, the Red Hat Enterprise Linux CoreOS (RHCOS) machines that OpenShift Container Platform runs on bypass the default Kubernetes cryptography suite and use the cryptography modules that are provided with RHCOS instead. Allowed values `true / false` |
| `admin-username` | ec2-user | Admin username for the bootnode. |
| `openshift-username` | Requires input | Desired Openshift username. |
| `openshift-password` | Requires input | Desired Openshift password. |
| `pull-secret-file-path` | Requires input | The pull secret that you obtained from the [Pull Secret](https://cloud.redhat.com/openshift/install/pull-secret) page on the Red Hat OpenShift Cluster Manager site. You use this pull secret to authenticate with the services that are provided by the included authorities, including Quay.io, which serves the container images for OpenShift Container Platform components. |
| `public_key_path` | Requires input | Path to the ssh public key file to allow terraform run commands remotely. Example: "~/.ssh/id_rsa.pub" |
| `ssh-public-key` | Requires input | ssh Public key to be included in the bootnode and all the nodes in the cluster. Example: "ssh-rsa AAAAB3Nza..." |
| `ssh-private-key-file-path` | Requires input | Path to the private key file of the corresponding ssh public key used to allow terraform run commands remotely. Example: "~/.ssh/id_rsa" |
| `classic-lb-timeout` | 1800 | Classic loadbalancer timeout value in seconds. |
| `dnszone` | Requires input | The domain name configured for the cluster. |
| `hosted-zoneid` | Requires input | Pass the Route53 public zone ID. |
| `storage-type` | portworx | Storage management to be used for the cp4d installation. Allowed values `portworx / ocs / efs`. |
| `portworx-spec-url` | Requires input | URL for generated portworx specification. Keep `default  = ""` when selecting `storage-type` as `ocs` or `efs`. See [Portworx documentation](PORTWORX.md) for more details. |
| `efs-performance-mode` | Requires input | If storage-type is selected as `efs`, select one of the performance mode, default is `generalPurpose`. Allowed values are `generalPurpose / maxIO`. To read more about efs performance mode see [efs performance modes](https://docs.aws.amazon.com/efs/latest/ug/performance.html#performancemodes) |
| `redhat-username` | Requires input | `(Using Mirror Registry)` Username for your Red Hat account. |
| `redhat-password` | Requires input | `(Using Mirror Registry)` Password for your Red Hat account. |
| `certificate-file-path` | Requires input | `(Using Mirror Registry)` Path to the certificate `/opt/registry/certs/domain.crt` file that you copied from the RHEL server where Mirror Registry is created. |
| `local-registry-repository` | Requires input |`(Using Mirror Registry)` `<local_registry>/<local_repository_name>` values from the `imageContentSources` section, from the output of the command for creating mirror registry. Example `ip-0-0-0-0.eu-west-3.compute.internal:5000/ocp4/openshift4` |
| `local-registry` | Requires input |`(Using Mirror Registry)` `<local_registry>` values from the `imageContentSources` section, from the output of the command for creating mirror registry. Example `ip-0-0-0-0.eu-west-3.compute.internal:5000` |
| `local-registry-username` | Requires input |`(Using Mirror Registry)` Username that you provided for creating the mirror registry. |
| `local-registry-pwd` | Requires input |`(Using Mirror Registry)` Password that you provided for creating the mirror registry. |
| `mirror-region` | Requires input |`(Using Mirror Registry)` Region where mirror registry instance is created. |
| `mirror-vpcid` | Requires input |`(Using Mirror Registry)` VPC id of the mirror registry instance . |
| `mirror-vpccidr` | Requires input |`(Using Mirror Registry)` VPC CIDR range of the mirror registry instance . |
| `mirror-sgid` | Requires input |`(Using Mirror Registry)` Security Group id of the mirror registry instance . |
| `mirror-routetable-id` | Requires input |`(Using Mirror Registry)` Route table id of the route table associated with the subnet of the mirror registry instance. |
| `cpdservices-to-install` | lite |`(Using Mirror Registry)` Input all the comma separated list of CP4D Service that you want to install. For example, to install the Cloud Pak for Data control plane, Watson Studio and Data Virtualization, specify lite,wsl,dv. At a minimum, you must specify lite. CP4D service list currently supported: `lite,dv,spark,wkc,wsl,wml,aiopenscale,cde,streams,streams-flows,ds,db2wh,db2oltp,dmc,datagate,dods,ca,spss-modeler,big-sql,pa` |
| `imageContentSourcePolicy-path` | Requires input |`(Using Mirror Registry)` Path of the `imageContentSourcePolicy.yaml` file copied from the Mirror registry ec2 instance, which was generated during the mirroring of the catalog for redhat-operators. See step 5 in disconnected installation section [Readme file](./README.md). |
| `accept-cpd-license` | reject | Read and accept license at https://ibm.biz/Bdq6KP. Allowed values `accept / reject`. |
| `cpd-namespace` | zen | The OpenShift project that will be created for deploying Cloud Pak for Data. It can be any lowercase string. |
| `api-key` | Requires input | Enter the API Key. To generate API Key select [Entitlement Key](https://myibm.ibm.com/products-services/containerlibrary) |
| `data-virtualization` | no | Enter `yes` to install the Data Virtualization Add-on service. If you installing this service, you need to install `data-management-console` service as well. |
| `apache-spark` | no | Enter `yes` to install the Apache Spark Add-on service. |
| `watson-knowledge-catalog` | no | Enter `yes` to install the Watson Knowledge Catalog Add-on service. |
| `watson-studio-library` | no | Enter `yes` to install the Watson Studio Add-on service. |
| `watson-machine-learning` | no | Enter `yes` to install the Watson Machine Learning Add-on service. |
| `watson-ai-openscale` | no | Enter `yes` to install the Watson OpenScale and Watson Machine Learning Add-on services. |
| `cognos-dashboard-embedded` | no | Enter `yes` to install the Cognos dashboard embedded Add-on service. |
| `streams` | no | Enter `yes` to install the Streams Add-on service. |
| `streams-flows` | no | Enter `yes` to install the Streams Flow Add-on service. |
| `datastage` | no | Enter `yes` to install the datastage Add-on service. |
| `db2-warehouse` | no | Enter `yes` to install the DB2Warehouse Add-on service. If you installing this service, you need to install `data-management-console` service as well.  |
| `db2-advanced-edition` | no | Enter `yes` to install the db2 advanced edition Add-on service. If you installing this service, you need to install `data-management-console` service as well. |
| `data-management-console` | no | Enter `yes` to install the data management console Add-on service. |
| `datagate` | no | Enter `yes` to install the Data Gate Add-on service. |
| `decision-optimization` | no | Enter `yes` to install the Decision Optimization Add-on service. |
| `cognos-analytics` | no | Enter `yes` to install the Cognos Analytics Add-on service. |
| `spss-modeler` | no | Enter `yes` to install the SPSS Modeler Add-on service. |
| `db2-bigsql` | no | Enter `yes` to install the Db2 bigaql Add-on service. |
| `planning-analytics` | no | Enter `yes` to install the Planning Analytics Add-on service. |

<!-- | `watson-assistant` | no | Enter `yes` to install the Watson Assistant Add-on service. |
| `watson-discovery` | no | Enter `yes` to install the Watson Discovery Add-on service. |
| `watson-knowledge-studio` | no | Enter `yes` to install the Watson Knowledge Studio Add-on service. |
| `watson-language-translator` | no | Enter `yes` to install the Watson Language Translator Add-on service. |
| `watson-speech` | no | Enter `yes` to install the Watson Speech Add-on service. | -->
