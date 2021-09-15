# Bastion node setup for Private cluster

The below document explains how to setup a bastion node to deploy a private cluster using the terraform scripts. 

## Prerequisites

1) To provision a private cluster using our terrform scripts, create the below resources beforehand. 

* Resource group 
* Vnet in the above resource group. 
* 1 master-subnet, 1 worker-subnet and 1 bastion-subnet in the vnet created. 
* (optional) If required network security groups can be created and attached to the subnets based on the requirement. 
* A private dns zone in the resource group that can be used during the terraform execution. This can be skipped if a private dns zone already exists that can be used. 

2) Provision a RHEL VM in the same resource group using the bastion-subnet. The bastion can either have public ip or not. This is based on the customer's network setup. 

## Prerequisites on the bastion node to execute terraform 

Once the bastion node is created, the below pre-reqs has to be installed to execute terraform scripts. 

* Install yum-config-manager to manage your repositories

```
sudo yum install -y yum-utils
```

* Use yum-config-manager to add the official HashiCorp Linux repository 

```bash
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
```

* Install Terraform

```bash
sudo yum -y install terraform
```

* oc client download

```
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.6.31/openshift-client-linux-4.6.31.tar.gz
tar -xvf openshift-client-linux-4.6.31.tar.gz
chmod u+x oc kubectl
sudo mv oc /usr/local/bin
sudo mv kubectl /usr/local/bin
oc version
```

*  Install jq

```
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
mv jq-linux64 jq
chmod +x jq
mv jq /usr/local/bin
```

*  Install python packages

``` 
yum install wget jq httpd-tools python36 -y
ln -s /usr/bin/python3 /usr/bin/python
ln -s /usr/bin/pip3 /usr/bin/pip
pip install pyyaml
```

## Download terraform scripts: 

In your bastion node download the terraform scripts from [here](https://github.com/IBM/cp4d-deployment) and follow the 'steps to deploy' section in the [readme](README.md). 

To deploy the private cluster you can refer to the sample .tfvars file located [here - sample_private_cluster.tfvars](./azure_infra/sample_private_cluster.tfvars).