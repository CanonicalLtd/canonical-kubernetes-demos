# Deploying Ceph with Canonical Kubernetes to Provide Persistant Storage

This document describes how to deploy Canonical Kubernetes with Ceph storage using Juju.

We assume you have installed snap, juju and bootstrapped your cloud of choice (Azure, AWS) or on-premise infrastructure. Do not deploy the kubernetes model though yet. It is possible to add Ceph after a cluster has already been created, you just need to add the Ceph-mon, ceph-osd units and relationships.

We usually deploy the ceph-osd and ceph-mon services onto the Kubernetes-worker. Ceph-mon should be run as an LXD container to stop any problems with idempotency.

The instructions for deploying CDK on AWS and Azure can be found in this demos repository or in the Kubernetes manuals.

## Deploy CDK with Ceph-osd, Ceph-mon and relationships

The repository includes a canonical kubernetes bundle file which also deploys Ceph: [https://github.com/CanonicalLtd/canonical-kubernetes-demos/blob/master/cdk-ceph/cdk-ceph.yaml](https://github.com/CanonicalLtd/canonical-kubernetes-demos/blob/master/cdk-ceph/cdk-ceph.yaml) using the latest charms. Download the file using wget, curl or your browser. 

Once you have bootstrapped your cloud of choice, you shoud deploy it:

```
 juju deploy cdk-ceph.yaml
```

You can monitor the deployment status using the command:

```
 watch --color juju status --color
```

Eventually, this will all turn green and the workload status will be mostly 'active'. However, you will see an error or warning on the ceph-osd nodes, that no block storage is available.

Don't forget to also install kubectl and copy the kubeconfig file from the kubernetes-master server:

```
 sudo snap install kubectl --classic
 juju scp kubernetes-master/0:/home/ubuntu/config ~/.kube/config
```


The next step is to add some storage devices to the osd nodes which they can consume. You can do this using juju actions or manually using the command line tools. Note that currently

## Using juju actions to mount the storage

You can use the command juju storage-pools to get a list of storage pools:

```
# output for AWS
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-ceph$ juju storage-pools
Name     Provider  Attrs
ebs      ebs       
ebs-ssd  ebs       volume-type=ssd
loop     loop      
rootfs   rootfs    
tmpfs    tmpfs

# output for Azure
calvinh@calvinh-mbp:~$ juju storage-pools
AName Provider Attrs
azure azure
azure-premium azure account-type=Premium_LRS
loop loop
rootfs rootfs
tmpfs tmpfs
```

We can now add some storage to the ceph OSD nodes:

```
# commands for AWS
juju add-storage ceph-osd/0 osd-devices=ebs,100G,1
juju add-storage ceph-osd/1 osd-devices=ebs,100G,1
juju add-storage ceph-osd/2 osd-devices=ebs,100G,1

# commands for Azure
juju add-storage ceph-osd/0 osd-devices=azure,100G,1
juju add-storage ceph-osd/1 osd-devices=azure,100G,1
juju add-storage ceph-osd/2 osd-devices=azure,100G,1
```

You can now monitor the status again, you will see that the storage is being attached to the OSD nodes using:

```
 watch --color juju status --color
```

Finally, we can create a PV on kubernetes:

```
 juju run-action kubernetes-master/0 create-rbd-pv name=test size=50
```

We can check the pv has been created:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos$ kubectl get pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
test      50M        RWO            Retain           Available             rbd                      44m

```

The PV is now ready to be configured by the kubernetes-workers. Try spinning up a workload and creating a PVC which utilises the PV.

## Manually configuring the PV and Ceph storage

First we need to add some block devices for the worker nodes to consume, this is automated on public cloud, but I assume you already have some spare disks attached to your ceph-osd nodes if you're using your own infrastructure (phsyical or virtual):

```
# commands for AWS
juju add-storage ceph-osd/0 osd-devices=ebs,10G,1
juju add-storage ceph-osd/1 osd-devices=ebs,10G,1
juju add-storage ceph-osd/2 osd-devices=ebs,10G,1

# commands for Azure
juju add-storage ceph-osd/0 osd-devices=azure,10G,1
juju add-storage ceph-osd/1 osd-devices=azure,10G,1
juju add-storage ceph-osd/2 osd-devices=azure,10G,1
```

This will cause juju to add more storage to the ceph-osd nodes.

You can now monitor the status again, you will see that the storage is being attached to the OSD nodes using:

```
 watch --color juju status --color
```

Now we have storage devices, we need to create a pool in Ceph. SSH to the machine running the ceph-mon process and run:

```
 juju ssh kubernetes-master/0
 ceph osd pool create rbd 100 100
```

You can check how much space is available in the pool:

```
 juju ssh kubernetes-master/0
 rados df
 ubuntu@ip-172-31-20-225:~$ rados df
pool name                 KB      objects       clones     degraded      unfound           rd        rd KB           wr        wr KB
rbd                        0            0            0            0            0            0            0            0            0
  total used          103092            0
  total avail       15591696
  total space       15694788

```

You can set quotas on the pool:

```
ceph osd pool set-quota rbd max_objects 0
ceph osd pool set-quota rbd max_bytes 0
```

Its also possible to delete the pool:

```
ceph osd pool delete rbd rbd --yes-i-really-really-mean-it
```

Now we've created a pool, we need to create some things inside kubernetes. The first of which is the secret file which allows Kubernetes to interact with Ceph. If you add the storage and the relationships correctly in the bundle, juju should automatically create the secret file Kubernetes need sto interact with Ceph:

```
# check if the secret already exists
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get secrets
NAME                                                         TYPE                                  DATA      AGE
ceph-secret                                                  kubernetes.io/rbd                     1         19m
default-token-zhtvn                                          kubernetes.io/service-account-token   3         21m
nginx-ingress-kubernetes-worker-serviceaccount-token-hx4cg   kubernetes.io/service-account-token   3         20m

# Lets inspect the secret
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl edit secret ceph-secret

apiVersion: v1
data:
  key: QVFDVGo3VmFBUTh6RXhBQVlYcXJTaGQ0TkNNejJFUEdDTE53Tmc9PQ==
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"key":"QVFDVGo3VmFBUTh6RXhBQVlYcXJTaGQ0TkNNejJFUEdDTE53Tmc9PQ=="},"kind":"Secret","metadata":{"annotations":{},"name":"ceph-secret","namespace":"default"},"type":"kubernetes.io/rbd"}
  creationTimestamp: 2018-03-23T23:38:54Z
  name: ceph-secret
  namespace: default
  resourceVersion: "446"
  selfLink: /api/v1/namespaces/default/secrets/ceph-secret
  uid: 597390bf-2ef3-11e8-9e9d-02c5db71785a
