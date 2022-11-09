MKFILEPATH = $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILEDIR = $(dir $(MKFILEPATH))
BUILDDIR = $(MKFILEDIR)/build
WORKDIR = ${MKFILEDIR}.work
K3D = ${WORKDIR}/k3d
HELM = ${WORKDIR}/helm
KUSTOMIZE = ${WORKDIR}/kustomize
KUBECTL = ${WORKDIR}/kubectl
KUBECTL_CROSSPLANE = ${WORKDIR}/kubectl-crossplane
SOURCEDIR = $(MKFILEDIR)platform
MKDIR = mkdir -p
TAG ?= latest
CONTAINER ?= ghcr.io/mavenwave-devops/projectx-crossplane-platform:${TAG}
CREDS ?= $${HOME}/.config/gcloud/application_default_credentials.json

UNAME_S := $(shell uname -s)
UNAME_P := $(shell uname -p)

ifeq ($(UNAME_S),Darwin)
	ifneq ($(filter %86,$(UNAME_P)),)
		K3D_DOWNLOAD := curl -Lo ${K3D} https://github.com/k3d-io/k3d/releases/download/v5.4.6/k3d-darwin-amd64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-darwin-amd64.tar.gz
		HELM_ARCH := ${WORKDIR}/darwin-amd64
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_darwin_amd64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
  endif
  ifneq ($(filter arm%,$(UNAME_P)),)
		K3D_DOWNLOAD := curl -Lo ${K3D} https://github.com/k3d-io/k3d/releases/download/v5.4.6/k3d-darwin-arm64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-darwin-arm64.tar.gz
		HELM_ARCH := ${WORKDIR}/darwin-arm64
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_darwin_arm64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/arm64/kubectl"
  endif
endif
ifeq ($(UNAME_S),Linux)
	ifneq ($(filter x86_64,$(UNAME_P)),)
		K3D_DOWNLOAD := curl -Lo ${K3D} https://github.com/k3d-io/k3d/releases/download/v5.4.6/k3d-linux-amd64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-linux-amd64.tar.gz
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_linux_amd64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
	endif
	ifneq ($(filter arm%,$(UNAME_P)),)
		K3D_DOWNLOAD := curl -Lo ${K3D} https://github.com/k3d-io/k3d/releases/download/v5.4.6/k3d-linux-arm64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-linux-arm64.tar.gz
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_linux_arm64.tar.gz
	endif
endif
KUBECTL_CROSSPLANE_DOWNLOAD = curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh

export KUBECONFIG=${MKFILEDIR}kubeconfig

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help directories package

help: ## Show this help message.
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Create buil directories
directories:
	$(MKDIR) $(BUILDDIR) $(WORKDIR)

# Copy crossplane package yaml
cp-pkg:
	cp $(SOURCEDIR)/crossplane.yaml $(BUILDDIR)

install-kustomize: directories
ifneq ($(wildcard ${KUSTOMIZE}), ${KUSTOMIZE})
	$(KUSTOMIZE_DOWNLOAD) ;\
	tar -zxvf ${WORKDIR}/kustomize.tar.gz -C ${WORKDIR} ;\
	rm ${WORKDIR}/kustomize.tar.gz
endif

install-kubectl: directories
ifneq ($(wildcard ${KUBECTL}), ${KUBECTL})
	$(KUBECTL_DOWNLOAD) ;\
	chmod +x ${KUBECTL}
endif

install-k3d: directories
ifneq ($(wildcard ${K3D}), ${K3D})
	$(K3D_DOWNLOAD) ;\
	chmod +x ${K3D}
endif

install-helm: directories
ifneq ($(wildcard ${HELM}), ${HELM})
	$(HELM_DOWNLOAD) ;\
	tar -zxvf ${WORKDIR}/helm.tar.gz -C ${WORKDIR} ;\
	mv ${HELM_ARCH}/helm ${WORKDIR} ;\
	rm -Rf ${HELM_ARCH} ;\
	rm ${WORKDIR}/helm.tar.gz
endif

install-crossplane-plugin: directories install-kubectl
ifneq ($(wildcard ${KUBECTL_CROSSPLANE}), ${KUBECTL_CROSSPLANE})
	cd ${WORKDIR} ;\
	$(KUBECTL_CROSSPLANE_DOWNLOAD)
endif

## Build crossplane compositions
build: directories cp-pkg install-kustomize
	$(KUSTOMIZE) build -o $(BUILDDIR) $(SOURCEDIR)

## Create K3D cluster
create-cluster: install-k3d
	${K3D} cluster create platform-crossplane || true

## Delete K3D cluster
delete-cluster:
	${K3D} cluster delete platform-crossplane

## Install crossplane onto K3D cluster
install-crossplane: install-helm
	${HELM} upgrade --install --repo https://charts.crossplane.io/stable --version v1.9.1 --create-namespace --namespace crossplane-system crossplane crossplane --values ${MKFILEDIR}helm/crossplane/values.yaml --wait

## Install platform CRDs in cluster
install: build install-kubectl
	$(KUBECTL) apply -k $(SOURCEDIR)

## Create local development cluster
local-dev: create-cluster install-crossplane install

## Create tenant namespace
create-ns: install-kubectl
	${KUBECTL} create ns ${TENANT} || true

## Delete Crossplane GCP provider secret
delete-provider-secret:
	${KUBECTL} -n ${TENANT} delete secret gcp-default || true ;\
	${KUBECTL} -n ${TENANT} delete secret k8s-default || true

## Create Crossplane GCP provider secret
create-provider-secret: create-ns delete-provider-secret
	${KUBECTL} -n ${TENANT} create secret generic gcp-default --from-file=credentials=${CREDS} ;\
	${KUBECTL} -n ${TENANT} create secret generic k8s-default --from-file=credentials=${CREDS}

## Create GCP providerconfig
create-gcp-providerconfig:
	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}") | (.spec.credentials.secretRef.namespace |= "${TENANT}")' ${MKFILEDIR}manifests/provider-configs/gcp-provider.yaml | ${KUBECTL} apply -f - ;\

## Create Helm providerconfig
create-helm-providerconfig:
	yq e '.metadata.name |= "${TENANT}"' ${MKFILEDIR}manifests/provider-configs/helm-provider.yaml | ${KUBECTL} apply -f -

## Create providerconfigs
create-providerconfigs: create-provider-secret create-gcp-providerconfig create-helm-providerconfig

## Setup local devlopment cluster
setup: create-ns create-providerconfigs 

# # TODO cleanup resources
## Destroy local devlopment cluster
destroy: delete-cluster

## Clean local build
clean:
	rm -Rf ${BUILDDIR}

## Clean Crossplane packages
clean-all: destroy clean
	rm -Rf ${WORKDIR}

## Build Crossplane package
package: clean build install-crossplane-plugin
	cd ${BUILDDIR} ;\
	${KUBECTL} crossplane build configuration ;\

## Push Crossplane package
push: package
	cd ${BUILDDIR} ;\
	${KUBECTL} crossplane push configuration ${CONTAINER}
