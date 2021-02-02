### Generating the Portworx Spec URL
* Launch the [spec generator](https://central.portworx.com/specGen/wizard)
* Select `Portworx Essentials` or `Portworx Enterprise` and press Next to continue:
![Alt text](images/essential-enterprise.png)
* Check `Use the Portworx Operator` box and select the `Portworx version` as `2.5` For `ETCD` select `Built-in` option and then press Next:
![Alt text](images/portworx-version.png)
* Select `Cloud` for `Select your environment` option. Click on `AWS` and select `Create Using a Spec` option for `Select type of disk`.
Enter value for `Size(GB)` as `1000` and then press Next. 
![Alt text](images/cloud-platform.png)
* Leave `auto` as the network interfaces and press Next:
![Alt text](images/network-interface.png)
* Select Openshift 4+ as Openshift version, go to `Advanced Settings`:
![Alt text](images/openshift-version.png)
* In the `Advanced Settings` tab select CSI and Monitoring and press Finish:
![Alt text](images/advance-setting.png)
* Copy Spec URL:
![Alt text](images/spec-url.png)
