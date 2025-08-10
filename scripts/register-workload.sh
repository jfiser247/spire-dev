#!/bin/bash

# SPIRE Workload Registration Script
# This script helps SPIRE administrators register new workloads
# Usage: ./register-workload.sh [OPTIONS]

set -e

# Default configuration
SPIRE_SERVER_NAMESPACE="spire-server"
TRUST_DOMAIN="example.org"
PARENT_ID="spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster"
DEFAULT_TTL="1800"
DEFAULT_WORKLOAD_NAMESPACE="workload"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
SPIRE Workload Registration Script

This script helps register new workloads with SPIRE Server.

Usage: $0 [OPTIONS]

Required Options:
    -n, --name <name>           Workload name (used for SPIFFE ID and selectors)
    -s, --service-account <sa>  Kubernetes ServiceAccount name

Optional Options:
    -w, --workload-ns <ns>      Workload namespace (default: $DEFAULT_WORKLOAD_NAMESPACE)
    -t, --trust-domain <domain> Trust domain (default: $TRUST_DOMAIN)
    -p, --parent-id <id>        Parent SPIFFE ID (default: $PARENT_ID)
    --ttl <seconds>             Certificate TTL in seconds (default: $DEFAULT_TTL)
    --spire-ns <ns>             SPIRE server namespace (default: $SPIRE_SERVER_NAMESPACE)
    -d, --dns-names <names>     Comma-separated DNS names
    -l, --labels <labels>       Comma-separated pod labels (key:value format)
    --service-type <type>       Service type for labeling
    --tier <tier>               Application tier for labeling
    --dry-run                   Show what would be executed without running
    --force                     Skip confirmation prompts
    -h, --help                  Show this help message

Examples:
    # Basic workload registration
    $0 --name my-service --service-account my-service

    # Workload with DNS names and custom TTL
    $0 --name payment-api --service-account payment-api \\
       --dns-names payment-api.production.svc.cluster.local \\
       --ttl 3600

    # Workload with custom labels and service type
    $0 --name user-service --service-account user-service \\
       --service-type backend --tier application \\
       --labels "version:v1.2.3,environment:production"

    # Different namespace and trust domain
    $0 --name inventory-service --service-account inventory-service \\
       --workload-ns production --trust-domain company.com
EOF
}

