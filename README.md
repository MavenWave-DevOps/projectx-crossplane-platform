# ProjectX Bootstrap DevOps Control Plane

## Quick Start
This quick start will cover:
* Installing dependencies for the bootstrap
* Creating DevOps Control Plane kind cluster
* Destroying the kind cluster

## Requirements
* Docker or Rancher Desktop
  * For Rancher Desktop: open kubernetes settings and disable kubernetes
* yq
```
brew install yq
```

## Setup DevOps Control Plane
* Clone this repository
* ```sh
  make create
  ```
* ```sh
  export KUBECONFIG=$PWD/kubeconfig
  ```
* Wait until providers are healthy
  ```sh
  kubectl get providers
  ```
  * Set Kubeconfig environment variable
* ```sh
  make setup PROJECTID=<gcp project id> CPNAME=<control plane name> TENANT=<tenant id>
  ```
## Destroy Local Control Plane
* ```sh
  make destroy
  ```
* This will delete the kind cluster. This will not remove any cloud resources created by the cluster!

# Deploy Configuration
Apply the following manifest to use the Platform API in your cluster.
```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: platform
spec:
  package: ghcr.io/mavenwave-devops/projectx-crossplane-platform #Add the tag to pin a version
  packagePullPolicy: Always

```
