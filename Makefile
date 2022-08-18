current_dir = $(shell pwd)
platform_packages = $(shell ls -d ${current_dir}/package/platform/**)
export KUBECONFIG = ${current_dir}/kubeconfig
creds = $${HOME}/.config/gcloud/application_default_credentials.json

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help

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

## Create a Kind cluster
create-cluster:
	kind create cluster --name platform-crossplane --config=${current_dir}/dev/kind/config.yaml --kubeconfig=${current_dir}/kubeconfig || true

## Delete Kind cluster
delete-cluster:
	kind delete cluster --name platform-crossplane

## Install crossplane onto Kind cluster
install-crossplane:
	helm upgrade --install --repo https://charts.crossplane.io/stable --version v1.9.0 --create-namespace --namespace crossplane-system crossplane crossplane --values ${current_dir}/dev/crossplane/values.yaml --wait

## Install ingress-nginx onto Kind cluster
install-ingress-nginx:
	kustomize build dev/ingress-nginx | kubectl apply -f -

## Install platform CRDs in cluster
install-platform:
	for i in ${platform_packages}; do kubectl apply -f $$i; done

## Delete Crossplane GCP provider secret
delete-provider-secret:
	kubectl -n crossplane-system delete secret gcp-default || true

## Create Crossplane GCP provider secret
create-provider-secret: delete-provider-secret
	kubectl -n crossplane-system create secret generic gcp-default --from-file=credentials=${creds}

## Create GCP providerconfig
create-gcp-providerconfig:
	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}")' ${current_dir}/dev/providers/gcp-provider.yaml | kubectl apply -f - ;\

## Create GCP Terrajet providerconfig
create-terrajet-gcp-providerconfig:
	yq e '(.spec.projectID |= "${PROJECTID}") | (.metadata.name |= "${TENANT}")' ${current_dir}/dev/providers/terrajet-gcp-provider.yaml  | kubectl apply -f -

## Create Helm providerconfig
create-helm-providerconfig:
	yq e '.metadata.name |= "${TENANT}"' ${current_dir}/dev/providers/helm-provider.yaml | kubectl apply -f -

## Create Helm Provider
create-helm-provider:
	kubectl apply -f ${current_dir}/dev/helm-provider/

## Create providerconfigs
create-providerconfigs: create-provider-secret create-gcp-providerconfig create-helm-providerconfig

## Create K8s namespace
create-ns:
	kubectl create namespace ${TENANT} || true

# Create local devlopment cluster
create: create-cluster install-ingress-nginx install-crossplane create-helm-provider install-platform

# Setup local devlopment cluster
setup: create-ns create-providerconfigs

# TODO cleanup resources
# Destroy local devlopment cluster
destroy: delete-cluster