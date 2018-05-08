# Using Helm with Canonical Kubernetes

Helm is currently shipped as a Spell which can be deployed using Conjure-up. We can also do the deployment using a script which is included in this demo or using the snap.

There are two parts to Helm, the Helm client and the Tiller server which runs on our Kubernetes Cluster.

Helm is essentially a package manager for Kubernetes which helps collate and manage the various yaml files, binaries and scripts used to deploy software on Kubernetes.

## Deploying Helm + Tiller

We first assume you have juju installed and have deployed a CDK cluster. Also install and conjure kubectl, make sure kubectl config is in ~/.kube/config. The steps for deploying CDK on AWS or Azure can be found in this repository, see the folder cdk-aws or cdk-azure.

We can deploy Helm using the snap:

```
sudo apt-get install snapd
sudo snap install helm
```

Or you can use the script provided with this repository, which is forked from the Spell:

```
./helm-installer.ch
```

This will download Helm from Google and deploy the binary, so be patient. Also, can check the status of the Tiller pods by running this command:

```
kubectl -n kube-system get po
```

Helm should now be ready to roll on your cluster.

## Deploying a Chart

We need to first run an update to get the latest charts:

```
helm repo update
```

Next we can search charts:

```
helm search docker-registry
NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
stable/docker-registry	1.1.1        	2.6.2      	A Helm chart for Docker Registry

```

If you're using juju, make sure you have opened the Helm port on all your worker nodes, 44134:

```
juju run --unit kubernetes-worker/0 "open-port 44134"
juju run --unit kubernetes-worker/1 "open-port 44134"
juju run --unit kubernetes-worker/2 "open-port 44134"
```

And finally we can install a simple chart:
```
helm install stable/docker-registry --debug
helm install stable/mysql --debug
```

## Writing a Chart

Charts are the package format for Helm, a full guide on writing charts has been provided in the Helm Manual here: [https://docs.helm.sh/developing_charts/#charts](https://docs.helm.sh/developing_charts/#charts).

Upstream charts can be found here: [https://github.com/kubernetes/charts/tree/master/stable](https://github.com/kubernetes/charts/tree/master/stable).

## Useful Links
- [https://docs.helm.sh/using_helm/](https://docs.helm.sh/using_helm/)
- [https://docs.helm.sh/developing_charts/#charts](https://docs.helm.sh/developing_charts/#chart)
- [https://github.com/kubernetes/charts/tree/master/stable](https://github.com/kubernetes/charts/tree/master/stable)
- [https://github.com/kubernetes/helm](https://github.com/kubernetes/helm)
- [https://raw.githubusercontent.com/conjure-up/spells/master/canonical-kubernetes/addons/common.sh](https://raw.githubusercontent.com/conjure-up/spells/master/canonical-kubernetes/addons/common.sh)
