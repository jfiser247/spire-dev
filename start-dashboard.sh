#!/bin/bash

# Start the SPIRE Dashboard with real-time pod data
# This script starts a simple HTTP server that serves the dashboard
# and provides an API endpoint for fetching real pod data

echo "Starting SPIRE Dashboard Server..."
echo "==========================================="

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js to run the dashboard server."
    echo "   You can download it from: https://nodejs.org/"
    exit 1
fi

# Check if required kubectl contexts are available
echo "🔍 Checking kubectl contexts..."
if ! kubectl config get-contexts | grep -q "spire-server-cluster"; then
    echo "⚠️  spire-server-cluster context not found"
fi

if ! kubectl config get-contexts | grep -q "workload-cluster"; then
    echo "⚠️  workload-cluster context not found"
fi

# Start the server
echo "🚀 Starting dashboard server on http://localhost:3000"
echo ""
echo "Available endpoints:"
echo "  • Dashboard: http://localhost:3000/web-dashboard.html"
echo "  • API: http://localhost:3000/api/pod-data"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

node server.js