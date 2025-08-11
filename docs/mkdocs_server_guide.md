# MkDocs Documentation Server Guide

## Overview

The SPIRE development environment includes a comprehensive documentation system built with [MkDocs](https://www.mkdocs.org/), a fast static site generator designed for project documentation. This guide covers how to use, navigate, and contribute to the documentation system.

## 🚀 Quick Start

### Starting the Documentation Server

**Option 1: Using the helper script (recommended)**
```bash
./scripts/start-docs-server.sh
```

**Option 2: Direct mkdocs command**
```bash
# From project root
mkdocs serve
```

**Option 3: From the dashboard**
- Open the SPIRE dashboard at `http://localhost:3000/web-dashboard.html`
- Click the **📚 Project Overview** or **📖 Documentation** tabs
- If mkdocs isn't running, you'll get helpful setup instructions

### Accessing Documentation

Once running, documentation is available at:
- **Main URL**: `http://localhost:8000`
- **Dashboard Integration**: Click doc tabs in SPIRE dashboard
- **Auto-reload**: Changes to markdown files automatically refresh the browser

## 📚 Documentation Structure

### Navigation Overview

The documentation is organized into logical sections accessible via the top navigation:

```
🏠 Home → 🚀 Getting Started → 🎓 Learning SPIRE → 🔧 Local Development → 🏢 Advanced Enterprise
```

### 🏠 Home Section

| Document | Description | Best For |
|----------|-------------|----------|
| `index.md` | Project overview and introduction | New users getting oriented |

### 🚀 Getting Started

| Document | Purpose | When to Use |
|----------|---------|-------------|
| `fresh_install_guide.md` | Complete setup walkthrough | First-time installation |
| `quick_start_workload_integration.md` | Fast workload integration | Developers adding SPIRE to existing services |
| `troubleshooting.md` | Common issues and solutions | When encountering problems |

### 🎓 Learning SPIRE

| Document | Focus Area | Target Audience |
|----------|------------|-----------------|
| `spiffe_service_integration_guide.md` | SPIFFE integration patterns | Service developers |
| `workload_integration_guide.md` | Workload identity implementation | Platform engineers |
| `architecture_diagrams.md` | System architecture visualization | Architects and tech leads |

### 🔧 Local Development

| Document | Covers | Use Case |
|----------|--------|----------|
| `project_structure.md` | Codebase organization | Contributors and maintainers |
| `architecture_validation.md` | Testing and validation | Quality assurance |
| `spire_security_policies.md` | Kubernetes security requirements | Platform administrators |
| `namespace_labeling_fix.md` | Namespace configuration | Deployment troubleshooting |
| `script_fixes_summary.md` | Installation script improvements | Maintenance and updates |

### 🏢 Advanced Enterprise

| Document | Enterprise Feature | Enterprise Audience |
|----------|-------------------|-------------------|
| `enterprise_architecture_diagram.md` | Production architecture | Enterprise architects |
| `enterprise_deployment_guide.md` | Production deployment | DevOps and SRE teams |
| `enterprise_workload_integration.md` | Enterprise integration patterns | Platform teams |
| `helm_deployment_guide.md` | Helm chart deployment | Kubernetes administrators |
| `enterprise_crd_requirements.md` | Custom resource requirements | Platform engineers |

## 🛠️ MkDocs Configuration

### Theme and Features

The documentation uses the **Material for MkDocs** theme with enhanced features:

```yaml
theme:
  name: material
  features:
    - navigation.tabs      # Top-level navigation tabs
    - navigation.sections  # Collapsible navigation sections
    - navigation.top       # Back-to-top button
    - navigation.tracking  # URL updates as you scroll
    - search.highlight     # Highlight search terms
    - search.share         # Share search results
    - content.code.copy    # Copy code blocks
    - content.code.annotate # Code annotations
```

### Enhanced Markdown Support

The documentation supports advanced markdown features:

- **Code syntax highlighting** with line numbers
- **Mermaid diagrams** for architecture visualization
- **Admonitions** for tips, warnings, and notes
- **Mathematical expressions** with MathJax
- **Tabbed content** for organized information
- **Emoji support** 🎉 for better visual communication

### Search Functionality

**Built-in search features:**
- Full-text search across all documents
- Instant results as you type
- Search term highlighting
- Keyboard shortcuts (`/` to focus search)

## 📝 Content Guidelines

### Document Structure

Each document follows consistent patterns:

```markdown
# Document Title

## Overview
Brief introduction to the topic

## Quick Start / Getting Started
Immediate actionable steps

## Detailed Sections
In-depth coverage of topics

## Examples
Practical code examples and use cases

## Troubleshooting
Common issues and solutions

## Advanced Topics
Complex scenarios and edge cases
```

### Content Types

**🔧 Technical Guides**
- Step-by-step instructions
- Code examples with explanations
- Configuration file samples
- Command-line references

**📊 Architecture Documentation**
- System diagrams (Mermaid)
- Component relationships
- Data flow explanations
- Security considerations

**🚨 Troubleshooting Guides**
- Problem descriptions
- Root cause analysis
- Solution steps
- Prevention strategies

**📋 Reference Materials**
- API documentation
- Configuration options
- Command references
- Best practices

## 🎯 Navigation Tips

### Using the Interface

**Top Navigation Tabs**
- Click main sections: Home, Getting Started, Learning, etc.
- Active section is highlighted
- Sub-navigation appears in left sidebar

**Left Sidebar Navigation**
- Hierarchical document structure
- Current page highlighted
- Click to jump between documents
- Collapsible sections for organization

**Search**
- Use the search box in the header
- Press `/` to focus search from anywhere
- Results show document context
- Click results to navigate directly

**Table of Contents**
- Right sidebar shows page outline
- Click headings to jump to sections
- Automatically updates as you scroll
- Hidden on smaller screens to save space

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `/` | Focus search |
| `Esc` | Clear search |
| `Tab` | Navigate search results |
| `Enter` | Open selected result |

## 🔧 Advanced Usage

### Local Development

**Live Reloading**
```bash
# Start with live reload (default)
mkdocs serve

# Specify custom port
mkdocs serve --dev-addr=0.0.0.0:8001

# Enable verbose output
mkdocs serve --verbose
```

**Building for Production**
```bash
# Generate static site
mkdocs build

# Clean previous builds
mkdocs build --clean

# Build to custom directory
mkdocs build --site-dir custom-site
```

### Customization

**Adding New Documents**
1. Create markdown file in `docs/` directory
2. Add to `mkdocs.yml` navigation structure
3. Use consistent naming convention
4. Follow content guidelines

**Configuration Changes**
```yaml
# mkdocs.yml
nav:
  - 🏠 Home: index.md
  - 🚀 Getting Started:
    - Your New Guide: your_new_guide.md
```

### Integration with Dashboard

The MkDocs server integrates seamlessly with the SPIRE dashboard:

**Automatic Detection**
- Dashboard checks if mkdocs is running on port 8000
- Shows helpful setup message if server is down
- Provides multiple access methods

**Navigation Integration**
- Documentation tabs in dashboard navigation
- Opens in new browser tab for parallel use
- Visual indicators for external links

## 📊 Document Statistics

### Content Metrics

```
📄 Total Documents: 15+
📝 Lines of Documentation: 2000+
🎯 Coverage Areas: 5 major sections
🔍 Search Index: Full-text searchable
🌐 Supported Formats: Markdown, HTML, PDF export
```

### Usage Analytics

**Common Access Patterns:**
1. **Getting Started** → Most accessed by new users
2. **Troubleshooting** → Frequently referenced during issues
3. **Architecture Diagrams** → Popular with technical leads
4. **Security Policies** → Essential for platform administrators
5. **Enterprise Guides** → Growing usage in production deployments

## 🚨 Troubleshooting

### Common Issues

**Port 8000 Already in Use**
```bash
# Find process using port 8000
lsof -i :8000

# Kill existing process
pkill -f mkdocs

# Or use different port
mkdocs serve --dev-addr=127.0.0.1:8001
```

**Documentation Not Loading**
```bash
# Check if mkdocs is installed
mkdocs --version

# Install if missing
pip install mkdocs mkdocs-material

# Verify configuration
mkdocs serve --verbose
```

**Search Not Working**
- Ensure JavaScript is enabled in browser
- Clear browser cache
- Check console for JavaScript errors
- Verify search plugin in mkdocs.yml

**Mermaid Diagrams Not Rendering**
- Check mermaid2 plugin installation: `pip install mkdocs-mermaid2-plugin`
- Verify plugin configuration in mkdocs.yml
- Ensure proper mermaid syntax in markdown

### Performance Issues

**Slow Loading**
- Check for large images in docs
- Optimize markdown file sizes
- Consider pagination for large documents

**Build Errors**
- Validate markdown syntax
- Check for broken internal links
- Verify all referenced files exist

## 🔄 Maintenance

### Regular Tasks

**Content Updates**
- Review and update outdated information
- Add new features and functionality
- Incorporate user feedback
- Fix broken links and references

**Performance Monitoring**
- Monitor page load times
- Check search functionality
- Validate mobile responsiveness
- Test cross-browser compatibility

**Version Management**
- Tag documentation versions with releases
- Maintain changelog for documentation updates
- Archive deprecated content appropriately

### Contributing

**Documentation Improvements**
1. Identify gaps or outdated content
2. Create or update markdown files
3. Test changes with local mkdocs server
4. Submit pull request with clear description

**Style Guidelines**
- Use consistent heading hierarchy
- Include practical examples
- Add code snippets with proper syntax highlighting
- Use admonitions for important notes

---

## 📞 Support

**Getting Help**
- Check existing documentation first
- Search for similar issues
- Review troubleshooting guides
- Create issues for documentation gaps

**Contributing**
- Documentation improvements welcome
- Follow existing style and structure
- Test changes locally before submitting
- Provide clear commit messages

**Community**
- Join SPIFFE community discussions
- Share documentation feedback
- Suggest new topics and improvements
- Help others navigate the documentation

---

**Last Updated**: This guide is maintained alongside the SPIRE development environment and is updated with each release to reflect the latest features and best practices.