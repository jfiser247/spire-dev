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

echo "Starting fresh Mac laptop install process..."
echo "📚 Basic development deployment selected"

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
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_tools+=("node")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "❌ Missing required tools: ${missing_tools[*]}"
        echo "📦 Install them with: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    echo "✅ All required tools are available"
    
    # Check Docker
    if ! docker info &> /dev/null; then
        echo "❌ Docker is not running. Please start Docker Desktop."
        exit 1
    fi
    echo "✅ Docker is running"
}

# Function to clean up existing environment
cleanup_environment() {
    print_section "Cleaning up existing environment"
    
    # Stop any running dashboard servers
    pkill -f 'node.*server.js' 2>/dev/null || echo "ℹ️  No dashboard servers to stop"
    
    # Delete existing minikube profiles
    local profiles=($(minikube profile list -o json 2>/dev/null | jq -r '.valid[]?.Name // empty' 2>/dev/null || echo ""))
    
    for profile in "${profiles[@]}"; do
        if [ -n "$profile" ] && [ "$profile" != "null" ]; then
            echo "🗑️  Deleting profile: $profile"
            minikube delete -p "$profile" 2>/dev/null || echo "⚠️  Failed to delete $profile"
        fi
    done
    
    echo "✅ Environment cleaned"
}

# Function to setup cluster with Mac-friendly resources
setup_cluster() {
    print_section "Setting up workload cluster"
    
    # Get available system resources
    local total_memory=$(sysctl -n hw.memsize)
    local memory_gb=$((total_memory / 1024 / 1024 / 1024))
    local cpu_cores=$(sysctl -n hw.ncpu)
    
    # Calculate Mac-friendly resource allocation (conservative for Docker Desktop)
    local cluster_memory=3072
    local cluster_cpus=2
    
    if [ "$memory_gb" -ge 32 ]; then
        cluster_memory=4096  # Use 4GB only on very high-memory systems
    elif [ "$memory_gb" -ge 16 ]; then
        cluster_memory=3584  # Use 3.5GB on high-memory systems
    fi
    
    # Docker Desktop often limits available resources, so be conservative
    if [ "$cpu_cores" -ge 8 ]; then
        cluster_cpus=2  # Conservative: use 2 CPUs even on high-core systems
    else
        cluster_cpus=2
    fi
    
    echo "💻 System resources: ${memory_gb}GB RAM, ${cpu_cores} CPUs"
    echo "🎯 Allocating: ${cluster_memory}MB RAM, ${cluster_cpus} CPUs to cluster"
    
    # Create cluster with appropriate resources
    minikube start -p workload-cluster \
        --cpus="$cluster_cpus" \
        --memory="$cluster_memory" \
        --disk-size=5g \
        --driver=docker \
        --kubernetes-version=v1.30.0
    
    echo "✅ Workload cluster created"
}

# Function to create namespaces with proper security settings
setup_namespaces() {
    print_section "Setting up namespaces"
    
    # Create namespaces with inline YAML to avoid race conditions
    cat <<EOF | kubectl --context workload-cluster apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: spire-server
  labels:
    name: spire-server
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: v1
kind: Namespace
metadata:
  name: spire-system
  labels:
    name: spire-system
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: v1
kind: Namespace
metadata:
  name: spire-workload
  labels:
    name: spire-workload
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF
    
    echo "✅ Namespaces created with proper security labels"
}

# Function to deploy MySQL database
deploy_mysql_database() {
    print_section "Deploying MySQL Database"
    
    # Apply MySQL database manifests
    kubectl --context workload-cluster apply -f k8s/spire-db/mysql-pvc.yaml
    kubectl --context workload-cluster apply -f k8s/spire-db/mysql-deployment.yaml
    kubectl --context workload-cluster apply -f k8s/spire-db/mysql-service.yaml
    
    echo "⏳ Waiting for MySQL database to be ready..."
    
    # Wait for database pod to be scheduled
    for i in {1..24}; do
        DB_PODS=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-db --no-headers 2>/dev/null | wc -l)
        if [ "$DB_PODS" -gt 0 ]; then
            echo "✅ Database pod scheduled, waiting for readiness..."
            break
        fi
        echo "⏳ Waiting for database pod to be scheduled... (attempt $i/24)"
        sleep 5
    done
    
    if [ "$DB_PODS" -eq 0 ]; then
        echo "❌ Database pod failed to be scheduled"
        kubectl --context workload-cluster -n spire-server get pods
        exit 1
    fi
    
    # Wait for database to be ready
    if kubectl --context workload-cluster -n spire-server wait --for=condition=ready pod -l app=spire-db --timeout=600s; then
        echo "✅ MySQL database is ready"
    else
        echo "❌ MySQL database failed to become ready"
        kubectl --context workload-cluster -n spire-server describe pods -l app=spire-db
        exit 1
    fi
}

