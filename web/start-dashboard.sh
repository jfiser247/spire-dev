#!/bin/bash

# SPIRE Dashboard Startup Script
# Automatically detects and supports both basic and enterprise deployments

set -e

echo "🌐 Starting SPIRE Dashboard Server"
echo "==================================="

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js to run the dashboard."
    echo "📖 Install with: brew install node"
    exit 1
fi

# Check if dashboard is already running
if lsof -i :3000 >/dev/null 2>&1; then
    echo "⚠️  Port 3000 is already in use"
    echo "🔍 Checking for existing dashboard processes..."
    
    # Check if it's our dashboard server
    if pgrep -f "node.*server.js" >/dev/null 2>&1 || pgrep -f "node.*enterprise-server.js" >/dev/null 2>&1; then
        echo "✅ Dashboard server is already running"
        echo "🌐 Dashboard URL: http://localhost:3000/web-dashboard.html"
        echo "🔄 To restart, kill the existing process first:"
        echo "   pkill -f 'node.*server.js'"
        echo "   pkill -f 'node.*enterprise-server.js'"
        exit 0
    else
        echo "❌ Port 3000 is occupied by another process"
        echo "🔧 Please free port 3000 or kill the conflicting process"
        lsof -i :3000
        exit 1
    fi
fi

# Navigate to the web directory
cd "$(dirname "$0")"

# Auto-detect deployment type for server selection
echo "🔍 Auto-detecting deployment type..."

DEPLOYMENT_TYPE="basic"
if kubectl config get-contexts --no-headers 2>/dev/null | grep -q "upstream-spire-cluster" && \
   kubectl config get-contexts --no-headers 2>/dev/null | grep -q "downstream-spire-cluster"; then
    DEPLOYMENT_TYPE="enterprise"
fi

echo "📊 Detected deployment: $DEPLOYMENT_TYPE"

# Start the appropriate server
if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
    echo "🏢 Starting enterprise dashboard server..."
    echo "   📋 Features: Multi-cluster support, upstream/downstream topology"
    echo "   🔗 Supports: upstream-spire-cluster, downstream-spire-cluster"
    node enterprise-server.js &
else
    echo "🔧 Starting basic development dashboard server..."
    echo "   📋 Features: Single workload cluster, development focused"
    echo "   🔗 Supports: workload-cluster contexts"
    node server.js &
fi

SERVER_PID=$!
echo "🚀 Dashboard server started (PID: $SERVER_PID)"

# Wait a moment for server to start
sleep 3

# Test if server is responding
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Dashboard server is running successfully"
    echo ""
    echo "🌐 Dashboard Access:"
    echo "   📊 URL: http://localhost:3000/web-dashboard.html"
    echo "   🖥️  Command: open http://localhost:3000/web-dashboard.html"
    echo ""
    echo "🔄 Server Management:"
    echo "   🛑 Stop server: pkill -f 'node.*server.js'"
    echo "   📋 View processes: ps aux | grep node"
    echo ""
    echo "🏢 Deployment Details:"
    echo "   📈 Type: $DEPLOYMENT_TYPE"
    if [ "$DEPLOYMENT_TYPE" = "enterprise" ]; then
        echo "   🔒 Upstream cluster: upstream-spire-cluster"
        echo "   🌐 Downstream cluster: downstream-spire-cluster"
    else
        echo "   🔧 Workload cluster: workload-cluster"
    fi
    echo ""
    echo "📊 Dashboard will auto-refresh every 30 seconds"
    echo "🎉 Ready for SPIRE operations!"
else
    echo "❌ Dashboard server failed to start properly"
    echo "🔍 Troubleshooting:"
    echo "   1. Check if port 3000 is available: lsof -i :3000"
    echo "   2. Check server logs: tail -f /tmp/dashboard.log"
    echo "   3. Verify kubectl contexts are configured"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi