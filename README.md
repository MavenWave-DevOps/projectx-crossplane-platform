# Projectx Crossplane Platform

## Requirements
* [Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)
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
In order to develop this repo, knowledge of [Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/) and [Kustomize components](https://kubectl.docs.kubernetes.io/guides/config_management/components/) are required.

### Adding Components
Example:

`src/components/crossplane/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patchesJson6902:
- target:
    group: apiextensions.crossplane.io
    version: v1
    kind: Composition
    name: platform
  path: crossplane.yaml
```
`src/components/crossplane/crossplane.yaml`
```yaml
---
- op: add
  path: /spec/resources/-1
  value:
    name: crossplane
    base:
      apiVersion: helm.crossplane.io/v1beta1
      kind: Release
      metadata:
        annotations: 
          crossplane.io/external-name: crossplane
      spec:
        forProvider:
          chart:
            name: crossplane
            repository: https://charts.crossplane.io/stable/
            version: 1.7.0
          namespace: crossplane-system
          wait: true
        rollbackLimit: 5
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: spec.providerConfigRef.name
      transforms:
      - type: string
        string:
          fmt: "%s-cluster"
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: metadata.name
      transforms:
      - type: string
        string:
          fmt: "%s-crossplane"

```

### Adding a Composition
Example:
`src/compositions/gcp-secure-gitops/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

nameSuffix: -gcp-secure-gitops
commonLabels:
  provider: gcp
  security: high
  gitops: argocd
  
resources:
- ../../base

components:
- ../../components/gcp/network
- ../../components/gcp/kms
- ../../components/gcp/gke
- ../../components/opa-gatekeeper
- ../../components/crossplane
- ../../components/gcp/crossplane
- ../../components/argo-cd

patchesJson6902:
- target:
    group: apiextensions.crossplane.io
    version: v1
    kind: Composition
    name: platform
  path: gke_patches.yaml
```