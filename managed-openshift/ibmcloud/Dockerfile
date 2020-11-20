FROM phusion/baseimage:bionic-1.0.0

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

################################
# Download and install packages
################################

RUN install_clean wget unzip jq nano
WORKDIR /tmp

# terraform
RUN wget --no-verbose https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
RUN unzip terraform_0.12.29_linux_amd64.zip
RUN mv terraform /usr/bin/
RUN echo 'alias tf=terraform' >> /root/.bashrc

# terraform-provider-ibm
RUN wget --no-verbose https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.14.0/linux_amd64.zip
RUN unzip linux_amd64.zip
RUN mkdir -p /root/.terraform.d/plugins
RUN mv terraform-provider-ibm_v1.14.0 /root/.terraform.d/plugins/

# oc and kubectl
RUN wget --no-verbose https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
RUN tar -xzf openshift-client-linux.tar.gz
RUN mv oc /usr/bin/
RUN mv kubectl /usr/bin/

# cloudctl
RUN wget --no-verbose https://github.com/IBM/cloud-pak-cli/releases/download/v3.6.0/cloudctl-linux-amd64.tar.gz
RUN tar -xzf cloudctl-linux-amd64.tar.gz
RUN mv cloudctl-linux-amd64 /usr/bin/cloudctl

# ibmcloud cli (not essential)
RUN wget --no-verbose -O ibmcloud-installer.tgz https://clis.cloud.ibm.com/download/bluemix-cli/latest/linux64
RUN tar -xzf ibmcloud-installer.tgz
RUN Bluemix_CLI/install
RUN echo 'alias ic=ibmcloud' >> /root/.bashrc

###################################
# Dir for mounting template files
###################################

RUN mkdir -p /root/templates
WORKDIR /root/templates

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
