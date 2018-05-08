# Canonical Kubernetes Demos

This repository contains source-code and documentation for various Canonical Kubernetes (CDK) demos. These are used for conferences, demonstrations, training and PoC.

## Deploying Canonical Kubernetes

Most of the documentation for the demos in this repository assume you already have a Canonical Kubernetes cluster up and running. If you need the steps to deploy a cluster, they can be found here: [Canonical Kubernetes Deployment Guide](https://kubernetes.io/docs/getting-started-guides/ubuntu/installation/).

Additional steps can be found on the Juju store for Canonical Kubernetes: [https://jujucharms.com/canonical-kubernetes/](https://jujucharms.com/canonical-kubernetes/). There are also some demo repositories in this repo which explain how to deploy Canonical Kubernetes onto various public clouds, including AWS, Azure and OVH.

## Demo List

- Deploying CDK on Azure
- Deploying CDK on AWS
- CDK with Ceph as a default StorageClass for PV/PVC
- CDK with Minio to provide S3 type storage
- CDK with Helm

## Third-party Product Integrations

Documentation and source-code for third-party software integration with Canonical Kubernetes can be found in a separate repository here: [Canonical Kubernetes Third-Party Integration Documentation](https://github.com/CanonicalLtd/canonical-kubernetes-third-party-integrations).

This additional repository is used to document things like third-party load-balancer integration, SDN/NFV plugins, security products and much more.  

## Getting Help

If your issue is regarding a bug in the Canonical Kubernetes distribution itself, you can raise them here: [Canonical Kubernetes Bundle Builder](https://github.com/juju-solutions/bundle-canonical-kubernetes/issues).

Support for Canonical Kubernetes can be purchased here: [https://www.ubuntu.com/kubernetes](https://www.ubuntu.com/kubernetes).

Support for Ceph storage can be purchased here: [https://www.ubuntu.com/cloud/storage](https://www.ubuntu.com/cloud/storage)

## Licence and Contributing

The assets in this repository are distributed under the MIT licence, please feel free to re-use and modify our code. Corrections and new demos are always welcome, Pull Requests are always welcome.

If you wish to contribute your own demo, please try to the follow the structure of the other demos. Generally this should include:

- README.MD containing all of the steps for deploying the demo, any configuration, caveats and useful links.
- Any scripts or yaml files used to deploy and configure the demo.
- Any associated licence with any re-used code, I.E if you fork code make sure it includes original licence.

## Useful Links
- [Canoical Kubernetes](https://www.ubuntu.com/kubernetes)
- [Canonical Kubernetes Installation Guide](https://kubernetes.io/docs/getting-started-guides/ubuntu/installation/)
- [Canonical Kubernetes Juju Bundle](https://jujucharms.com/canonical-kubernetes/)
- [Canonical Kubernetes Third-party Integrations](https://github.com/CanonicalLtd/canonical-kubernetes-third-party-integrations/settings)
- [Canonical Kubernetes Helm Charts](https://github.com/CanonicalLtd/canonical-kubernetes-helm-charts)
