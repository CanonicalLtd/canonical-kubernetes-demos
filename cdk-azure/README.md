## Deploying Canonical Kubernetes on Azure

Deploying Canonical Kubernetes on Azure is very simple, but we need to do a few extra steps when compared to AWS. We need to install the Azure CLI tool and login first.

Make sure you have installed juju and snap:

```
sudo apt-get install snapd
snap install juju
```

We can first check that juju supports azure through the following command:

```
juju show-cloud azure
```

We can also update the list of clouds juju has available using the following command:

```
juju update-clouds
```

The azure CLI tool needs to be installed using the following command. You may want to download and review the script first for security reasons rather than piping directly into bash:

```
 curl -L https://aka.ms/InstallAzureCli | bash
```

If this does not work, try installing through apt:

```
# first we setup the apt for the repos
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list

#  Install the azure-ci packages
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
sudo apt-get install apt-transport-https
sudo apt-get update && sudo apt-get install azure-cli
```

During the script, your path is updated and your terminal should be restarted:

```
exec -l $SHELL
```

After this has been installed, you can verify the installation it using the command:

```
 az --version
```

The next step is to add the azure credential to juju so we can use it to provision infrastructure:

```
juju add-credential azure
Enter credential name: cpe-azure

Auth Types
  interactive
  service-principal-secret

Select auth type [interactive]:

Enter subscription-id (optional):

To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code DJCVFCQZ4 to authenticate.
[
  {
    "cloudName": "AzureCloud",
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "isDefault": true,
    "name": "Pay-As-You-Go",
    "state": "Enabled",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "user": {
      "name": "calvin.hartwell@canonical.com",
      "type": "user"
    }
  }
]
Credentials added for cloud azure.
```

**__Note that credentials may expire after some time and should be renewed if problems arise with juju when you use Azure.__**

The next step is to bootstrap Azure, change 'mycloud' to something more meaningful, this will be the name of the contoller node on azure:

```
  juju bootstrap azure mycloud
  juju bootstrap azure mycloud
Creating Juju controller "mycloud" on azure/centralus
Looking for packaged Juju agent version 2.3.4 for amd64
Launching controller instance(s) on azure/centralus...
 - machine-0 (arch=amd64 mem=3.5G cores=1)
Installing Juju agent on bootstrap instance
Fetching Juju GUI 2.12.1
Waiting for address
Attempting to connect to 192.168.16.4:22
Attempting to connect to 52.173.249.30:22
Connected to 52.173.249.30
Running machine configuration script...


Bootstrap agent now started
Contacting Juju controller at 192.168.16.4 to verify accessibility...
Bootstrap complete, "mycloud" controller now available
Controller machines are in the "controller" model
Initial model "default" added
```

Once we have the controller node, we are ready to deploy Kubernetes:

```
 juju deploy canonical-kubernetes
```

Or if you have a bundle file:

```
 juju deploy bundle.yaml
```

Finally, you can check the status using:

```
 juju status
```

or

```
 watch --color juju status --color
```

Eventually the colours will all turn green and your cluster is good to go. To access the cluster, we need to install the kubectl command line client and copy the kubernetes configuration file over for it to use:

```
 # If this does not work, try adding the --classic option on the end.
 snap install kubectl --classic
```

Next we copy over the configuration file:

```
  juju scp kubernetes-master/0:/home/ubuntu/config ~/.kube/config
```

Finally, using kubectl we can check that kubernetes cluster interaction is possible:

```
Kubernetes master is running at https://34.253.164.197:443

Heapster is running at https://34.253.164.197:443/api/v1/namespaces/kube-system/services/heapster/proxy
KubeDNS is running at https://34.253.164.197:443/api/v1/namespaces/kube-system/services/kube-dns/proxy
kubernetes-dashboard is running at https://34.253.164.197:443/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy
Grafana is running at https://34.253.164.197:443/api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
InfluxDB is running at https://34.253.164.197:443/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy
```

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'

# Useful Links
- [https://jujucharms.com/docs/2.2/help-azure](https://jujucharms.com/docs/2.3/help-azure)
