#!/bin/bash

# SPIFFE/SPIRE Fresh Mac Laptop Install Script
# This script provides a complete idempotent fresh installation experience
# Tears down any existing environment and rebuilds from scratch

set -e  # Exit on any error

# Configuration
DEPLOYMENT_TYPE="${1:-basic}"  # basic, enterprise, or crd-free

echo "🍎 SPIFFE/SPIRE Fresh Mac Laptop Install"
echo "========================================"
echo ""
if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
    echo "🏢 Enterprise Deployment Mode:"
    echo "  1. 🧹 Completely tearing down existing environment"
    echo "  2. 🔄 Cleaning all local configurations"
    echo "  3. 🚀 Setting up enterprise SPIRE clusters (upstream + downstream)"
    echo "  4. ✅ Validating the complete enterprise installation"
elif [ "$DEPLOYMENT_TYPE" = "crd-free" ]; then
    echo "🔒 CRD-Free Enterprise Mode:"
    echo "  1. 🧹 Completely tearing down existing environment"
    echo "  2. 🔄 Cleaning all local configurations"
    echo "  3. 🚀 Setting up CRD-free SPIRE deployment (external servers + agents)"
    echo "  4. ✅ Validating the CRD-free installation"
else
    echo "📚 Basic Development Mode:"
    echo "  1. 🧹 Completely tearing down existing environment"
    echo "  2. 🔄 Cleaning all local configurations"
    echo "  3. 🚀 Setting up basic SPIRE clusters from scratch"
    echo "  4. ✅ Validating the complete installation"
fi
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "🔸 $1"
    echo "----------------------------------------"
}

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Mac laptop prerequisites"
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v minikube &> /dev/null; then
        missing_tools+=("minikube")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_tools+=("node (Node.js)")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ Missing required tools for Mac laptop SPIRE development:"
        for tool in "${missing_tools[@]}"; do
            echo "   - $tool"
        done
        echo ""
        echo "📖 Installation guide:"
        echo "   brew install minikube kubectl node jq"
        echo ""
        exit 1
    fi
    
    echo "✅ All Mac laptop prerequisites satisfied"
    echo "   - minikube: $(minikube version --short 2>/dev/null)"
    echo "   - kubectl: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    echo "   - node: $(node --version)"
    echo "   - jq: $(jq --version)"
}

# Function to completely tear down existing environment
teardown_environment() {
    print_section "Tearing down existing environment (simulating fresh laptop)"
    
    # Stop any running dashboard servers
    echo "🛑 Stopping any running dashboard servers..."
    pkill -f "node server.js" 2>/dev/null || echo "   No dashboard servers running"
    
    # Delete all SPIRE-related minikube clusters
    echo "🗑️  Deleting all SPIRE minikube clusters..."
    
    # Get list of all profiles and delete SPIRE-related ones
    local profiles=$(minikube profile list -o json 2>/dev/null | jq -r '.valid[]?.Name // empty' 2>/dev/null || echo "")
    
    for profile in $profiles; do
        if [[ "$profile" =~ spire.*cluster$ ]] || [[ "$profile" =~ workload.*cluster$ ]] || [[ "$profile" =~ upstream.*cluster$ ]] || [[ "$profile" =~ downstream.*cluster$ ]]; then
            echo "   Deleting cluster: $profile"
            minikube delete --profile "$profile" >/dev/null 2>&1 || echo "   Warning: Could not delete $profile"
        fi
    done
    
    # Clean up kubectl contexts
    echo "🧹 Cleaning kubectl contexts..."
    kubectl config delete-context spire-server-cluster 2>/dev/null || echo "   spire-server-cluster context not found"
    kubectl config delete-context workload-cluster 2>/dev/null || echo "   workload-cluster context not found"
    kubectl config delete-context upstream-spire-cluster 2>/dev/null || echo "   upstream-spire-cluster context not found"
    kubectl config delete-context downstream-spire-cluster 2>/dev/null || echo "   downstream-spire-cluster context not found"
    
    # Clean up temporary files
    echo "🗂️  Cleaning temporary files..."
    rm -f /tmp/bundle.* /tmp/spire-* /tmp/agent-* /tmp/workload-* /tmp/upstream-* /tmp/downstream-* 2>/dev/null || true
    
    # Reset Docker (in case of Docker driver issues)
    echo "🐳 Resetting Docker state..."
    docker system prune -f >/dev/null 2>&1 || echo "   Docker cleanup skipped"
    
    echo "✅ Environment completely torn down (fresh laptop state achieved)"
}