# Function to validate SPIFFE ID format
validate_spiffe_id() {
    local spiffe_id="$1"
    if [[ ! "$spiffe_id" =~ ^spiffe://[a-zA-Z0-9.-]+(/[a-zA-Z0-9._-]+)*$ ]]; then
        print_error "Invalid SPIFFE ID format: $spiffe_id"
        exit 1
    fi
}

# Function to check if kubectl is available and connected
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Function to check if SPIRE server is running
check_spire_server() {
    print_info "Checking SPIRE server availability..."
    
    if ! kubectl get namespace "$SPIRE_SERVER_NAMESPACE" &> /dev/null; then
        print_error "SPIRE server namespace '$SPIRE_SERVER_NAMESPACE' not found"
        exit 1
    fi

    local server_pods=$(kubectl get pods -n "$SPIRE_SERVER_NAMESPACE" -l app=spire-server --no-headers 2>/dev/null | wc -l)
    if [ "$server_pods" -eq 0 ]; then
        print_error "No SPIRE server pods found in namespace '$SPIRE_SERVER_NAMESPACE'"
        exit 1
    fi

    local ready_pods=$(kubectl get pods -n "$SPIRE_SERVER_NAMESPACE" -l app=spire-server --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    if [ "$ready_pods" -eq 0 ]; then
        print_error "SPIRE server pods are not ready"
        exit 1
    fi

    print_success "SPIRE server is running and ready"
}

# Function to build selectors
build_selectors() {
    local selectors=""
    
    # Add namespace selector
    selectors="$selectors -selector k8s:ns:$WORKLOAD_NAMESPACE"
    
    # Add service account selector
    selectors="$selectors -selector k8s:sa:$SERVICE_ACCOUNT"
    
    # Add app selector
    selectors="$selectors -selector k8s:pod-label:app:$WORKLOAD_NAME"
    
    # Add service type selector if provided
    if [ -n "$SERVICE_TYPE" ]; then
        selectors="$selectors -selector k8s:pod-label:service:$SERVICE_TYPE"
    fi
    
    # Add tier selector if provided
    if [ -n "$TIER" ]; then
        selectors="$selectors -selector k8s:pod-label:tier:$TIER"
    fi
    
    # Add custom labels if provided
    if [ -n "$CUSTOM_LABELS" ]; then
        IFS=',' read -ra LABELS <<< "$CUSTOM_LABELS"
        for label in "${LABELS[@]}"; do
            if [[ "$label" =~ ^([^:]+):(.+)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                selectors="$selectors -selector k8s:pod-label:$key:$value"
            else
                print_warning "Ignoring invalid label format: $label (expected key:value)"
            fi
        done
    fi
    
    echo "$selectors"
}

# Function to build DNS names
build_dns_names() {
    local dns_args=""
    
    if [ -n "$DNS_NAMES" ]; then
        IFS=',' read -ra NAMES <<< "$DNS_NAMES"
        for name in "${NAMES[@]}"; do
            dns_args="$dns_args -dnsName $name"
        done
    fi
    
    echo "$dns_args"
}

# Function to check if entry already exists
check_existing_entry() {
    local spiffe_id="$1"
    print_info "Checking if registration entry already exists..."
    
    local existing_entry=$(kubectl exec -n "$SPIRE_SERVER_NAMESPACE" deployment/spire-server -- \
        /opt/spire/bin/spire-server entry show -spiffeID "$spiffe_id" 2>/dev/null || true)
    
    if [ -n "$existing_entry" ] && echo "$existing_entry" | grep -q "Entry ID"; then
        return 0  # Entry exists
    else
        return 1  # Entry does not exist
    fi
}

# Function to create registration entry
create_registration_entry() {
    local spiffe_id="spiffe://$TRUST_DOMAIN/workload/$WORKLOAD_NAME"
    local selectors=$(build_selectors)
    local dns_names=$(build_dns_names)
    
    validate_spiffe_id "$spiffe_id"
    validate_spiffe_id "$PARENT_ID"
    
    # Check if entry already exists
    if check_existing_entry "$spiffe_id"; then
        if [ "$FORCE" != "true" ]; then
            print_warning "Registration entry already exists for SPIFFE ID: $spiffe_id"
            read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Skipping registration entry creation"
                return 0
            fi
        fi
        
        print_info "Deleting existing registration entry..."
        if [ "$DRY_RUN" = "true" ]; then
            echo "Would run: kubectl exec -n $SPIRE_SERVER_NAMESPACE deployment/spire-server -- /opt/spire/bin/spire-server entry delete -spiffeID $spiffe_id"
        else
            kubectl exec -n "$SPIRE_SERVER_NAMESPACE" deployment/spire-server -- \
                /opt/spire/bin/spire-server entry delete -spiffeID "$spiffe_id" || true
        fi
    fi
    
    # Build the complete command
    local cmd="/opt/spire/bin/spire-server entry create -spiffeID $spiffe_id -parentID $PARENT_ID $selectors -ttl $TTL $dns_names"
    
    print_info "Creating registration entry for workload: $WORKLOAD_NAME"
    print_info "SPIFFE ID: $spiffe_id"
    print_info "Parent ID: $PARENT_ID"
    print_info "TTL: $TTL seconds"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "Would run: kubectl exec -n $SPIRE_SERVER_NAMESPACE deployment/spire-server -- $cmd"
        return 0
    fi
    
    # Execute the command
    if kubectl exec -n "$SPIRE_SERVER_NAMESPACE" deployment/spire-server -- $cmd; then
        print_success "Registration entry created successfully"
        
        # Verify the entry was created
        print_info "Verifying registration entry..."
        kubectl exec -n "$SPIRE_SERVER_NAMESPACE" deployment/spire-server -- \
            /opt/spire/bin/spire-server entry show -spiffeID "$spiffe_id"
    else
        print_error "Failed to create registration entry"
        exit 1
    fi
}

# Function to show configuration summary
show_configuration() {
    cat << EOF

${BLUE}Registration Configuration Summary:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Workload Details:
  Name:                 $WORKLOAD_NAME
  Namespace:            $WORKLOAD_NAMESPACE  
  Service Account:      $SERVICE_ACCOUNT
  SPIFFE ID:            spiffe://$TRUST_DOMAIN/workload/$WORKLOAD_NAME

SPIRE Configuration:
  Trust Domain:         $TRUST_DOMAIN
  Parent ID:            $PARENT_ID
  TTL:                  $TTL seconds
  SPIRE Server NS:      $SPIRE_SERVER_NAMESPACE

Selectors:
  k8s:ns:$WORKLOAD_NAMESPACE
  k8s:sa:$SERVICE_ACCOUNT
  k8s:pod-label:app:$WORKLOAD_NAME
EOF

    if [ -n "$SERVICE_TYPE" ]; then
        echo "  k8s:pod-label:service:$SERVICE_TYPE"
    fi
    
    if [ -n "$TIER" ]; then
        echo "  k8s:pod-label:tier:$TIER"
    fi
    
    if [ -n "$CUSTOM_LABELS" ]; then
        IFS=',' read -ra LABELS <<< "$CUSTOM_LABELS"
        for label in "${LABELS[@]}"; do
            if [[ "$label" =~ ^([^:]+):(.+)$ ]]; then
                echo "  k8s:pod-label:${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
            fi
        done
    fi
    
    if [ -n "$DNS_NAMES" ]; then
        echo ""
        echo "DNS Names:"
        IFS=',' read -ra NAMES <<< "$DNS_NAMES"
        for name in "${NAMES[@]}"; do
            echo "  $name"
        done
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Parse command line arguments
DRY_RUN="false"
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            WORKLOAD_NAME="$2"
            shift 2
            ;;
        -s|--service-account)
            SERVICE_ACCOUNT="$2"
            shift 2
            ;;
        -w|--workload-ns)
            WORKLOAD_NAMESPACE="$2"
            shift 2
            ;;
        -t|--trust-domain)
            TRUST_DOMAIN="$2"
            shift 2
            ;;
        -p|--parent-id)
            PARENT_ID="$2"
            shift 2
            ;;
        --ttl)
            TTL="$2"
            shift 2
            ;;
        --spire-ns)
            SPIRE_SERVER_NAMESPACE="$2"
            shift 2
            ;;
        -d|--dns-names)
            DNS_NAMES="$2"
            shift 2
            ;;
        -l|--labels)
            CUSTOM_LABELS="$2"
            shift 2
            ;;
        --service-type)
            SERVICE_TYPE="$2"
            shift 2
            ;;
        --tier)
            TIER="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set defaults
