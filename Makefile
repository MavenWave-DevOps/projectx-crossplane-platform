current_dir = $(shell pwd)
platform_packages = $(shell ls -d 1 ${current_dir}/package/platform/**)
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
	helm upgrade --install --repo https://charts.crossplane.io/stable --create-namespace --namespace crossplane-system crossplane crossplane --values ${current_dir}/dev/helm/crossplane-values.yaml --wait

## Install ingress-nginx onto Kind cluster
install-ingress-nginx:
	helm upgrade --install --repo https://kubernetes.github.io/ingress-nginx --create-namespace --namespace ingress-nginx ingress-nginx ingress-nginx --values ${current_dir}/dev/helm/ingress-nginx-values.yaml --wait

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
	yq e '.spec.projectID |= "${PROJECTID}"' ${current_dir}/dev/providers/gcp-provider.yaml | kubectl apply -f - ;\

## Create GCP Terrajet providerconfig
create-terrajet-gcp-providerconfig:
	yq e '.spec.projectID |= "${PROJECTID}"' ${current_dir}/dev/providers/terrajet-gcp-provider.yaml  | kubectl apply -f -

## Create Helm providerconfig
create-helm-providerconfig:
	kubectl apply -f ${current_dir}/dev/providers/helm-provider.yaml

## Create providerconfigs
create-providerconfigs: create-provider-secret create-gcp-providerconfig create-terrajet-gcp-providerconfig create-helm-providerconfig

# Create local devlopment cluster
create: create-cluster install-ingress-nginx install-crossplane install-platform

# Setup local devlopment cluster
setup: create-providerconfigs

# TODO cleanup resources
# Destroy local devlopment cluster
destroy: delete-cluster