type: kubernetes.io/rbd
```

Note the key value, this is the base64 encoded auth key/token used to interact with Ceph. We can manually re-create the secret by applying a Kubernetes manfiest. First we need to get the secret:

```
 # SSH to the ceph-mon node and grab the API key
 juju ssh ceph-mon/0
 ubuntu@ip-172-31-28-41:~$ sudo cat /etc/ceph/ceph.client.admin.keyring
[client.admin]
	key = AQCTj7VaAQ8zExAAYXqrShd4NCMz2EPGCLNwNg==
	caps mds = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"

# convert the key to a base 64 encoded value
ubuntu@ip-172-31-28-41:~$ echo -n "AQCTj7VaAQ8zExAAYXqrShd4NCMz2EPGCLNwNg==" -c | base64
QVFDVGo3VmFBUTh6RXhBQVlYcXJTaGQ0TkNNejJFUEdDTE53Tmc9PSAtYw==

# note that the base64 encoded key is the same as the one in the existing secret.
# you can also get this key using the ceph osd command on the k8s master node.
```

If we need to create a new secret, take this ID from the key and create a new secret file like the one below, save it to a file and use kubectl apply to create the secret:

```
---
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
data:
  key: QVFBUDdxZGFudXQvSkJBQXRLd3JSemNyLzVVa29DbEt1Q1FUZGc9PQ==
type:
  kubernetes.io/rbd
```

Next we need to create the StorageClass. Creating a default storageclass simplifies the way that Kubernetes interacts with the Ceph. It means you don't need to create individual PV but rather, when PVC are created, PV's are automatically creaed on Ceph based on the PVC requests.

In this example below, change the monitor IP(s) to the IP addresses of the nodes running the Ceph Monitors. The Ceph default port is 6789. You may need to change the namespace name and the secret name. Note if you're on AWS or Azure, these should be the private IP addresses in your cluster, not the public IP addresses.

```
---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
   name: default
   annotations:
     storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/rbd
parameters:
  # change the monitors to match your IP addresses of your ceph mon nodes
  monitors: 172.31.30.184:6789,172.31.76.153:6789,172.31.46.62:6789
  adminId: admin
  adminSecretName: ceph-secret
  adminSecretNamespace: default
  # change the name here if you the ceph pool you created is not called rbd
  pool: rbd
  userId: admin
  userSecretName: ceph-secret
  fsType: ext4
  imageFormat: "2"
  imageFeatures: "layering"
```

Now we should be able to automatically spawn PVs when PVC are created. To test this setup, create a PVC (use kubectl apply -f cdk-pvc-test.yaml):

```
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-vol01
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

Finally you should see the PV and PVC have been created:

```
calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                STORAGECLASS   REASON    AGE
pvc-e429fd5b-2efe-11e8-9e9d-02c5db71785a   2Gi        RWO            Delete           Bound     default/ceph-vol01   default                  1m

calvinh@ubuntu-ws:~/Source/canonical-kubernetes-demos/cdk-minio$ kubectl get pvc
NAME         STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ceph-vol01   Bound     pvc-e429fd5b-2efe-11e8-9e9d-02c5db71785a   2Gi        RWO            default        2m
```

## Destroying the cluster and storage

The following command will destroy the cluster and all attached storage:

```
 juju destroy-controller cpe-k8s --destroy-all-models --destroy-storage
```

## Troubleshooting and Common Errors

If you see the following error in your syslog:

```
 missing features 400000000000000
```

Run the following command from the ceph-osd nodes:

```
 ceph osd crush tunables hammer
```

## Useful Links
- [http://docs.ceph.com/docs/jewel/rados/operations/pools/](http://docs.ceph.com/docs/jewel/rados/operations/pools/)
- [https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-with-snap-on-ubuntu](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-with-snap-on-ubuntu)
- [https://jujucharms.com/docs/2.3/charms-storage-ceph](https://jujucharms.com/docs/2.3/charms-storage-ceph)
- [https://jujucharms.com/ceph-osd](https://jujucharms.com/ceph-osd)
- [https://jujucharms.com/ceph-mon](https://jujucharms.com/ceph-mon)
- [https://kubernetes.io/docs/getting-started-guides/ubuntu/storage/](https://kubernetes.io/docs/getting-started-guides/ubuntu/storage/)
- [https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/#whats-next](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/#whats-next)
