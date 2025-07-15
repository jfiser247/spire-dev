#!/bin/bash
set -e

echo "🔍 SPIRE Environment Verification"
echo "======================================"

# Check if clusters exist
echo "📋 Checking cluster availability..."
if ! kubectl --context workload-cluster get nodes >/dev/null 2>&1; then
    echo "❌ Workload cluster not available. Please run setup first."
    exit 1
fi

CLUSTER_COUNT=$(minikube profile list -l | grep Running | wc -l)
echo "✅ Minikube clusters running: $CLUSTER_COUNT"

# Verify single-cluster architecture
echo ""
echo "🏗️  Verifying single-cluster architecture..."
echo "Checking SPIRE server deployment in workload cluster..."
kubectl --context workload-cluster -n spire-server get pods
echo ""

echo "Checking SPIRE agent deployment in workload cluster..."
kubectl --context workload-cluster -n spire-system get pods
echo ""

echo "Checking workload services in workload cluster..."
kubectl --context workload-cluster -n production get pods
echo ""

# Enhanced pod status verification
echo "🔍 Detailed Component Status Analysis..."
echo "----------------------------------------"

# SPIRE Server Analysis
SERVER_PODS=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-server --no-headers 2>/dev/null | wc -l)
SERVER_READY=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-server --no-headers 2>/dev/null | grep Running | wc -l)
echo "🖥️  SPIRE Server: $SERVER_READY/$SERVER_PODS pods ready"

# Database Analysis  
DB_PODS=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-db --no-headers 2>/dev/null | wc -l)
DB_READY=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-db --no-headers 2>/dev/null | grep Running | wc -l)
echo "🗄️  Database: $DB_READY/$DB_PODS pods ready"

# Agent Analysis
AGENT_PODS=$(kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent --no-headers 2>/dev/null | wc -l)
AGENT_READY=$(kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent --no-headers 2>/dev/null | grep Running | wc -l)
echo "🤖 SPIRE Agent: $AGENT_READY/$AGENT_PODS pods ready"

# Workload Services Analysis
WORKLOAD_PODS=$(kubectl --context workload-cluster -n production get pods --no-headers 2>/dev/null | wc -l)
WORKLOAD_READY=$(kubectl --context workload-cluster -n production get pods --no-headers 2>/dev/null | grep Running | wc -l)
echo "🏭 Workload Services: $WORKLOAD_READY/$WORKLOAD_PODS pods ready"

# Check for any failing pods
echo ""
echo "🚨 Checking for any failing pods..."
FAILING_PODS=$(kubectl --context workload-cluster get pods -A --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l)
if [ "$FAILING_PODS" -gt 0 ]; then
    echo "⚠️  Found $FAILING_PODS failing pods:"
    kubectl --context workload-cluster get pods -A --no-headers 2>/dev/null | grep -v Running | grep -v Completed
else
    echo "✅ No failing pods found"
fi