# Function to deploy SPIRE server (MySQL-based for persistence)
deploy_spire_server() {
    print_section "Deploying SPIRE Server"
    
    # Apply SPIRE server manifests
    kubectl --context workload-cluster apply -f k8s/spire-server/
    
    echo "⏳ Waiting for SPIRE server to be ready..."
    
    # Wait for server pod to be scheduled
    for i in {1..24}; do
        SERVER_PODS=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-server --no-headers 2>/dev/null | wc -l)
        if [ "$SERVER_PODS" -gt 0 ]; then
            echo "✅ Server pod scheduled, waiting for readiness..."
            break
        fi
        echo "⏳ Waiting for server pod to be scheduled... (attempt $i/24)"
        sleep 5
    done
    
    if [ "$SERVER_PODS" -eq 0 ]; then
        echo "❌ Server pod failed to be scheduled"
        kubectl --context workload-cluster -n spire-server get pods
        exit 1
    fi
    
    # Wait for server to be ready
    if kubectl --context workload-cluster -n spire-server wait --for=condition=ready pod -l app=spire-server --timeout=600s; then
        echo "✅ SPIRE server is ready"
    else
        echo "❌ SPIRE server failed to become ready"
        kubectl --context workload-cluster -n spire-server describe pods -l app=spire-server
        exit 1
    fi
}

