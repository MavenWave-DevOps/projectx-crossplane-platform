MKFILEPATH = $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILEDIR = $(dir $(MKFILEPATH))
SOURCEDIR = $(MKFILEDIR)/internal
BUILDDIR = $(MKFILEDIR)/build
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

define build_comp
kustomize build $(1) -o $(2);
endef

define install_comp
kubectl apply -f $(1);
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
	$(MKDIR) $(subst /,$(PSEP),$(TARGETDIRS)) $(ERRIGNORE)

## Copy crossplane package yaml
cp-pkg:
	cp $(SOURCEDIR)/crossplane.yaml $(BUILDDIR)/

## Build crossplane compositions
build: directories cp-pkg
	$(foreach dir, $(SOURCEDIRS), $(call build_comp,$(dir),$(subst $(SOURCEDIR),$(BUILDDIR),$(dir))))

## Create Kind cluster
create-cluster:
	kind create cluster --name platform-crossplane --config=${MKFILEDIR}dev/kind/config.yaml --kubeconfig=${MKFILEDIR}kubeconfig || true

## Delete Kind cluster
delete-cluster:
	kind delete cluster --name platform-crossplane

## Install crossplane onto Kind cluster
install-crossplane:
	helm upgrade --install --repo https://charts.crossplane.io/stable --version v1.9.0 --create-namespace --namespace crossplane-system crossplane crossplane --values ${MKFILEDIR}dev/crossplane/values.yaml --wait

## Install ingress-nginx onto Kind cluster
install-ingress-nginx:
	kustomize build dev/ingress-nginx | kubectl apply -f -

## Install platform CRDs in cluster
install: build
	$(foreach dir, $(TARGETDIRS), $(call install_comp,$(dir)))

## Create tenant namespace
create-ns:
	kubectl create ns ${TENANT} || true

## Delete Crossplane GCP provider secret
delete-provider-secret:
	kubectl -n ${TENANT} delete secret gcp-default || true

## Create Crossplane GCP provider secret
create-provider-secret: create-ns delete-provider-secret
	kubectl -n ${TENANT} create secret generic gcp-default --from-file=credentials=${CREDS}

## Create GCP providerconfig
create-gcp-providerconfig:
	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}") | (.spec.credentials.secretRef.namespace |= "${TENANT}")' ${MKFILEDIR}dev/providers/gcp-provider.yaml | kubectl apply -f - ;\

# ## Create GCP Terrajet providerconfig
# create-terrajet-gcp-providerconfig:
# 	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}") | (.spec.credentials.secretRef.namespace |= "${TENANT}")' ${MKFILEDIR}dev/providers/terrajet-gcp-provider.yaml  | kubectl apply -f -

## Create Helm providerconfig
create-helm-providerconfig:
	yq e '.metadata.name |= "${TENANT}"' ${MKFILEDIR}dev/providers/helm-provider.yaml | kubectl apply -f -

## Create Helm Provider
create-helm-provider:
	kubectl apply -f ${MKFILEDIR}dev/helm-provider/

## Create providerconfigs
create-providerconfigs: create-provider-secret create-gcp-providerconfig create-helm-providerconfig

# Create local devlopment cluster
create: create-cluster install-ingress-nginx install-crossplane create-helm-provider install

# Setup local devlopment cluster
setup: create-ns create-providerconfigs

# TODO cleanup resources
# Destroy local devlopment cluster
destroy: delete-cluster

## Clean Crossplane packages
clean-package:
	cd ${BUILDDIR} ;\
	rm *.xpkg || true

## Build Crossplane package
package: build clean-package
	cd ${BUILDDIR} ;\
	kubectl crossplane build configuration ;\

## Push Crossplane package
push: package
	cd ${BUILDDIR} ;\
	kubectl crossplane push configuration ${CONTAINER}