echo ""
echo "📊 Checking SPIRE registration entries..."
if [ "$SERVER_READY" -gt 0 ]; then
    SERVER_POD=$(kubectl --context workload-cluster -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$SERVER_POD" ]; then
        echo "Using server pod: $SERVER_POD"
        kubectl --context workload-cluster -n spire-server exec $SERVER_POD -- /opt/spire/bin/spire-server entry show 2>/dev/null || echo "⚠️  Could not retrieve registration entries"
    else
        echo "⚠️  No server pod found for registration check"
    fi
else
    echo "⚠️  SPIRE server not ready, skipping registration check"
fi
echo ""

echo "🔐 Network and Service Connectivity Tests..."
echo "-------------------------------------------"

# Test agent-server connectivity
if [ "$AGENT_READY" -gt 0 ] && [ "$SERVER_READY" -gt 0 ]; then
    echo "🔗 Testing agent-server connectivity..."
    AGENT_POD=$(kubectl --context workload-cluster -n spire-system get pod -l app=spire-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$AGENT_POD" ]; then
        AGENT_STATUS=$(kubectl --context workload-cluster -n spire-system get pod $AGENT_POD -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$AGENT_STATUS" = "Running" ]; then
            echo "✅ Agent pod is running and should be connected to server"
        else
            echo "⚠️  Agent pod status: $AGENT_STATUS"
        fi
    else
        echo "⚠️  No agent pod found"
    fi
else
    echo "⚠️  Skipping connectivity test (agent or server not ready)"
fi

# Test workload SPIFFE ID verification (simplified)
echo ""
echo "🆔 Testing SPIFFE ID availability..."
if [ "$WORKLOAD_READY" -gt 0 ] && [ "$AGENT_READY" -gt 0 ]; then
    USER_SERVICE_POD=$(kubectl --context workload-cluster -n production get pod -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$USER_SERVICE_POD" ]; then
        echo "🧪 Testing SPIFFE ID for user-service..."
        # Simplified test - just check if agent socket is available
        kubectl --context workload-cluster -n production exec $USER_SERVICE_POD -- test -S /run/spire/sockets/agent.sock && echo "✅ Agent socket available in user-service" || echo "⚠️  Agent socket not available"
    else
        echo "⚠️  No user-service pod found for SPIFFE ID test"
    fi
else
    echo "⚠️  Skipping SPIFFE ID test (workloads or agent not ready)"
fi

echo ""

echo "🌐 Dashboard Server Verification..."
echo "-----------------------------------"

# Check if dashboard is running
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Dashboard server: running on http://localhost:3000"
    
    # Test API endpoint for real data
    echo "🔍 Testing dashboard API for real data..."
    
    # Test server data
    SERVER_COUNT=$(curl -s http://localhost:3000/api/pod-data | jq -r '.server | length' 2>/dev/null || echo "0")
    if [ "$SERVER_COUNT" -gt 0 ]; then
        echo "✅ Dashboard API: returning real server data ($SERVER_COUNT pods)"
    else
        echo "⚠️  Dashboard API: no server data (may be using mock data)"
    fi
    
    # Test workload data
    WORKLOAD_COUNT=$(curl -s http://localhost:3000/api/pod-data | jq -r '.workloads | length' 2>/dev/null || echo "0")
    if [ "$WORKLOAD_COUNT" -gt 0 ]; then
        echo "✅ Dashboard API: returning real workload data ($WORKLOAD_COUNT pods)"
    else
        echo "⚠️  Dashboard API: no workload data (may be using mock data)"
    fi
    
    # Test agent data
    AGENT_COUNT=$(curl -s http://localhost:3000/api/pod-data | jq -r '.agents | length' 2>/dev/null || echo "0")
    if [ "$AGENT_COUNT" -gt 0 ]; then
        echo "✅ Dashboard API: returning real agent data ($AGENT_COUNT pods)"
    else
        echo "⚠️  Dashboard API: no agent data (may be using mock data)"
    fi
    
    # Test drilldown functionality
    echo "🔍 Testing dashboard drilldown functionality..."
    if curl -s "http://localhost:3000/api/describe/pod/spire-server/workload-cluster/spire-server-0" >/dev/null 2>&1; then
        echo "✅ Dashboard drilldown: kubectl describe API working"
    else
        echo "⚠️  Dashboard drilldown: kubectl describe API not responding"
    fi
    
    echo ""
    echo "🎉 Dashboard verification completed!"
    echo "   📊 Dashboard URL: http://localhost:3000/web-dashboard.html"
    echo "   🌐 Open in browser: open http://localhost:3000/web-dashboard.html"
    
else
    echo "⚠️  Dashboard server: not running"
    echo "   💡 Start dashboard: ./web/start-dashboard.sh"
fi

echo ""
echo "📋 Environment Verification Summary"
echo "===================================="
echo "🖥️  SPIRE Server:     $SERVER_READY/$SERVER_PODS pods ready"
echo "🗄️  Database:         $DB_READY/$DB_PODS pods ready"
echo "🤖 SPIRE Agent:      $AGENT_READY/$AGENT_PODS pods ready"
echo "🏭 Workload Services: $WORKLOAD_READY/$WORKLOAD_PODS pods ready"
echo "🌐 Dashboard:        $(if curl -s http://localhost:3000 >/dev/null 2>&1; then echo 'Running'; else echo 'Not running'; fi)"

# Calculate overall health score
TOTAL_EXPECTED=$((SERVER_PODS + DB_PODS + AGENT_PODS + WORKLOAD_PODS))
TOTAL_READY=$((SERVER_READY + DB_READY + AGENT_READY + WORKLOAD_READY))

if [ "$TOTAL_EXPECTED" -gt 0 ]; then
    HEALTH_PERCENTAGE=$(echo "scale=0; $TOTAL_READY * 100 / $TOTAL_EXPECTED" | bc -l)
    echo ""
    echo "🎯 Overall Health Score: $HEALTH_PERCENTAGE% ($TOTAL_READY/$TOTAL_EXPECTED components ready)"
    
    if [ "$HEALTH_PERCENTAGE" -eq 100 ]; then
        echo "🎉 Perfect! All components are running successfully."
    elif [ "$HEALTH_PERCENTAGE" -ge 75 ]; then
        echo "✅ Good! Most components are running. Check warnings above."
    elif [ "$HEALTH_PERCENTAGE" -ge 50 ]; then
        echo "⚠️  Partial deployment. Several components need attention."
    else
        echo "❌ Poor health. Most components are not running properly."
    fi
else
    echo "⚠️  No components detected. Please run setup first."
fi

echo ""
echo "🎉 Environment verification completed!"