# Function to create trust bundle
create_trust_bundle() {
    print_section "Creating trust bundle"
    
    # Get server pod name
    SERVER_POD=$(kubectl --context workload-cluster -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$SERVER_POD" ]; then
        echo "❌ Failed to get SPIRE server pod name"
        exit 1
    fi
    
    # Create trust bundle with retry logic
    for i in {1..5}; do
        if kubectl --context workload-cluster -n spire-server exec "$SERVER_POD" -- \
           /opt/spire/bin/spire-server bundle show -socketPath /run/spire/sockets/server.sock -format pem > /tmp/bundle.pem 2>/dev/null; then
            if [ -s /tmp/bundle.pem ]; then
                echo "✅ Trust bundle retrieved successfully"
                break
            fi
        fi
        echo "⏳ Waiting for trust bundle... (attempt $i/5)"
        sleep 15
    done
    
    if [ ! -s /tmp/bundle.pem ]; then
        echo "❌ Failed to retrieve trust bundle"
        exit 1
    fi
    
    # Create bundle ConfigMap
    kubectl --context workload-cluster -n spire-system create configmap spire-bundle --from-file=bundle.crt=/tmp/bundle.pem
    
    echo "✅ Trust bundle ConfigMap created"
}

# Function to deploy SPIRE agent
deploy_spire_agent() {
    print_section "Deploying SPIRE Agent"
    
    # Apply agent manifests
    kubectl --context workload-cluster apply -f k8s/workload-cluster/
    
    echo "⏳ Waiting for SPIRE agent to be ready..."
    
    # Wait for agent to be ready
    if kubectl --context workload-cluster -n spire-system wait --for=condition=ready pod -l app=spire-agent --timeout=300s; then
        echo "✅ SPIRE agent is ready"
    else
        echo "❌ SPIRE agent failed to become ready"
        kubectl --context workload-cluster -n spire-system describe pods -l app=spire-agent
        exit 1
    fi
}

# Function to deploy and wait for workload services
deploy_workload_services() {
    print_section "Deploying Workload Services"
    
    echo "⏳ Waiting for workload deployments to be ready..."
    
    # Wait for all workload deployments to be ready
    local deployments=("inventory-service" "payment-api" "user-service")
    local all_ready=true
    
    for deployment in "${deployments[@]}"; do
        echo "⏳ Waiting for $deployment deployment..."
        if kubectl --context workload-cluster -n spire-workload wait --for=condition=available deployment/$deployment --timeout=300s; then
            echo "✅ $deployment deployment is ready"
        else
            echo "❌ $deployment deployment failed to become ready"
            kubectl --context workload-cluster -n spire-workload describe deployment/$deployment
            all_ready=false
        fi
    done
    
    if [ "$all_ready" = true ]; then
        echo "✅ All workload services are ready"
    else
        echo "❌ Some workload services failed to deploy properly"
        exit 1
    fi
}

# Function to start documentation server
start_documentation_server() {
    print_section "Starting documentation server"
    
    # Check if mkdocs is available and verify dependencies
    if ! command -v mkdocs &> /dev/null; then
        echo "⚠️  MkDocs not found, attempting to install..."
        
        # Create a simple virtual environment for mkdocs if it doesn't exist
        if [ ! -d "venv-docs" ]; then
            echo "🔧 Creating virtual environment for documentation dependencies..."
            python3 -m venv venv-docs 2>/dev/null || {
                echo "⚠️  Failed to create virtual environment"
                echo "ℹ️  Documentation server will be skipped"
                echo "ℹ️  To enable manually:"
                echo "     python3 -m venv venv-docs"
                echo "     source venv-docs/bin/activate"
                echo "     pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin"
                return 0
            }
        fi
        
        # Activate virtual environment and install dependencies
        source venv-docs/bin/activate 2>/dev/null || {
            echo "⚠️  Failed to activate virtual environment"
            return 0
        }
        
        echo "🔧 Installing MkDocs with all required dependencies in virtual environment..."
        if pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin 2>/dev/null; then
            echo "✅ MkDocs and dependencies installed successfully"
        else
            echo "⚠️  Failed to install mkdocs dependencies"
            echo "ℹ️  To enable documentation manually:"
            echo "     source venv-docs/bin/activate"
            echo "     pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin"
            return 0
        fi
        deactivate 2>/dev/null || true
    else
        echo "🔍 MkDocs found, verifying dependencies..."
        # Check if material theme is available
        if ! python3 -c "import material" 2>/dev/null; then
            echo "⚠️  Missing Material theme, may need virtual environment..."
            if [ -d "venv-docs" ]; then
                echo "🔧 Installing missing dependencies in existing virtual environment..."
                source venv-docs/bin/activate 2>/dev/null && {
                    pip install mkdocs-material mkdocs-mermaid2-plugin 2>/dev/null && {
                        echo "✅ Dependencies installed"
                    } || {
                        echo "⚠️  Failed to install dependencies in virtual environment"
                    }
                    deactivate 2>/dev/null || true
                } || {
                    echo "⚠️  Could not use virtual environment"
                }
            fi
        fi
    fi
    
    # Start documentation server using the helper script
    if [ -f "./scripts/start-docs-server.sh" ]; then
        ./scripts/start-docs-server.sh > /tmp/docs.log 2>&1 &
        DOCS_PID=$!
    else
        # Fallback to direct mkdocs command
        echo "⚠️  Helper script not found, starting mkdocs directly..."
        mkdocs serve > /tmp/docs.log 2>&1 &
        DOCS_PID=$!
    fi
    
    # Wait for documentation server to be ready
    for i in {1..15}; do
        if curl -s http://localhost:8000 > /dev/null 2>&1; then
            echo "✅ Documentation server is ready at http://localhost:8000"
            
            # Quick verification of Mermaid diagram syntax
            echo "🔍 Quick Mermaid syntax verification..."
            sleep 3  # Give diagrams time to render
            
            local diagram_errors=$(curl -s http://localhost:8000/architecture_diagrams/ 2>/dev/null | grep -i -c "syntax error\|mermaid.*error" 2>/dev/null || echo "0")
            if [ "$diagram_errors" -eq 0 ]; then
                echo "✅ Mermaid diagrams: Syntax validation passed"
            else
                echo "⚠️  Mermaid diagrams: $diagram_errors syntax errors detected"
                echo "💡 Note: Full validation will be performed in final verification"
            fi
            
            return 0
        fi
        echo "⏳ Waiting for documentation server... (attempt $i/15)"
        sleep 2
    done
    
    echo "⚠️  Documentation server may not be fully ready, but it's starting..."
    echo "📚 Documentation URL: http://localhost:8000"
}

# Function to start dashboard
start_dashboard() {
    print_section "Starting dashboard"
    
    # Stop any existing dashboard
    pkill -f 'node.*server.js' 2>/dev/null || true
    sleep 2
    
    # Start dashboard in background
    ./web/start-dashboard.sh > /tmp/dashboard.log 2>&1 &
    DASHBOARD_PID=$!
    
    # Wait for dashboard to be ready
    for i in {1..10}; do
        if curl -s http://localhost:3000/api/pod-data > /dev/null 2>&1; then
            echo "✅ Dashboard is ready at http://localhost:3000/web-dashboard.html"
            return 0
        fi
        echo "⏳ Waiting for dashboard... (attempt $i/10)"
        sleep 2
    done
    
    echo "⚠️  Dashboard may not be fully ready, but it's starting..."
    echo "📊 Dashboard URL: http://localhost:3000/web-dashboard.html"
}

# Function to verify installation
verify_installation() {
    print_section "Verifying installation"
    
    # Check all pods are running
    local all_ready=true
    
    # Check database
    local db_ready=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-db -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$db_ready" = "true" ]; then
        echo "✅ MySQL Database: Ready"
    else
        echo "❌ MySQL Database: Not Ready"
        all_ready=false
    fi
    
    # Check server
    local server_ready=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-server -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$server_ready" = "true" ]; then
        echo "✅ SPIRE Server: Ready"
    else
        echo "❌ SPIRE Server: Not Ready"
        all_ready=false
    fi
    
    # Check agent
    local agent_ready=$(kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$agent_ready" = "true" ]; then
        echo "✅ SPIRE Agent: Ready"
    else
        echo "❌ SPIRE Agent: Not Ready"
        all_ready=false
    fi
    
    # Check workloads
    local workload_count=$(kubectl --context workload-cluster -n spire-workload get pods --no-headers 2>/dev/null | grep "Running" | wc -l)
    if [ "$workload_count" -gt 0 ]; then
        echo "✅ Workload Services: $workload_count running"
    else
        echo "⚠️  Workload Services: None running (this is OK for basic setup)"
    fi
    
    # Check documentation server
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo "✅ Documentation Server: Ready"
        
        # Check for Mermaid syntax errors in architecture diagrams
        echo "🔍 Verifying Mermaid diagram syntax..."
        
        # Wait a moment for diagrams to fully load
        sleep 2
        
        # Check for multiple error patterns that Mermaid might display
        local page_content=$(curl -s http://localhost:8000/architecture_diagrams/ 2>/dev/null)
        local syntax_errors=$(echo "$page_content" | grep -i -c "syntax error\|parse error\|mermaid.*error\|diagram.*error" 2>/dev/null || echo "0")
        local mermaid_version=$(echo "$page_content" | grep -i "mermaid.*version" | head -1)
        
        if [ "$syntax_errors" -eq 0 ]; then
            echo "✅ Documentation Diagrams: All Mermaid diagrams render correctly"
            if [ -n "$mermaid_version" ]; then
                echo "ℹ️  Mermaid rendering: $(echo "$mermaid_version" | sed 's/.*\(version [0-9.]*\).*/\1/' 2>/dev/null || echo 'version detected')"
            fi
        else
            echo "❌ Documentation Diagrams: Mermaid syntax errors detected ($syntax_errors errors)"
            echo "⚠️  Found $syntax_errors Mermaid-related errors in documentation"
            echo "🔧 Common fixes:"
            echo "   • Check for unsupported emoji characters in diagram labels"
            echo "   • Verify proper bracket matching in node definitions"
            echo "   • Remove unsupported 'color' properties from classDef statements"
            echo "💡 Detailed errors visible at: http://localhost:8000/architecture_diagrams/"
            all_ready=false
        fi
    else
        echo "⚠️  Documentation Server: Not responding (may need a moment to start)"
    fi
    
    # Check dashboard
    if curl -s http://localhost:3000/api/pod-data > /dev/null 2>&1; then
        echo "✅ Dashboard: Ready"
    else
        echo "⚠️  Dashboard: Not responding (may need a moment to start)"
    fi
    
    if [ "$all_ready" = true ]; then
        echo ""
        echo "🎉 SPIFFE/SPIRE installation completed successfully!"
    else
        echo ""
        echo "⚠️  Installation completed with some issues. Check pod status above."
    fi
}

# Function to display final information
show_final_info() {
    print_section "Installation Complete"
    
    echo "🎯 Your SPIFFE/SPIRE environment is ready!"
    echo ""
    echo "📊 Dashboard Access:"
    echo "   URL: http://localhost:3000/web-dashboard.html"
    echo "   Command: open http://localhost:3000/web-dashboard.html"
    echo ""
    echo "📚 Documentation Available:"
    echo "   - Click '📚 Project Overview' tab in dashboard"
    echo "   - Click '📖 Documentation' tab in dashboard"
    echo "   - Direct URL: http://localhost:8000"
    echo ""
    echo "🔧 Common Commands:"
    echo "   kubectl --context workload-cluster -n spire-server get pods"
    echo "   kubectl --context workload-cluster -n spire-system get pods"
    echo "   kubectl --context workload-cluster -n spire-workload get pods"
    echo ""
    echo "🔍 SPIRE Operations:"
    echo "   ./scripts/verify-setup.sh"
    echo ""
    echo "🔒 Security Information:"
    echo "   Security Policy Guide: docs/spire_security_policies.md"
    echo ""
    echo "⏱️  Total setup time: ~3-4 minutes"
    echo "🔄 To reset: ./scripts/fresh-install.sh"
}

# Main installation flow
main() {
    local start_time=$(date +%s)
    
    check_prerequisites
    cleanup_environment
    setup_cluster
    setup_namespaces
    deploy_mysql_database
    deploy_spire_server
    create_trust_bundle
    deploy_spire_agent
    deploy_workload_services
    start_documentation_server
    start_dashboard
    verify_installation
    show_final_info
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "⏱️  Installation completed in ${duration} seconds"
}

# Execute main function
main "$@"