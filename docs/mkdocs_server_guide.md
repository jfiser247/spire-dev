# MkDocs Server Guide

This guide explains how to run the documentation server locally for development and testing.

## Quick Start

```bash
# Start the documentation server
./scripts/start-docs-server.sh
```

The documentation will be available at: **http://localhost:8000**

## What the Script Does

The `start-docs-server.sh` script automatically:

1. **Checks Dependencies** - Verifies Python 3 is installed
2. **Creates Virtual Environment** - Sets up isolated Python environment in `docs/venv/`
3. **Installs MkDocs** - Installs MkDocs Material theme and Mermaid plugin
4. **Starts Server** - Launches development server with live reload

## Manual Setup

If you prefer to set up MkDocs manually:

```bash
# Create virtual environment
python3 -m venv docs/venv
source docs/venv/bin/activate

# Install dependencies
pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin

# Start server
mkdocs serve --dev-addr=0.0.0.0:8000
```

## Features

- **Live Reload** - Changes automatically refresh in browser
- **Material Theme** - Modern, responsive documentation theme
- **Mermaid Diagrams** - Support for architectural diagrams
- **Search** - Full-text search across documentation
- **Navigation** - Organized sections with emoji indicators

## Troubleshooting

### Python Not Found
```bash
# macOS
brew install python

# Ubuntu/Debian
sudo apt-get install python3 python3-pip python3-venv
```

### Port Already in Use
```bash
# Check what's using port 8000
lsof -i :8000

# Kill existing MkDocs processes
pkill -f "mkdocs serve"

# Use different port
mkdocs serve --dev-addr=0.0.0.0:8001
```

### Permission Errors
```bash
# Make script executable
chmod +x scripts/start-docs-server.sh

# Fix virtual environment permissions
rm -rf docs/venv
python3 -m venv docs/venv
```

## Development Workflow

1. **Start Server**: `./scripts/start-docs-server.sh`
2. **Edit Documentation**: Modify `.md` files in `docs/`
3. **Preview Changes**: Browser automatically refreshes
4. **Stop Server**: Press `Ctrl+C`

## Configuration

Documentation configuration is in `mkdocs.yml`:

- **Site settings**: Title, description, URL
- **Theme**: Material theme with dark/light toggle
- **Navigation**: Organized menu structure
- **Plugins**: Search and Mermaid diagram support
- **Extensions**: Code highlighting, admonitions, etc.

## Adding New Pages

1. Create `.md` file in `docs/` directory
2. Add to navigation in `mkdocs.yml`:
   ```yaml
   nav:
     - Section Name:
       - Page Title: filename.md
   ```
3. Server automatically detects changes

## Building Static Site

```bash
# Build static site for deployment
mkdocs build

# Output will be in site/ directory
ls site/
```