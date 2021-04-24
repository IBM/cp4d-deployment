# AWS ROSA

### Architecture
![ROSA_Architecture](images/AWS_ROSA.png)

### Installation
* Download `rosa` cli [here](https://github.com/openshift/rosa/releases)
* Get RedHat ROSA token [here](https://cloud.redhat.com/openshift/token/rosa)
* Enable ROSA [here](https://console.aws.amazon.com/rosa/home)
* Run the following steps:
```bash
## Configures your AWS account and ensures everything is setup correctly
$ rosa init

## Login
$ rosa login --token=<rosa_token>

## Starts the cluster creation process (~30-40minutes) and watches the logs
$ rosa create cluster --cluster-name <cluster_name> --watch --compute-machine-type "m5.4xlarge" --compute-nodes 3
```

### Configuring your IDP (GitHub Enterprise)
* Click Settings → Developer settings → OAuth Apps → Register a new OAuth application.
* Enter an application name.
* Enter Homepage URL e.g `https://oauth-openshift.apps.femi-rosa.z2ri.p1.openshiftapps.com`
* Optional: Enter an application description.
* Enter the authorization callback URL, where the end of the URL contains the identity provider name e.g `https://oauth-openshift.apps.femi-rosa.z2ri.p1.openshiftapps.com/oauth2callback/github/`
* Click Register application. GitHub provides a Client ID and a Client Secret. You need these values to complete the identity provider configuration.
* In your terminal, run `rosa describe cluster --cluster <cluster_name> | grep Details` to view the admin page of the cluster. Follow the link to the cluster and create OAuth using these generated information.
  * For the Hostname field enter the Enterprise hostname, e.g. github.ibm.com
* Grant admin priviledges to a user in the github org/team you provided through the admin page.

### Installing Portworx and CPD
* Login to the cluster using your IDP, generate a login command (top right corner) and get the token and server url. 
* Set the `openshift_api` and `openshift_token` variables with the server url and token respectively.
* Fill out the `variables.tf` in the root folder or create an `.tfvars` file for your variables.
* Deploy, using:
```bash
terraform apply
```

### Pricing Information for ROSA
1. An hourly fee for the cluster would be $0.03/cluster/hour ($263/cluster/year)
1. Pricing per worker node would be $0.171 per 4vCPU/hour for on-demand consumption (~$1498/node/year)
  1. This can be reduced by committing to a year in advance, $0.114 per 4vCPU/hour for a 1-year commit (~$998/node/year)

Note: Pricing for ROSA is in addition to the costs of Amazon EC2 & AWS services used.

E.g. If you have 10 m5.xlarge worker node cluster running on-demand for a year,
Cost would be,

  1. $0.03/cluster/hour X 1 cluster X 24 hours/day X 365 days/year = $263
  1. $0.171/node/hour X 10 worker nodes X 24 hours/day X 365 days/year = $14,990
  Total is approximately $15,253

Note: Above pricing does not include infrastructure expenses. For more information [here] (https://aws.amazon.com/rosa/pricing/)