WORKLOAD_NAMESPACE="${WORKLOAD_NAMESPACE:-$DEFAULT_WORKLOAD_NAMESPACE}"
TTL="${TTL:-$DEFAULT_TTL}"

# Validate required parameters
if [ -z "$WORKLOAD_NAME" ]; then
    print_error "Workload name is required. Use --name option."
    show_usage
    exit 1
fi

if [ -z "$SERVICE_ACCOUNT" ]; then
    print_error "Service account is required. Use --service-account option."
    show_usage
    exit 1
fi

# Validate TTL is a number
if ! [[ "$TTL" =~ ^[0-9]+$ ]]; then
    print_error "TTL must be a positive integer"
    exit 1
fi

# Main execution
main() {
    print_info "Starting SPIRE workload registration process..."
    
    # Pre-flight checks
    check_kubectl
    check_spire_server
    
    # Show configuration
    show_configuration
    
    # Confirmation (unless force or dry-run)
    if [ "$DRY_RUN" != "true" ] && [ "$FORCE" != "true" ]; then
        read -p "Do you want to proceed with this registration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Registration cancelled by user"
            exit 0
        fi
    fi
    
    # Create registration entry
    create_registration_entry
    
    if [ "$DRY_RUN" != "true" ]; then
        print_success "Workload registration completed successfully!"
        echo ""
        print_info "Next steps:"
        echo "1. Deploy your workload to namespace '$WORKLOAD_NAMESPACE'"
        echo "2. Ensure your workload uses ServiceAccount '$SERVICE_ACCOUNT'"
        echo "3. Add required pod labels to match the selectors"
        echo "4. Configure your workload to use the SPIFFE endpoint socket"
        echo ""
        print_info "Example kubectl commands:"
        echo "kubectl get pods -n $WORKLOAD_NAMESPACE -l app=$WORKLOAD_NAME"
        echo "kubectl logs -n $WORKLOAD_NAMESPACE -l app=$WORKLOAD_NAME"
    else
        print_info "Dry run completed. No changes were made."
    fi
}

# Run main function
main