# About Mirror Regisrty

  
You can mirror the contents of the OpenShift Container Platform registry and the images that are required to generate the installation program. The mirror registry is a key component that is required to complete an installation in a restricted network. You can create this mirror on a bastion host, which can access both the internet and your closed network, or by using other methods that meet your restrictions. 

Because of the way that OpenShift Container Platform verifies integrity for the release payload, the image references in your local registry are identical to the ones that are hosted by Red Hat on Quay.io. During the bootstrapping process of installation, the images must have the same digests no matter which repository they are pulled from. To ensure that the release payload is identical, you mirror the images to your local repository. To know more about creating mirro registry in a restricted network [see here](https://docs.openshift.com/container-platform/4.5/installing/install_config/installing-restricted-networks-preparations.html).

## Creating a mirror registry

The "CreateMirrorRegistry.sh" file will create the Mirror Registry in the node you execute this script.

### Prerequisites

The following are the prerequisites for executing the script in your cluster.

   * You should have a Red Hat Enterprise Linux (RHEL) `7.*` server on your network to use as the registry host and the registry host can access the internet. Make sure there is `1000 GiB` available disk space on the mirror host.
   * Make sure that `Vnet CIDR` range of mirror registry vm instance is different from the `Vnet CIDR` range used for creating the OpenShift cluster.If the ranges are same, the terrform scripts will fail as it will be unable to create vnet peering.
   * Download the scripts (createMirrorRegistry.sh, createSSL.sh and certificate ) from [here](../mirror-registry) and place it in your node which has been selected to install mirror-registry.
   * Download your registry.redhat.io pull secret from the [Pull Secret](https://cloud.redhat.com/openshift/install/pull-secret) page on the Red Hat OpenShift Cluster Manager site. Place the pull_secret file in the same folder as the script.
   * If you do not have an existing trusted certificate authority, you can generate a self-signed certificate. To generate a self signed certificate update `certificate` file and place it in the same directory as that of the scripts. (don't put any double quotes " " on the variable values and also no space in a value.)
   ```
   countrycode=Specify the two-letter ISO country code for your location. See ISO 3166 country codes link below.
   state=Enter the full name of your state or province.
   locality=Enter the name of your city.
   organization=Enter your company name.
   unit=Enter your department name.
   ```
   [ISO 3166 country codes](https://www.iso.org/iso-3166-country-codes.html) standard.
   * Assign execute permission to both the shell script
   ```
   chmod +x createMirrorRegistry.sh
   chmod +x createSSL.sh
   ```
 Then execute the script by giving the follwing parameters in the same sequence "`emailid`, `any username`, `any password`, OCP version same as cluster's version (currently using `4.5.18`), `red hat account username`, `red hat account password`" as parameters.

##### Example:

  ```
  ./createMirrorRegistry.sh "example@in.ibm.com" "testuser" "testPassword" "4.5.18" "RedHat account username" "RedHat account password"
  ```
   * This command pulls the release information as a digest, and its output includes the `imageContentSources` data that you require when you install your cluster.
   * Record the entire `imageContentSources` section, The information about your mirrors is unique to your mirrored repository, and you must add the `imageContentSources` section to the install-config.yaml file during installation.

##### Example Output:

```
imageContentSources:
- mirrors:
  - mirror-node.eastus.cloudapp.azure.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - mirror-node.eastus.cloudapp.azure.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```
