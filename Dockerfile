FROM phusion/baseimage:bionic-1.0.0

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

################################
# Download and install packages
################################

RUN install_clean wget unzip jq nano
WORKDIR /tmp

# terraform
RUN wget --no-verbose https://releases.hashicorp.com/terraform/0.13.0/terraform_0.13.0_linux_amd64.zip \
 && unzip terraform_0.13.0_linux_amd64.zip \
 && mv terraform /usr/bin/ \
 && echo 'alias tf=terraform' >> $HOME/.profile

# cloudctl
RUN wget --no-verbose https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.1/cloudctl-linux-amd64.tar.gz \
 && tar -xzf cloudctl-linux-amd64.tar.gz \
 && mv cloudctl-linux-amd64 /usr/bin/cloudctl

# terraform-provider-ibm
RUN wget --no-verbose https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.33.0/terraform-provider-ibm_1.33.0_linux_amd64.zip \
 && unzip terraform-provider-ibm_1.33.0_linux_amd64.zip \
 && mkdir -p $HOME/.terraform.d/plugins \
 && mv terraform-provider-ibm_v1.33.0 $HOME/.terraform.d/plugins/

# oc and kubectl
RUN wget --no-verbose https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.6/openshift-client-linux.tar.gz \
 && tar -xzf openshift-client-linux.tar.gz \
 && mv oc /usr/bin/ \
 && mv kubectl /usr/bin/

# ibmcloud cli (not essential)
RUN wget --no-verbose -O ibmcloud-installer.tgz https://clis.cloud.ibm.com/download/bluemix-cli/latest/linux64 \
 && tar -xzf ibmcloud-installer.tgz \
 && Bluemix_CLI/install \
 && echo 'alias ic=ibmcloud' >> $HOME/.profile

# ibmcloud plugins
RUN ibmcloud plugin install container-registry \
&& ibmcloud plugin install container-service

# install jq
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64  -O /usr/bin/jq && chmod +x /usr/bin/jq

RUN apt-get update -y
RUN apt-get install -y python
RUN apt-get install -y python-yaml

###################################
# Dir for mounting template files
###################################
RUN mkdir -p $HOME/templates \
 && echo "$HOME/.terraform" > /etc/container_environment/TF_DATA_DIR

WORKDIR /root/templates

############
# Clean up
############
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
