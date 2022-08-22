# Projectx Crossplane Platform

## Requirements
* [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
* [Helm](https://helm.sh/docs/intro/quickstart/)
* [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
* yq

## Development Setup
Perform the following to create a local Kind cluster and deploy crossplane and the custom compositions to the local cluster.
* ```sh
  make create
  ```
* Wait until providers are healthy (`kubectl get providers`)
* ```sh
  make setup PROJECTID=<your gcp project ID> CPNAME=<name for your control plane>
  ```
* Set your KUBECONFIG environment variable (`export KUBECONFIG=$PWD/kubeconfig`)
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