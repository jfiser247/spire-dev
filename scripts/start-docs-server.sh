#!/bin/bash

# SPIRE Documentation Server Startup Script
# Starts MkDocs documentation server alongside the dashboard

set -e

echo "📚 Starting SPIRE Documentation Server"
echo "======================================="

# Check if MkDocs is available (global or virtual environment)
MKDOCS_CMD=""

# Check if we have a virtual environment with mkdocs
if [ -d "venv-docs" ] && [ -f "venv-docs/bin/activate" ]; then
    source venv-docs/bin/activate 2>/dev/null || true
    if command -v mkdocs &> /dev/null; then
        MKDOCS_CMD="mkdocs"
        echo "✅ Using MkDocs from virtual environment"
    fi
# Check for system mkdocs
elif command -v mkdocs &> /dev/null; then
    MKDOCS_CMD="mkdocs"
    echo "✅ Using system MkDocs installation"
fi

# If no mkdocs found, create virtual environment and install
if [ -z "$MKDOCS_CMD" ]; then
    echo "⚠️  MkDocs not found. Setting up virtual environment..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv-docs" ]; then
        echo "🔧 Creating virtual environment for documentation..."
        python3 -m venv venv-docs || {
            echo "❌ Failed to create virtual environment"
            echo "ℹ️  Please install Python 3.7+ and try again"
            exit 1
        }
    fi
    
    # Activate and install dependencies
    source venv-docs/bin/activate || {
        echo "❌ Failed to activate virtual environment"
        exit 1
    }
    
    echo "📦 Installing MkDocs and dependencies..."
    pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin pymdown-extensions || {
        echo "❌ Failed to install MkDocs dependencies"
        echo "ℹ️  Check your internet connection and try again"
        deactivate 2>/dev/null || true
        exit 1
    }
    
    MKDOCS_CMD="mkdocs"
    echo "✅ MkDocs installed successfully in virtual environment"
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