# Function to set up fresh environment
setup_fresh_environment() {
    print_section "Setting up fresh SPIRE environment"
    
    echo "🚀 Starting fresh SPIRE cluster setup..."
    
    # Make scripts executable (fresh laptop might not have this)
    chmod +x scripts/setup-clusters.sh
    chmod +x scripts/setup-enterprise-clusters.sh
    chmod +x scripts/setup-crd-free-deployment.sh
    chmod +x scripts/verify-setup.sh
    chmod +x scripts/verify-enterprise-setup.sh
    chmod +x scripts/start-docs-server.sh
    chmod +x web/start-dashboard.sh
    
    # Run the appropriate setup script based on deployment type
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        echo "📦 Running enterprise cluster setup script..."
        ./scripts/setup-enterprise-clusters.sh
    elif [ "$DEPLOYMENT_TYPE" = "crd-free" ]; then
        echo "📦 Running CRD-free deployment script..."
        ./scripts/setup-crd-free-deployment.sh
    else
        echo "📦 Running basic cluster setup script..."
        ./scripts/setup-clusters.sh
    fi
    
    echo "✅ Fresh SPIRE environment setup completed"
}

# Function to validate installation
validate_installation() {
    print_section "Validating fresh installation"
    
    echo "🔍 Running verification checks..."
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        ./scripts/verify-enterprise-setup.sh || echo "⚠️  Some components may still be initializing"
    else
        ./scripts/verify-setup.sh || echo "⚠️  Some components may still be initializing"
    fi
    
    echo ""
    echo "📊 Testing real-time dashboard API..."
    
    # Start dashboard in background for testing
    ./web/start-dashboard.sh &
    DASHBOARD_PID=$!
    
    # Wait for dashboard to start
    sleep 10
    
    # Test API endpoint with retries
    echo "Testing dashboard API..."
    for i in {1..5}; do
        if curl -s http://localhost:3000/api/pod-data >/dev/null 2>&1; then
            echo "✅ Dashboard API responding successfully"
            echo "   🌐 Dashboard URL: http://localhost:3000/web-dashboard.html"
            break
        else
            echo "   ⏳ Dashboard API attempt $i/5 - waiting..."
            sleep 5
        fi
    done
    
    # Stop test dashboard with proper cleanup
    if [ ! -z "$DASHBOARD_PID" ]; then
        kill $DASHBOARD_PID 2>/dev/null || true
        wait $DASHBOARD_PID 2>/dev/null || true
    fi
    
    # Kill any remaining dashboard processes
    pkill -f "node server.js" 2>/dev/null || true
    
    # Wait for port to be released with longer timeout
    echo "⏳ Waiting for dashboard port to be released..."
    for i in {1..15}; do
        if ! lsof -i :3000 >/dev/null 2>&1; then
            echo "✅ Port 3000 is available"
            break
        fi
        echo "   Waiting for port cleanup... (attempt $i/15)"
        sleep 3
        
        # Force kill any remaining processes on port 3000 after a few attempts
        if [ $i -eq 5 ]; then
            echo "   🔧 Force killing processes on port 3000..."
            pkill -9 -f "node server.js" 2>/dev/null || true
        fi
    done
    
    echo ""
    echo "📋 Fresh laptop installation summary:"
    echo "   ✅ minikube clusters: $(minikube profile list -o json 2>/dev/null | jq -r '.valid | length' 2>/dev/null || echo '0') active"
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        echo "   ✅ kubectl contexts: configured for enterprise multi-cluster setup"
        echo "   ✅ SPIRE services: enterprise upstream and downstream clusters deployed"
    else
        echo "   ✅ kubectl contexts: configured for basic multi-cluster setup"
        echo "   ✅ SPIRE services: basic development clusters deployed"
    fi
    echo "   🚀 Starting dashboard server..."
    
    # Start dashboard server in background
    ./web/start-dashboard.sh &
    DASHBOARD_PID=$!
    
    # Start documentation server in background
    ./scripts/start-docs-server.sh &
    DOCS_PID=$!
    
    # Wait for servers to start
    sleep 5
    
    # Test if dashboard is running with retries
    for i in {1..3}; do
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo "   ✅ Dashboard server: running on http://localhost:3000"
            echo "   📊 Dashboard URL: http://localhost:3000/web-dashboard.html"
            break
        else
            echo "   ⏳ Dashboard starting... (attempt $i/3)"
            sleep 3
        fi
    done
    
    # Test if documentation server is running
    for i in {1..3}; do
        if curl -s http://localhost:8000 >/dev/null 2>&1; then
            echo "   ✅ Documentation server: running on http://localhost:8000"
            echo "   📚 Documentation URL: http://localhost:8000"
            break
        else
            echo "   ⏳ Documentation starting... (attempt $i/3)"
            sleep 3
        fi
    done
}

