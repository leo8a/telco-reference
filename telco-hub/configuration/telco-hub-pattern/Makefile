# Telco Hub Validated Pattern Makefile

PATTERN_NAME = telco-hub
CHART_PATH = ./charts/all/telco-hub
VALUES_GLOBAL = values-global.yaml
VALUES_HUB = values-hub.yaml
NAMESPACE = telco-hub-pattern

KUBECTL_TOOL 	?= oc
KUBECONFIG_PATH ?= ${HOME}/.kube/kubeconfig

.PHONY: help check install status uninstall clean lint validate

help: ## Show this help message
	@echo "Telco Hub Validated Pattern"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Check prerequisites and validate configuration
	@echo
	@echo "Checking prerequisites and validating configuration..."
	./pattern.sh --check-only

install: check ## Install the telco-hub pattern
	@echo
	@echo "Installing telco-hub pattern..."
	./pattern.sh

status: ## Show pattern deployment status
	@echo
	@echo "Showing pattern status..."
	./pattern.sh --status

uninstall: ## Uninstall the telco-hub pattern
	@echo
	@echo "Uninstalling telco-hub pattern..."
	helm uninstall $(PATTERN_NAME) -n $(NAMESPACE) || true
	$(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) delete applications -n openshift-gitops -l app.kubernetes.io/part-of=telco-hub-pattern || true
	$(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) delete namespace $(NAMESPACE) || true

clean-gitops-apps: ## Clean up all gitops applications
	@echo
	@echo "Cleaning up gitops applications..."
	$(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) delete applications.argoproj.io --all --all-namespaces || true

clean: uninstall ## Clean up all pattern resources
	@echo
	@echo "Cleaning up pattern resources..."
	$(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) delete projects telco-hub || true

lint: ## Lint Helm charts
	@echo
	@echo "Linting Helm charts..."
	helm lint $(CHART_PATH)

validate: lint ## Validate Helm templates
	@echo
	@echo "Validating Helm templates..."
	helm template $(PATTERN_NAME) $(CHART_PATH) \
		--values $(VALUES_GLOBAL) \
		--values $(VALUES_HUB) \
		--validate

dry-run: ## Perform a dry-run installation
	@echo
	@echo "Performing dry-run installation..."
	helm upgrade --install $(PATTERN_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--values $(VALUES_GLOBAL) \
		--values $(VALUES_HUB) \
		--dry-run --debug

template: ## Generate Kubernetes manifests from Helm templates
	@echo
	@echo "Generating templates..."
	helm template $(PATTERN_NAME) $(CHART_PATH) \
		--values $(VALUES_GLOBAL) \
		--values $(VALUES_HUB) \
		--output-dir ./output

debug: ## Debug the pattern configuration
	@echo
	@echo "Debug information:"
	@echo "Pattern Name: $(PATTERN_NAME)"
	@echo "Chart Path: $(CHART_PATH)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Values Files: $(VALUES_GLOBAL), $(VALUES_HUB)"
	@echo ""
	@echo "Git Repository Configuration:"
	@grep -E "repoURL|targetRevision" $(VALUES_HUB) || echo "Git config not found"
	@echo ""
	@echo "Enabled Components:"
	@grep -A 20 "components:" $(VALUES_HUB) | grep "enabled: true" || echo "No enabled components found"

argocd-login: ## Get ArgoCD login information
	@echo
	@echo "ArgoCD Login Information:"
	@echo "URL: https://$(shell $(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo 'ArgoCD not deployed')"
	@echo "Username: admin"
	@echo "Password: $(shell $(KUBECTL_TOOL) --kubeconfig=$(KUBECONFIG_PATH) get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d || echo 'ArgoCD not deployed')"
