#!/bin/bash
# Telco Hub Validated Pattern Installation Script
#
# Environment variables can be used to override defaults:
# - KUBECTL_TOOL: Set to 'kubectl' or 'oc' (default: oc)
# - KUBECONFIG_PATH: Path to kubeconfig file (default: ~/.kube/kubeconfig)

set -e

# Pattern configuration
PATTERN_NAME="telco-hub"
PATTERN_NAMESPACE="telco-hub-pattern"
VALUES_HUB="values-hub.yaml"
VALUES_GLOBAL="values-global.yaml"

# Tool configuration
KUBECTL_TOOL="${KUBECTL_TOOL:-oc}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/kubeconfig}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl tool is available
    if ! command -v "$KUBECTL_TOOL" &> /dev/null; then
        log_error "Kubernetes CLI ($KUBECTL_TOOL) is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if logged into OpenShift
    if ! "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" whoami &> /dev/null; then
        log_error "Not logged into OpenShift cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

validate_config() {
    log_info "Validating pattern configuration..."
    
    if [[ ! -f "$VALUES_HUB" ]]; then
        log_error "Hub values file ($VALUES_HUB) not found"
        exit 1
    fi
    
    if [[ ! -f "$VALUES_GLOBAL" ]]; then
        log_error "Global values file ($VALUES_GLOBAL) not found"
        exit 1
    fi
    
    # Check if git repo URL is configured
    if grep -q "your-org/telco-reference" "$VALUES_HUB"; then
        log_warn "Please update the git.repoURL in $VALUES_HUB with your actual repository URL"
    fi
    
    log_info "Configuration validation passed"
}

install_gitops_operator() {
    log_info "Installing OpenShift GitOps operator..."

    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" apply -f ../reference-crs/required/gitops/clusterrole.yaml \
              -f ../reference-crs/required/gitops/clusterrolebinding.yaml \
              -f ../reference-crs/required/gitops/gitopsNS.yaml \
              -f ../reference-crs/required/gitops/gitopsOperatorGroup.yaml \
              -f ../reference-crs/required/gitops/gitopsSubscription.yaml

    log_info "Waiting for GitOps operator to be ready..."
    # Wait for the subscription to be ready first
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=CatalogSourcesUnhealthy=false sub openshift-gitops-operator -n openshift-gitops-operator --timeout=300s
    
    # Wait for the operator to be installed
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=Available deployment/openshift-gitops-operator-controller-manager -n openshift-gitops-operator --timeout=300s

    # Wait for ArgoCD namespace to be created
    while ! "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" get namespace openshift-gitops &> /dev/null; do
        log_info "Waiting for openshift-gitops namespace to be created..."
        sleep 5
    done

    # Wait for ArgoCD server to be ready
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=Available deployment/openshift-gitops-server -n openshift-gitops --timeout=600s
}

deploy_pattern() {
    log_info "Deploying Telco Hub pattern..."
    
    # Create pattern namespace
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" create namespace "$PATTERN_NAMESPACE" --dry-run=client -o yaml | "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" apply -f -
    
    # Deploy the Helm chart
    helm upgrade --install "$PATTERN_NAME" ./charts/all/telco-hub \
        --namespace "$PATTERN_NAMESPACE" \
        --values "$VALUES_GLOBAL" \
        --values "$VALUES_HUB" \
        --wait \
        --timeout=10m
    
    log_info "Pattern deployed successfully"
}

show_status() {
    log_info "Pattern deployment status:"
    echo
    log_info "ArgoCD Applications:"
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" get applications.argoproj.io --all-namespaces -l app.kubernetes.io/part-of=${PATTERN_NAME}-pattern
    echo
    log_info "Pattern Resources:"
    "$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" get all -n "$PATTERN_NAMESPACE"
    echo
    log_info "Access ArgoCD console:"
    echo "URL: https://$("$KUBECTL_TOOL" --kubeconfig="$KUBECONFIG_PATH" get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
    echo
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --check-only   Only check prerequisites and validate config"
    echo "  --status       Show pattern deployment status"
    echo
    echo "Examples:"
    echo "  $0              # Deploy the pattern"
    echo "  $0 --check-only # Check prerequisites only"
    echo "  $0 --status     # Show status"
}

# Main execution
main() {
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        --check-only)
            check_prerequisites
            validate_config
            log_info "All checks passed. Ready to deploy."
            exit 0
            ;;
        --status)
            show_status
            exit 0
            ;;
        "")
            log_info "Starting Telco Hub pattern deployment..."
            check_prerequisites
            validate_config
            install_gitops_operator
            deploy_pattern
            show_status
            log_info "Telco Hub pattern deployment completed!"
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
