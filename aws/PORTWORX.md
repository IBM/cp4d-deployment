### Generating the Portworx Spec URL
* Launch the [spec generator](https://central.portworx.com/specGen/wizard)
* Select `New Spec` to generate spec for PortWorx:
![Alt text](images/spec_creation.png)
* Select Enterprise Trial or Essentials:
![Alt text](images/trial-or-essentials.png)
* Enter the Kubernetes Version and the Portworx version to 1.16.2 and 2.5 respectively, select Built-in and press Next:
![Alt text](images/kube-version-etcd.png)
* Select `AWS` Cloud and enter disk size to be `500 GB` and option `Create using a spec`:
![Alt text](images/configure_size.png)
* Leave `auto` as the network interfaces and press Next:
![Alt text](images/network_selection.png)
* Select Openshift 4+ as Openshift version, go to Advanced Settings:
![Alt text](images/env_selection.png)
* In the Advanced Settings tab select CSI and Monitoring and press Finish:
![Alt text](images/Advanced_settings.png)
* Copy Spec URL:
![Alt text](images/spec_url.png)
