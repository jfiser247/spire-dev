#!/bin/bash

# Start Jekyll development server for SPIRE documentation

set -e

echo "🚀 Starting Jekyll documentation server..."

# Check if we're in the right directory
if [[ ! -f "_config.yml" ]]; then
    echo "❌ Error: _config.yml not found. Please run this script from the repository root."
    exit 1
fi

# Check if Ruby and Bundler are installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Error: Ruby is not installed. Please install Ruby first."
    echo "   macOS: brew install ruby"
    echo "   Ubuntu: sudo apt-get install ruby-full"
    exit 1
fi

if ! command -v bundle &> /dev/null; then
    echo "❌ Error: Bundler is not installed. Installing..."
    gem install bundler
fi

# Install Jekyll dependencies if needed
if [[ ! -f "Gemfile.lock" ]] || [[ "Gemfile" -nt "Gemfile.lock" ]]; then
    echo "📦 Installing Jekyll dependencies..."
    bundle install
fi

# Start the Jekyll server
echo "🌐 Starting Jekyll server..."
echo "📖 Documentation will be available at: http://localhost:4000"
echo "🔄 Server will auto-reload when files change"
echo "⏹️  Press Ctrl+C to stop the server"
echo ""

# Use bundle exec to ensure we use the right gem versions
bundle exec jekyll serve --host=0.0.0.0 --port=4000 --livereload --incremental