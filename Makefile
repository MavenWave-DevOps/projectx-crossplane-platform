MKFILEPATH = $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILEDIR = $(dir $(MKFILEPATH))
SOURCEDIR = $(MKFILEDIR)/package
BUILDDIR = $(MKFILEDIR)/build
WORKDIR = ${MKFILEDIR}.work
KIND = ${WORKDIR}/kind
HELM = ${WORKDIR}/helm
KUSTOMIZE = ${WORKDIR}/kustomize
KUBECTL = ${WORKDIR}/kubectl
KUBECTL_CROSSPLANE = ${WORKDIR}/kubectl-crossplane
DIRS = platform
SOURCEDIRS = $(foreach dir, $(DIRS), $(foreach comps, $(wildcard $(addprefix $(SOURCEDIR)/, $(dir)/**/kustomization.yaml)), $(subst kustomization.yaml,,$(comps))))
TARGETDIRS =  $(foreach dir, $(subst $(SOURCEDIR),$(BUILDDIR),$(SOURCEDIRS)), $(dir))
MKDIR = mkdir -p
SEP=/
ERRIGNORE = 2>/dev/null
PSEP = $(strip $(SEP))
TAG = latest
CONTAINER = ghcr.io/mavenwave-devops/projectx-crossplane-platform:${TAG}
CREDS = $${HOME}/.config/gcloud/application_default_credentials.json

UNAME_S := $(shell uname -s)
UNAME_P := $(shell uname -p)

ifeq ($(UNAME_S),Darwin)
	ifneq ($(filter %86,$(UNAME_P)),)
		KIND_DOWNLOAD := curl -Lo ${KIND} https://kind.sigs.k8s.io/dl/v0.14.0/kind-darwin-amd64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-darwin-amd64.tar.gz
		HELM_ARCH := ${WORKDIR}/darwin-amd64
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_darwin_amd64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
  endif
  ifneq ($(filter arm%,$(UNAME_P)),)
		KIND_DOWNLOAD := curl -Lo ${KIND} https://kind.sigs.k8s.io/dl/v0.14.0/kind-darwin-arm64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-darwin-arm64.tar.gz
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_darwin_arm64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/arm64/kubectl"
  endif
endif
ifeq ($(UNAME_S),Linux)
	ifneq ($(filter x86_64,$(UNAME_P)),)
		KIND_DOWNLOAD := curl -Lo ${KIND} https://kind.sigs.k8s.io/dl/v0.14.0/kind-linux-amd64
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-linux-amd64.tar.gz
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_linux_amd64.tar.gz
		KUBECTL_DOWNLOAD := curl -Lo ${WORKDIR}/kubectl "https://storage.googleapis.com/kubernetes-release/release/$$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
	endif
	ifneq ($(filter arm%,$(UNAME_P)),)
		HELM_DOWNLOAD := curl -Lo ${WORKDIR}/helm.tar.gz https://get.helm.sh/helm-v3.9.4-linux-arm64.tar.gz
		KUSTOMIZE_DOWNLOAD := curl -Lo ${WORKDIR}/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.7/kustomize_v4.5.7_linux_arm64.tar.gz
	endif
endif
KUBECTL_CROSSPLANE_DOWNLOAD = curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh

export KUBECONFIG=${MKFILEDIR}kubeconfig

define build_comp
${KUSTOMIZE} build $(1) -o $(2);
endef

define install_comp
${KUBECTL} apply -f $(1);
endef

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
	@mkdir -p ${WORKDIR}
	@$(MKDIR) $(subst /,$(PSEP),$(TARGETDIRS)) $(ERRIGNORE)

## Copy crossplane package yaml
cp-pkg:
	cp $(SOURCEDIR)/crossplane.yaml $(BUILDDIR)/

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

install-kind: directories
ifneq ($(wildcard ${KIND}), ${KIND})
	$(KIND_DOWNLOAD) ;\
	chmod +x ${KIND}
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
	$(foreach dir, $(SOURCEDIRS), $(call build_comp,$(dir),$(subst $(SOURCEDIR),$(BUILDDIR),$(dir))))

## Create Kind cluster
create-cluster: install-kind
	${KIND} create cluster --name platform-crossplane --config=${MKFILEDIR}kind/config.yaml --kubeconfig=${MKFILEDIR}kubeconfig || true

## Delete Kind cluster
delete-cluster:
	kind delete cluster --name platform-crossplane

## Install crossplane onto Kind cluster
install-crossplane: install-helm
	${HELM} upgrade --install --repo https://charts.crossplane.io/stable --version v1.9.0 --create-namespace --namespace crossplane-system crossplane crossplane --values ${MKFILEDIR}helm/crossplane/values.yaml --wait

## Install ingress-nginx onto Kind cluster
install-ingress-nginx: install-kustomize install-kubectl
	${KUSTOMIZE} build manifests/ingress-nginx | ${KUBECTL} apply -f -

## Install platform CRDs in cluster
install: build install-kubectl
	$(foreach dir, $(TARGETDIRS), $(call install_comp,$(dir)))

## Create tenant namespace
create-ns: install-kubectl
	${KUBECTL} create ns ${TENANT} || true

## Delete Crossplane GCP provider secret
delete-provider-secret:
	${KUBECTL} -n ${TENANT} delete secret gcp-default || true

## Create Crossplane GCP provider secret
create-provider-secret: create-ns delete-provider-secret
	${KUBECTL} -n ${TENANT} create secret generic gcp-default --from-file=credentials=${CREDS}

## Create GCP providerconfig
create-gcp-providerconfig:
	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}") | (.spec.credentials.secretRef.namespace |= "${TENANT}")' ${MKFILEDIR}manifests/provider-configs/gcp-provider.yaml | ${KUBECTL} apply -f - ;\

# # ## Create GCP Terrajet providerconfig
# # create-terrajet-gcp-providerconfig:
# # 	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}") | (.spec.credentials.secretRef.namespace |= "${TENANT}")' ${MKFILEDIR}manifests/provider-configs/terrajet-gcp-provider.yaml  | kubectl apply -f -

## Create Helm providerconfig
create-helm-providerconfig:
	yq e '.metadata.name |= "${TENANT}"' ${MKFILEDIR}manifests/provider-configs/helm-provider.yaml | ${KUBECTL} apply -f -

## Create Helm Provider
create-helm-provider:
	${KUBECTL} apply -f ${MKFILEDIR}manifests/helm-provider/

## Create providerconfigs
create-providerconfigs: create-provider-secret create-gcp-providerconfig create-helm-providerconfig

## Create local development cluster
create: create-cluster install-ingress-nginx install-crossplane create-helm-provider install

## Setup local devlopment cluster
setup: create-ns create-providerconfigs

# TODO cleanup resources
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