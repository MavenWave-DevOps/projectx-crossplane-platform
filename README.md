# Projectx Crossplane Platform

## Requirements
* [Crossplane Plugin](https://crossplane.io/docs/v1.8/getting-started/install-configure.html#install-crossplane-cli)
* Kubernetes cluster (Cloud or local)

## Setup
```
kubectl create namespace crossplane-system
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane --namespace crossplane-system crossplane-stable/crossplane -f hacking/values.yaml
```
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

## Development
* Create a development Kubernetes cluster (cloud, K3D, Minikube)
* Install Crossplane using instructions above