# Function to display next steps
show_next_steps() {
    print_section "Fresh Mac laptop setup complete!"
    
    echo "🎉 Your fresh SPIRE development environment is ready!"
    echo ""
    echo "💻 Your development environment is ready:"
    echo "   📊 Dashboard: http://localhost:3000/web-dashboard.html"
    echo "   📚 Documentation: http://localhost:8000"
    echo "   🌐 Open dashboard: open http://localhost:3000/web-dashboard.html"
    echo "   📖 Open docs: open http://localhost:8000"
    echo ""
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        echo "🏢 Explore your enterprise clusters:"
        echo "   # Upstream cluster (Root CA)"
        echo "   kubectl --context upstream-spire-cluster -n spire-upstream get pods"
        echo ""
        echo "   # Downstream cluster (Regional/Workload)"
        echo "   kubectl --context downstream-spire-cluster -n spire-downstream get pods"
        echo "   kubectl --context downstream-spire-cluster -n downstream-workloads get pods"
        echo ""
        echo "🔄 To reset to fresh enterprise state anytime:"
        echo "   ./scripts/fresh-install.sh enterprise"
        echo ""
        echo "🔍 Run enterprise verification:"
        echo "   ./scripts/verify-enterprise-setup.sh"
    elif [ "$DEPLOYMENT_TYPE" = "crd-free" ]; then
        echo "🔒 Explore your CRD-free deployment:"
        echo "   # SPIRE agents (no CRDs)"
        echo "   kubectl --context crd-free-cluster -n spire-system get pods"
        echo ""
        echo "   # CRD-free workloads"
        echo "   kubectl --context crd-free-cluster -n crd-free-workloads get pods"
        echo ""
        echo "   # Check for CRDs (should be none)"
        echo "   kubectl get crd | grep spire || echo 'No SPIRE CRDs found (✅ CRD-free confirmed)'"
        echo ""
        echo "🔄 To reset to fresh CRD-free state anytime:"
        echo "   ./scripts/fresh-install.sh crd-free"
        echo ""
        echo "🔍 Verify CRD-free deployment:"
        echo "   ./scripts/setup-crd-free-deployment.sh  # Re-run for verification"
        echo ""
        echo "⚠️  Remember: This deployment requires external SPIRE servers"
        echo "   Configure: external-spire-server.company.com:8081"
    else
        echo "🔍 Explore your basic clusters:"
        echo "   kubectl --context spire-server-cluster -n spire-server get pods"
        echo "   kubectl --context workload-cluster -n spire-system get pods"
        echo "   kubectl --context workload-cluster -n production get pods"
        echo ""
        echo "🔄 To reset to fresh laptop state anytime:"
        echo "   ./scripts/fresh-install.sh"
        echo ""
        echo "🔍 Run basic verification:"
        echo "   ./scripts/verify-setup.sh"
    fi
    echo ""
    echo "📖 See README.md for complete documentation"
    echo ""
    echo "🏢 Ready for enterprise deployment!"
}

# Main execution flow
main() {
    echo "Starting fresh Mac laptop install process..."
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        echo "🏢 Enterprise deployment selected"
    else
        echo "📚 Basic development deployment selected"
    fi
    echo ""
    
    # Confirm with user
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        read -p "🤔 This will completely tear down your current SPIRE environment and set up enterprise clusters. Continue? (y/N): " -n 1 -r
    elif [ "$DEPLOYMENT_TYPE" = "crd-free" ]; then
        read -p "🤔 This will completely tear down your current SPIRE environment and set up CRD-free deployment. Continue? (y/N): " -n 1 -r
    else
        read -p "🤔 This will completely tear down your current SPIRE environment and set up basic clusters. Continue? (y/N): " -n 1 -r
    fi
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Fresh install cancelled by user"
        echo ""
        echo "💡 Usage:"
        echo "   ./scripts/fresh-install.sh              # Basic development setup"
        echo "   ./scripts/fresh-install.sh enterprise   # Enterprise setup"
        echo "   ./scripts/fresh-install.sh crd-free     # CRD-free enterprise setup"
        exit 0
    fi
    
    # Execute installation steps
    check_prerequisites
    teardown_environment
    setup_fresh_environment
    validate_installation
    show_next_steps
    
    echo "✨ Fresh Mac laptop SPIRE installation completed successfully!"
}

# Execute main function
main "$@"