#!/bin/bash

# Start MkDocs development server for SPIRE documentation

set -e

echo "🚀 Starting MkDocs documentation server..."

# Check if we're in the right directory
if [[ ! -f "mkdocs.yml" ]]; then
    echo "❌ Error: mkdocs.yml not found. Please run this script from the repository root."
    exit 1
fi

# Function to check if Python 3 is available
check_python() {
    if command -v python3 &> /dev/null; then
        return 0
    elif command -v python &> /dev/null && python --version 2>&1 | grep -q "Python 3"; then
        return 0
    else
        return 1
    fi
}

# Check if Python 3 is installed
if ! check_python; then
    echo "❌ Error: Python 3 is not installed. Please install Python 3 first."
    echo "   macOS: brew install python"
    echo "   Ubuntu: sudo apt-get install python3 python3-pip python3-venv"
    exit 1
fi

# Create virtual environment in docs directory if it doesn't exist
VENV_DIR="docs/venv"
if [[ ! -d "$VENV_DIR" ]]; then
    echo "📦 Creating virtual environment for MkDocs..."
    mkdir -p docs
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Check if MkDocs and dependencies are installed
if ! pip list | grep -q mkdocs-material; then
    echo "📥 Installing MkDocs and dependencies..."
    pip install --upgrade pip
    pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin
else
    echo "✅ MkDocs dependencies found"
fi

# Start MkDocs server
echo "🌐 Starting MkDocs server..."
echo "📖 Documentation will be available at: http://localhost:8000"
echo "🔄 Server will auto-reload when files change"
echo "⏹️  Press Ctrl+C to stop the server"
echo ""

# Start with live reload and custom address
mkdocs serve --dev-addr=0.0.0.0:8000