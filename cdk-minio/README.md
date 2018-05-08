# Minio storage with Canonical Kubernetes

This demo shows how to use Minio storage with Canonical Kubernetes. Minio storage allows you to turn K8s PV into S3 Compatible storage ([https://www.minio.io/kubernetes.html](https://www.minio.io/kubernetes.html)).

It is a pretty useful storage mechanism which gives you Amazon S3 like storage wherever your kubernetes cluster is running. If you're running Kubernetes on-premise within your own data-center, on Google Cloud or Azure, you can avoid the problem of vendor lock-in with AWS by using Minio.

## Prerequisites

This document assumes you have already deployed Canonical Kubernetes and have a cluster running already with some storage available for the creation of PV. If you want something quick to test with.

I recommend you follow the [cdk-ceph demo here to deploy Canonical Kubernetes with Ceph](https://github.com/CanonicalLtd/canonical-kubernetes-demos/tree/master/cdk-ceph) but create a default storage class based on the manual instructions. The PVC you create will need at least 1GB of storage so keep this in mind.

## Deploying the Standalone Minio Workload

On the minio website, there is a page for generating the kubernetes payload. This repository includes two examples from that site which have been modified to work out of the box with Canonical Kubernetes if you've deployed it with available PV.

The standalone instance is designed to provide minio as a single instance, rather than a distributed cluster. This is useful for testing locally or prototyping, before moving to a bigger deployment.

First make sure you have a pv available:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-ceph$ kubectl get pvc
NAME             STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
minio-pv-claim   Bound     test      2G         RWO            rbd            1d
```

After you have the PV, modify the minio-standalone.yaml kubernetes payload to use that PV. Inside this yaml file is a pvc definition, you need to adjust the pvc to use this PV you created.

It is possible to check the details of the PV using kubectl:

```
kubectl edit pv test
# ... this will show you the pv details with full name, it can be changed this way.
```

Inside the minio-standalone.yaml file, there is a pvc (persistent volume claim) defined at the top, this must be modified:

```
# This PV has been added to the regular example, you should change this depending on your architecture
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  # This name uniquely identifies the PVC. Will be used in deployment below.
  name: minio-pv-claim
  labels:
    app: minio-storage-claim
spec:
  # Read more about access modes here: http://kubernetes.io/docs/user-guide/persistent-volumes/#access-modes
  accessModes:
    - ReadWriteOnce
  resources:
    # This is the request for storage. Should be available in the cluster.
    requests:
      storage: 1Gi
  # Uncomment and add storageClass specific to your requirements below. Read more https://kubernetes.io/docs/concepts/storage/persistent-volumes/#class-1
  storageClassName: rbd # <- change this line

  # ... rest of the file is omitted
```

In this example, we need to match the storageClassName (rbd) with the STORAGECLASS name given in the output of kubectl get pv command (rbd). Once it has been modified, apply the payload:

```
kubectl apply -f minio-standalone.yaml
```

If there are problems, it can be deleted and the previous command can be re-run to re-deploy the solution:

```
kubectl delete -f minio-standalone.yaml
```

Doing this should resolve the pvc:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get pvc
NAME             STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
minio-pv-claim   Bound     test      2G         RWO            rbd            1d
```

Which should now resolve the pod creation for minio:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-ceph$ kubectl get po
NAME                                               READY     STATUS    RESTARTS   AGE
default-http-backend-h9vg4                         1/1       Running   0          1h
minio-deployment-6b7595956b-kzvsp                  1/1       Running   0          33s
nginx-ingress-kubernetes-worker-controller-8c44t   1/1       Running   0          1h
nginx-ingress-kubernetes-worker-controller-xgljb   1/1       Running   0          1h
nginx-ingress-kubernetes-worker-controller-zfqd7   1/1       Running   0          1h
```

And if you then tail the logs for the minio pod, you will end up with a nice welcome message:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-ceph$ kubectl logs -f minio-deployment-6b7595956b-kzvsp
Created minio configuration file successfully at /root/.minio

Drive Capacity: 1.8 GiB Free, 1.8 GiB Total

Endpoint:  http://10.1.68.5:9000  http://127.0.0.1:9000
AccessKey: admin
SecretKey: password

Browser Access:
   http://10.1.68.5:9000  http://127.0.0.1:9000

Command-line Access: https://docs.minio.io/docs/minio-client-quickstart-guide
   $ mc config host add myminio http://10.1.68.5:9000 admin password

Object API (Amazon S3 compatible):
   Go:         https://docs.minio.io/docs/golang-client-quickstart-guide
   Java:       https://docs.minio.io/docs/java-client-quickstart-guide
   Python:     https://docs.minio.io/docs/python-client-quickstart-guide
   JavaScript: https://docs.minio.io/docs/javascript-client-quickstart-guide
   .NET:       https://docs.minio.io/docs/dotnet-client-quickstart-guide

```

Now our service is up, but we can't access it! Right at the end of the file is a nodeport entry which will be used to access the cluster.

What we need to do is open up this port. We could also use an ingress rule with a load-balancer instead with a DNS entry:

```
juju run --unit kubernetes-worker/0 "open-port 30900"
juju run --unit kubernetes-worker/1 "open-port 30900"
juju run --unit kubernetes-worker/2 "open-port 30900"
```

If you run the above commands and then run juju status, you should be able to grab the IP address of one of your worker nodes.

Hit the IP address in the browser using the port 30900, you should be greated by a nice welcoming web interface:

![minio login page](https://raw.githubusercontent.com/CanonicalLtd/canonical-kubernetes-demos/master/cdk-minio/images/cdk-minio-loginpage.png "Minio Storage Login Page")

But what are the credentials? If you go back and look at the minio-standalone.yaml, you will see a section that defines the admin user and password:

```
- name: MINIO_ACCESS_KEY
  value: "admin"
- name: MINIO_SECRET_KEY
  value: "password"
```

These can be removed, so no access key is required or left as default credentials. Finally We can now log in using these details:

![minio logged-in](https://raw.githubusercontent.com/CanonicalLtd/canonical-kubernetes-demos/master/cdk-minio/images/cdk-minio-loggedin.png "Minio Logged In")

From here, you can perform basic management of your cluster, such as adding or removing buckets and files or creating bucket policies.

## Deploying the Distributed Minio Workload

The distributed Minio workload is very similar to the standalone workload but it runs in a highly-available, clustered mode using multiple replicas.

First remove anything related to Minio from your cluster and run the deployment command:


```
kubectl apply -f minio-distributed.yaml
```

If there are problems, it can be deleted and the previous command can be re-run to re-deploy the solution:

```
kubectl delete -f minio-distributed.yaml
```

This will create multiple PV, PVC and PODS:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get pvc
NAME           STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound     pvc-83dbc211-2ec4-11e8-8499-0e009186c0be   1536Mi     RWO            default        14m
data-minio-1   Bound     pvc-b0a646ab-2ec4-11e8-8499-0e009186c0be   1536Mi     RWO            default        13m
data-minio-2   Bound     pvc-4d0bf318-2ec5-11e8-8499-0e009186c0be   1536Mi     RWO            default        8m
data-minio-3   Bound     pvc-7b5edcfb-2ec5-11e8-8499-0e009186c0be   1536Mi     RWO            default        7m


NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                  STORAGECLASS   REASON    AGE
pvc-4d0bf318-2ec5-11e8-8499-0e009186c0be   1536Mi     RWO            Delete           Bound     default/data-minio-2   default                  8m
pvc-7b5edcfb-2ec5-11e8-8499-0e009186c0be   1536Mi     RWO            Delete           Bound     default/data-minio-3   default                  6m
pvc-83dbc211-2ec4-11e8-8499-0e009186c0be   1536Mi     RWO            Delete           Bound     default/data-minio-0   default                  13m
pvc-b0a646ab-2ec4-11e8-8499-0e009186c0be   1536Mi     RWO            Delete           Bound     default/data-minio-1   default                  12m

```

The caveat here is that you need to have an even amount of replicas (2, 4, etc) and each replica needs at least 1.5-2GB of available storage through a PV.

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get po
NAME                                               READY     STATUS    RESTARTS   AGE
default-http-backend-h9vg4                         1/1       Running   0          16h
minio-0                                            1/1       Running   0          15m
minio-1                                            1/1       Running   0          13m
minio-2                                            1/1       Running   0          9m
minio-3                                            1/1       Running   0          8m
nginx-ingress-kubernetes-worker-controller-8c44t   1/1       Running   0          16h
nginx-ingress-kubernetes-worker-controller-xgljb   1/1       Running   0          16h
nginx-ingress-kubernetes-worker-controller-zfqd7   1/1       Running   0          16h
```

The service should now be availabe and running again, just as like the standalone version. Note that it will take much longer to deploy when compared to the standalone system.

Eventually you will see a message like this, note the 'Status' is set to 4, this means there are four nodes running as part of the minio cluster:

```
Created minio configuration file successfully at /root/.minio

Drive Capacity: 2.7 GiB Free, 2.7 GiB Total
Status:         4 Online, 0 Offline.

Endpoint:  http://10.1.68.16:9000  http://127.0.0.1:9000
AccessKey: admin
SecretKey: password

Browser Access:
   http://10.1.68.16:9000  http://127.0.0.1:9000

Command-line Access: https://docs.minio.io/docs/minio-client-quickstart-guide
   $ mc config host add myminio http://10.1.68.16:9000 admin password

Object API (Amazon S3 compatible):
   Go:         https://docs.minio.io/docs/golang-client-quickstart-guide
   Java:       https://docs.minio.io/docs/java-client-quickstart-guide
   Python:     https://docs.minio.io/docs/python-client-quickstart-guide
   JavaScript: https://docs.minio.io/docs/javascript-client-quickstart-guide
   .NET:       https://docs.minio.io/docs/dotnet-client-quickstart-guide
```

What we need to do is open up this port. We could also use an ingress rule with a load-balancer instead with a DNS entry:

```
juju run --unit kubernetes-worker/0 "open-port 30900"
juju run --unit kubernetes-worker/1 "open-port 30900"
juju run --unit kubernetes-worker/2 "open-port 30900"
```

If you run the above commands and then run juju status, you should be able to grab the IP address of one of your worker nodes.

Hit the IP address in the browser using the port 30900, you should be greated by a nice welcoming web interface:

![minio login page](https://raw.githubusercontent.com/CanonicalLtd/canonical-kubernetes-demos/master/cdk-minio/images/cdk-minio-loginpage.png "Minio Storage Login Page")

As this is a clustered setup, the recommendation would be to create a DNS entry for the minio service, with A-Records pointing to each of the individual Kubernetes worker nodes.

You can also use the built-in ingress load-balancer which will provide a simple round-robin between the workers. The benefit of this is that you don't need to open up the nodeport, but it does require DNS entries.

The example below needs to be modified. The host entries should be replaced with DNS entries which are reflected on a DNS server, or the xip.io service can be used for testing. Xip.io essentially returns back an a-record for an IP address which is put infront of it, so hitting mino.192.168.1.1.xip.io in a web browser would return back an A-Record for 192.168.1.1.

In the example, replace <YOUR-WORKER-IP> with the IP address of one of your workers using juju status, add it to the minio-distribued.yaml file and use kubectl apply to re-apply the changes.

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: minio
 annotations:
   kubernetes.io/tls-acme: "true"
   ingress.kubernetes.io/secure-backends: "true"
spec:
 tls:
   - hosts:
     - minio.<YOUR-WORKER-IP>.xip.io
 rules:
   - host: minio.<YOUR-WORKER-IP>.xip.io
     http:
       paths:
         - path: /
           backend:
             serviceName: minio
             servicePort: 443
```

After you've done that, you should be able to hit minio.your-worker-ip.xip.io in your browser and be able to resolve to the minio web gui.

To delete the service, run the following command:

```
 kubectl delete -f minio-distributed.yaml
```

## Using the Minio Command Line Tool

To write and read data from we could use any of the available SDK(s), but we will use the minio client (https://docs.minio.io/docs/minio-client-quickstart-guide)[https://docs.minio.io/docs/minio-client-quickstart-guide].

Let's install it first using the snap:

```
 sudo snap install minio-client --edge --devmode
```

We add our newly provisioned minio server to our minio client as an end point, if you changed your access key or password in the bundle file, they should be adjusted here as well:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ minio-client config host add minio http://18.232.166.57:30900 admin password
mc: Configuration written to `/home/calvinh/snap/minio-client/164/.mc/config.json`. Please update your access credentials.
mc: Successfully created `/home/calvinh/snap/minio-client/164/.mc/share`.
mc: Initialized share uploads `/home/calvinh/snap/minio-client/164/.mc/share/uploads.json` file.
mc: Initialized share downloads `/home/calvinh/snap/minio-client/164/.mc/share/downloads.json` file.
Added `minio` successfully.
```

We can now interact with Minio using the command-line client:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ minio-client ?
NAME:
  mc - Minio Client for cloud storage and filesystems.

USAGE:
  mc [FLAGS] COMMAND [COMMAND FLAGS | -h] [ARGUMENTS...]

COMMANDS:
  ls       List files and folders.
  mb       Make a bucket or a folder.
  cat      Display file and object contents.
  pipe     Redirect STDIN to an object or file or STDOUT.
  share    Generate URL for sharing.
  cp       Copy files and objects.
  mirror   Mirror buckets and folders.
  find     Search for files and objects.
  stat     Stat contents of objects and folders.
  diff     List objects with size difference or missing between two folders or buckets.
  rm       Remove files and objects.
  events   Manage object notifications.
  watch    Watch for file and object events.
  policy   Manage anonymous access to objects.
  admin    Manage Minio servers
  session  Manage saved sessions for cp command.
  config   Manage mc configuration file.
  update   Check for a new software update.
  version  Print version info.

GLOBAL FLAGS:
  --config-folder value, -C value  Path to configuration folder. (default: "/home/calvinh/snap/minio-client/164/.mc")
  --quiet, -q                      Disable progress bar display.
  --no-color                       Disable color theme.
  --json                           Enable JSON formatted output.
  --debug                          Enable debug output.
  --insecure                       Disable SSL certificate verification.
  --help, -h                       Show help.

VERSION:
  DEVELOPMENT.GOGET
```

I uploaded a file to Minio using the web browser, called kitten.jpg in a bucket I also created there called test. I can now check for that file using the command line tool:

```
# The connection I added was called 'minio', this command lists all buckets in minio
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ minio-client ls minio
[2018-03-23 03:50:23 GMT]     0B test/

# This next command recursively lists all buckets and files within the minio bucket:
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ minio-client ls --recursive minio
[2018-03-23 03:50:23 GMT]  10KiB test/kitten.jpg
```

To delete the host from our client:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ minio-client config host remove minio
Removed `minio` successfully.
```

## Troubleshooting & Errors

If your PV or PVC is too small, Minio will start correctly and it will throw the following error:

```
Created minio configuration file successfully at /root/.minio

Trace: 1: /q/.q/sources/gopath/src/github.com/minio/minio/cmd/server-main.go:247:cmd.serverMain()
       2: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/app.go:499:cli.HandleAction()
       3: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/command.go:214:cli.Command.Run()
       4: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/app.go:260:cli.(*App).Run()
       5: /q/.q/sources/gopath/src/github.com/minio/minio/cmd/main.go:155:cmd.Main()
       6: /q/.q/sources/gopath/src/github.com/minio/minio/main.go:71:main.main()
[2018-03-21T03:24:34.902590795Z] [ERROR] Initializing object layer failed (disk path full)

Trace: 1: /q/.q/sources/gopath/src/github.com/minio/minio/cmd/server-main.go:249:cmd.serverMain()
       2: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/app.go:499:cli.HandleAction()
       3: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/command.go:214:cli.Command.Run()
       4: /q/.q/sources/gopath/src/github.com/minio/minio/vendor/github.com/minio/cli/app.go:260:cli.(*App).Run()
       5: /q/.q/sources/gopath/src/github.com/minio/minio/cmd/main.go:155:cmd.Main()
       6: /q/.q/sources/gopath/src/github.com/minio/minio/main.go:71:main.main()
[2018-03-21T03:24:34.902646769Z] [ERROR] Unable to shutdown http server (server not initialized)
```

To fix this issue, you need to create PV and PVC which provide at least 1GB of storage to Minio. Once you've done that, re-apply the kubernetes workload:

```
 # destroy and re-apply
 kubectl delete -f minio-distributed.yaml
 kubectl apply -f minio-distributed.yaml
```

If you get a constant 'ContainerCreating' status this means that the container cannot be started, either it is not in your registry or the PVC has issues:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get po
NAME                                               READY     STATUS              RESTARTS   AGE
default-http-backend-h9vg4                         1/1       Running             0          22m
minio-deployment-6b7595956b-p4nlj                  0/1       ContainerCreating   0          2m
nginx-ingress-kubernetes-worker-controller-8c44t   1/1       Running             0          20m
nginx-ingress-kubernetes-worker-controller-xgljb   1/1       Running             0          21m
nginx-ingress-kubernetes-worker-controller-zfqd7   1/1       Running             0          21m
```

If you run the kubectl get pvc command and see 'Pending' it is most likely caused by problems with the PVC/PV. You should adjust the size of your PVC so it is less than the total size of your PV and then re-run the container workload until you see the following message:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get pvc
NAME             STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
minio-pv-claim   Bound     test      1G         RWO            rbd            13s
```

## Conclusion

We have covered the basics of deploying minio storage on-top of Canonical Kubernetes (CDK). The next steps would be to integrate the storage into your own application using one of the provided minio SDK's which can be found in the useful links seciton of this document. Additional parameters can be changed in Minio, for example it is possible to configure it to use an SSL certificate for example.

## Useful Links
- [https://www.minio.io/kubernetes.html](https://www.minio.io/kubernetes.html)
- [https://github.com/minio/minio/blob/master/docs/config/README.md](https://github.com/minio/minio/blob/master/docs/config/README.md)
- [https://github.com/minio/minio](https://github.com/minio/minio)
- [https://docs.minio.io/docs/python-client-quickstart-guide](https://docs.minio.io/docs/python-client-quickstart-guide)
- [https://docs.minio.io/docs/java-client-quickstart-guide](https://docs.minio.io/docs/java-client-quickstart-guide)
- [https://docs.minio.io/docs/golang-client-quickstart-guide](https://docs.minio.io/docs/golang-client-quickstart-guide)
- [https://docs.minio.io/docs/javascript-client-quickstart-guide](https://docs.minio.io/docs/javascript-client-quickstart-guide)
- [https://docs.minio.io/docs/dotnet-client-quickstart-guide](https://docs.minio.io/docs/dotnet-client-quickstart-guide)
- [https://docs.minio.io/docs/minio-client-quickstart-guide](https://docs.minio.io/docs/minio-client-quickstart-guide)
