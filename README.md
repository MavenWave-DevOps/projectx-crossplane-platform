# Projectx Crossplane Platform

## Requirements
* Docker
* yq

## Development Setup
Perform the following to create a local Kind cluster and deploy crossplane and the custom compositions to the local cluster.
* ```sh
  make create
  ```
* Set your KUBECONFIG environment variable (`export KUBECONFIG=$PWD/kubeconfig`)
* Wait until providers are healthy (`kubectl get providers`)
* ```sh
  make setup PROJECTID=<your gcp project ID> CPNAME=<name for your control plane>
  ```
* When finished use `make destroy` to delete the kind cluster. NOTE: This will not remove cloud resources created by Crossplane

## Deploy Configuration
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