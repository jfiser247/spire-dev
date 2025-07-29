#!/bin/bash

# SPIRE Documentation Server Startup Script
# Starts MkDocs documentation server alongside the dashboard

set -e

echo "📚 Starting SPIRE Documentation Server"
echo "======================================="

# Check if MkDocs is installed
if ! command -v mkdocs &> /dev/null; then
    echo "❌ MkDocs not found. Installing MkDocs..."
    pip3 install mkdocs mkdocs-material mkdocs-mermaid2-plugin
fi

# Check if documentation server is already running
if lsof -i :8000 >/dev/null 2>&1; then
    echo "⚠️  Port 8000 is already in use"
    echo "🔍 Checking for existing documentation server..."
    
    if pgrep -f "mkdocs serve" >/dev/null 2>&1; then
        echo "✅ Documentation server is already running"
        echo "📚 Documentation URL: http://localhost:8000"
        exit 0
    else
        echo "❌ Port 8000 is occupied by another process"
        echo "🔧 Please free port 8000 or kill the conflicting process"
        lsof -i :8000
        exit 1
    fi
fi

# Navigate to project root
cd "$(dirname "$0")/.."

echo "🚀 Starting MkDocs documentation server..."
echo "   📋 Features: Material Design theme, Mermaid diagrams, search"
echo "   🔗 Integrated with dashboard via http://localhost:3000"

# Start MkDocs server in background
mkdocs serve --dev-addr=0.0.0.0:8000 &
DOCS_PID=$!

echo "📚 Documentation server started (PID: $DOCS_PID)"

# Wait for server to start
sleep 3

# Test if server is responding
if curl -s http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Documentation server is running successfully"
    echo ""
    echo "📚 Documentation Access:"
    echo "   📊 URL: http://localhost:8000"
    echo "   🖥️  Command: open http://localhost:8000"
    echo ""
    echo "🔗 Integration Points:"
    echo "   🌐 Dashboard: http://localhost:3000/web-dashboard.html"
    echo "   📖 Docs Button: Available in dashboard header"
    echo "   🔄 Live Reload: Documentation updates automatically"
    echo ""
    echo "📁 Documentation Structure:"
    echo "   📋 Getting Started: Quick setup guides"
    echo "   🏗️  Architecture: Design patterns and diagrams"
    echo "   🚀 Deployment: Step-by-step deployment guides"
    echo "   🏢 Enterprise: CRD requirements and compliance"
    echo "   🔧 Operations: Troubleshooting and maintenance"
    echo ""
    echo "📝 MkDocs Features:"
    echo "   🎨 Material Design theme with dark/light mode"
    echo "   🔍 Full-text search across all documentation"
    echo "   📊 Mermaid diagram rendering"
    echo "   📱 Mobile-responsive design"
    echo "   🔗 Cross-references and navigation"
    echo ""
    echo "🔄 Development Workflow:"
    echo "   📝 Edit files in docs-mkdocs/ directory"
    echo "   🔄 Changes auto-reload at http://localhost:8000"
    echo "   🛑 Stop server: pkill -f 'mkdocs serve'"
    echo ""
    echo "🎉 Documentation server ready!"
else
    echo "❌ Documentation server failed to start properly"
    echo "🔍 Troubleshooting:"
    echo "   1. Check if port 8000 is available: lsof -i :8000"
    echo "   2. Verify MkDocs installation: mkdocs --version"
    echo "   3. Check mkdocs.yml configuration"
    kill $DOCS_PID 2>/dev/null || true
    exit 1
fi