#!/bin/bash

echo "🔍 Enterprise SPIRE Verification Script"
echo "======================================="
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "🔸 $1"
    echo "----------------------------------------"
}

# Function to check pod status
check_pods() {
    local context=$1
    local namespace=$2
    local app_label=$3
    local description=$4
    
    echo "Checking $description..."
    kubectl --context $context -n $namespace get pods -l app=$app_label --no-headers 2>/dev/null || {
        echo "❌ Failed to get pods in context $context namespace $namespace"
        return 1
    }
    
    local ready_pods=$(kubectl --context $context -n $namespace get pods -l app=$app_label --no-headers 2>/dev/null | grep "Running" | wc -l)
    local total_pods=$(kubectl --context $context -n $namespace get pods -l app=$app_label --no-headers 2>/dev/null | wc -l)
    
    if [ $ready_pods -gt 0 ] && [ $ready_pods -eq $total_pods ]; then
        echo "✅ $description: $ready_pods/$total_pods running"
        return 0
    else
        echo "❌ $description: $ready_pods/$total_pods running"
        return 1
    fi
}

# Function to test SPIRE server API
test_spire_api() {
    local context=$1
    local namespace=$2
    local pod_prefix=$3
    local description=$4
    
    echo "Testing $description API..."
    local server_pod=$(kubectl --context $context -n $namespace get pod -l app=$pod_prefix --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$server_pod" ]; then
        echo "❌ No $description pod found"
        return 1
    fi
    
    if kubectl --context $context -n $namespace exec $server_pod -- /opt/spire/bin/spire-server bundle show -socketPath /run/spire/sockets/server.sock >/dev/null 2>&1; then
        echo "✅ $description API is responding"
        return 0
    else
        echo "❌ $description API is not responding"
        return 1
    fi
}

print_section "Verifying upstream cluster (Root Identity Provider)"

# Check if upstream cluster exists
if ! kubectl config get-contexts upstream-spire-cluster >/dev/null 2>&1; then
    echo "❌ Upstream cluster context not found"
    echo "   Run: ./scripts/setup-enterprise-clusters.sh"
    exit 1
fi

# Verify upstream components
check_pods "upstream-spire-cluster" "spire-upstream" "spire-upstream-db" "Upstream Database"
UPSTREAM_DB_STATUS=$?

check_pods "upstream-spire-cluster" "spire-upstream" "spire-upstream-server" "Upstream SPIRE Server"
UPSTREAM_SERVER_STATUS=$?

test_spire_api "upstream-spire-cluster" "spire-upstream" "spire-upstream-server" "Upstream SPIRE Server"
UPSTREAM_API_STATUS=$?

print_section "Verifying downstream cluster (Regional/Workload cluster)"

# Check if downstream cluster exists
if ! kubectl config get-contexts downstream-spire-cluster >/dev/null 2>&1; then
    echo "❌ Downstream cluster context not found"
    echo "   Run: ./scripts/setup-enterprise-clusters.sh"
    exit 1
fi

# Verify downstream components
check_pods "downstream-spire-cluster" "spire-downstream" "spire-downstream-db" "Downstream Database"
DOWNSTREAM_DB_STATUS=$?

check_pods "downstream-spire-cluster" "spire-downstream" "spire-downstream-server" "Downstream SPIRE Server"
DOWNSTREAM_SERVER_STATUS=$?

check_pods "downstream-spire-cluster" "spire-downstream" "spire-downstream-agent" "Downstream SPIRE Agents (Control)"
DOWNSTREAM_AGENT_STATUS=$?

check_pods "downstream-spire-cluster" "downstream-workloads" "spire-downstream-agent" "Downstream SPIRE Agents (Workload)"
DOWNSTREAM_WORKLOAD_AGENT_STATUS=$?

test_spire_api "downstream-spire-cluster" "spire-downstream" "spire-downstream-server" "Downstream SPIRE Server"
DOWNSTREAM_API_STATUS=$?

print_section "Verifying enterprise workload services"

# Check enterprise workloads
check_pods "downstream-spire-cluster" "downstream-workloads" "enterprise-api" "Enterprise API Service"
ENTERPRISE_API_STATUS=$?

check_pods "downstream-spire-cluster" "downstream-workloads" "data-processor" "Data Processor Service"
DATA_PROCESSOR_STATUS=$?

check_pods "downstream-spire-cluster" "downstream-workloads" "security-gateway" "Security Gateway Service"
SECURITY_GATEWAY_STATUS=$?

print_section "Testing service connectivity"

# Test if services can access SPIRE sockets
echo "Testing SPIRE socket access from workloads..."
WORKLOAD_POD=$(kubectl --context downstream-spire-cluster -n downstream-workloads get pod -l app=enterprise-api --no-headers 2>/dev/null | head -1 | awk '{print $1}')

if [ -n "$WORKLOAD_POD" ]; then
    if kubectl --context downstream-spire-cluster -n downstream-workloads exec $WORKLOAD_POD -- test -S /run/spire/sockets/agent.sock 2>/dev/null; then
        echo "✅ Workloads can access SPIRE agent socket"
        SOCKET_ACCESS_STATUS=0
    else
        echo "❌ Workloads cannot access SPIRE agent socket"
        SOCKET_ACCESS_STATUS=1
    fi
else
    echo "❌ No enterprise workload pod found for testing"
    SOCKET_ACCESS_STATUS=1
fi

print_section "Federation and trust bundle verification"

# Check trust bundles
echo "Verifying trust bundles..."
kubectl --context upstream-spire-cluster -n spire-upstream get configmap spire-bundle >/dev/null 2>&1
UPSTREAM_BUNDLE_STATUS=$?

kubectl --context downstream-spire-cluster -n spire-downstream get configmap spire-bundle >/dev/null 2>&1
DOWNSTREAM_BUNDLE_STATUS=$?

kubectl --context downstream-spire-cluster -n downstream-workloads get configmap spire-bundle >/dev/null 2>&1
WORKLOAD_BUNDLE_STATUS=$?

if [ $UPSTREAM_BUNDLE_STATUS -eq 0 ]; then
    echo "✅ Upstream trust bundle ConfigMap exists"
else
    echo "❌ Upstream trust bundle ConfigMap missing"
fi

if [ $DOWNSTREAM_BUNDLE_STATUS -eq 0 ]; then
    echo "✅ Downstream trust bundle ConfigMap exists"
else
    echo "❌ Downstream trust bundle ConfigMap missing"
fi

if [ $WORKLOAD_BUNDLE_STATUS -eq 0 ]; then
    echo "✅ Workload trust bundle ConfigMap exists"
else
    echo "❌ Workload trust bundle ConfigMap missing"
fi

print_section "Enterprise deployment verification summary"

echo "🏢 Architecture Status:"
echo ""

echo "   🔸 Upstream Cluster (Root CA):"
if [ $UPSTREAM_DB_STATUS -eq 0 ] && [ $UPSTREAM_SERVER_STATUS -eq 0 ] && [ $UPSTREAM_API_STATUS -eq 0 ]; then
    echo "     ✅ HEALTHY - Database, Server, and API operational"
else
    echo "     ❌ ISSUES - Check upstream cluster components"
fi

echo ""
echo "   🔸 Downstream Cluster (Regional):"
if [ $DOWNSTREAM_DB_STATUS -eq 0 ] && [ $DOWNSTREAM_SERVER_STATUS -eq 0 ] && [ $DOWNSTREAM_API_STATUS -eq 0 ]; then
    echo "     ✅ HEALTHY - Database, Server, and API operational"
else
    echo "     ❌ ISSUES - Check downstream cluster components"
fi

echo ""
echo "   🔸 SPIRE Agents:"
if [ $DOWNSTREAM_AGENT_STATUS -eq 0 ] && [ $DOWNSTREAM_WORKLOAD_AGENT_STATUS -eq 0 ]; then
    echo "     ✅ HEALTHY - Agents running in both namespaces"
else
    echo "     ❌ ISSUES - Check SPIRE agent deployments"
fi

echo ""
echo "   🔸 Enterprise Workloads:"
if [ $ENTERPRISE_API_STATUS -eq 0 ] && [ $DATA_PROCESSOR_STATUS -eq 0 ] && [ $SECURITY_GATEWAY_STATUS -eq 0 ]; then
    echo "     ✅ HEALTHY - All enterprise services operational"
else
    echo "     ❌ ISSUES - Check enterprise workload deployments"
fi

echo ""
echo "   🔸 Trust Infrastructure:"
if [ $UPSTREAM_BUNDLE_STATUS -eq 0 ] && [ $DOWNSTREAM_BUNDLE_STATUS -eq 0 ] && [ $WORKLOAD_BUNDLE_STATUS -eq 0 ]; then
    echo "     ✅ HEALTHY - Trust bundles configured across clusters"
else
    echo "     ❌ ISSUES - Trust bundle configuration incomplete"
fi

echo ""

# Overall status
TOTAL_CHECKS=11
SUCCESSFUL_CHECKS=0

[ $UPSTREAM_DB_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $UPSTREAM_SERVER_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $UPSTREAM_API_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DOWNSTREAM_DB_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DOWNSTREAM_SERVER_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DOWNSTREAM_API_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DOWNSTREAM_AGENT_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DOWNSTREAM_WORKLOAD_AGENT_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $ENTERPRISE_API_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $DATA_PROCESSOR_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))
[ $SECURITY_GATEWAY_STATUS -eq 0 ] && ((SUCCESSFUL_CHECKS++))

echo "📊 Overall Status: $SUCCESSFUL_CHECKS/$TOTAL_CHECKS checks passed"

if [ $SUCCESSFUL_CHECKS -eq $TOTAL_CHECKS ]; then
    echo "🎉 Enterprise SPIRE deployment is fully operational!"
    echo ""
    echo "🌐 Web Dashboard: http://localhost:3000/web-dashboard.html"
    echo "   Start with: ./web/start-dashboard.sh"
    echo ""
    echo "🔗 Access enterprise services:"
    echo "   kubectl --context downstream-spire-cluster port-forward -n downstream-workloads svc/security-gateway 30080:8080"
    echo ""
    exit 0
elif [ $SUCCESSFUL_CHECKS -gt 7 ]; then
    echo "⚠️  Enterprise deployment is mostly operational with minor issues"
    exit 0
else
    echo "❌ Enterprise deployment has significant issues requiring attention"
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "   1. Check cluster status: kubectl --context upstream-spire-cluster get nodes"
    echo "   2. Check cluster status: kubectl --context downstream-spire-cluster get nodes"
    echo "   3. Restart setup: ./scripts/setup-enterprise-clusters.sh"
    echo "   4. Check logs: kubectl logs -n <namespace> <pod-name>"
    exit 1
fi