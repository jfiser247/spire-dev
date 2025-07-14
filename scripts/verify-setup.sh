#!/bin/bash
set -e

echo "Verifying SPIRE server setup..."
kubectl --context spire-server-cluster -n spire-server get pods
echo ""

echo "Verifying SPIRE agent setup..."
kubectl --context workload-cluster -n spire-system get pods
echo ""

echo "Verifying workload services..."
kubectl --context workload-cluster -n production get pods
echo ""

echo "Checking SPIRE registration entries..."
SERVER_POD=$(kubectl --context spire-server-cluster -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire-server exec $SERVER_POD -- /opt/spire/bin/spire-server entry show
echo ""

echo "Verifying SPIFFE ID for user-service..."
USER_SERVICE_POD=$(kubectl --context workload-cluster -n production get pod -l app=user-service -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n production exec $USER_SERVICE_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "Verifying SPIFFE ID for payment-api..."
PAYMENT_API_POD=$(kubectl --context workload-cluster -n production get pod -l app=payment-api -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n production exec $PAYMENT_API_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "Verifying SPIFFE ID for inventory-service..."
INVENTORY_SERVICE_POD=$(kubectl --context workload-cluster -n production get pod -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n production exec $INVENTORY_SERVICE_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "🌐 Verifying Dashboard Server..."
echo "Testing dashboard server status..."

# Check if dashboard is running
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Dashboard server: running on http://localhost:3000"
    
    # Test API endpoint for real data
    echo "Testing dashboard API for real data..."
    
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
    
    echo ""
    echo "🎉 Dashboard verification completed!"
    echo "   📊 Dashboard URL: http://localhost:3000/web-dashboard.html"
    echo "   🌐 Open in browser: open http://localhost:3000/web-dashboard.html"
    
else
    echo "⚠️  Dashboard server: not running"
    echo "   💡 Start dashboard: ./web/start-dashboard.sh"
fi

echo ""
echo "🎉 Environment verification completed!"