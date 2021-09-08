# Known Issues and Troubleshooting steps:

## 1) Startup probe failed on OCP 4.6.34, 4.6.36 and 4.7.18

In the recent version of the openshift (4.6.34, 4.6.36 and 4.7.18) we have noticed the below issue on db2u pods. 

### Issue:

```bash
Error: Pods c-db2oltp-wkc-db2u-0  & c-db2oltp-iis-db2u-0 pods will have  Startup probe failed with bellow error message
```
```bash 
Warning  Unhealthy       101m                    kubelet            Startup probe failed: time="2021-07-09T03:05:48-05:00" level=error msg="exec failed: open /dev/tty: no such device or address"
  Normal   Pulled          34m (x4 over 87m)       kubelet            Container image "cp.icr.io/cp/db2u.restricted@sha256:c1aaa5dc86b01c7706ee0bf5d46da51cee628c77758b955385325a574e451372" already present on machine
  Warning  Unhealthy       5m24s (x249 over 101m)  kubelet            (combined from similar events): Startup probe failed: time="2021-07-09T04:42:08-05:00" level=error msg="exec failed: open /dev/tty: no such device or address"
```
### Workaround:

We have added the patch recommended by DB2 team to patch the db2 sts, this will restart the db2u pod and allow the service to be proceed further.

Patch example for wkc:
```bash

oc patch sts c-db2oltp-wkc-db2u -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'


```

For IIS, the below patch should make the install proceed further. The patch needs to be run before init-job completes its retries or else UG install will fail.

``` bash
oc patch sts c-db2oltp-iis-db2u -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'
```

For db2 instance creation in CP4D services like db2wh, db2oltp, dv ... that might be in progress for long time,if you see db2u pods in 0/1 state, describe pod for the respective db2u pod shows  /dev/tty: no such device or address error

Run the similar patch as above for the db2u sts that is in 0/1 state.