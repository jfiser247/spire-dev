# Documentation Setup

This project uses Jekyll for documentation instead of MkDocs. The documentation is automatically built and deployed via GitHub Pages.

## Local Development

### Prerequisites
- Ruby (3.1+)
- Bundler gem

### Setup
```bash
# Install dependencies
bundle install

# Start local server
./scripts/start-jekyll-server.sh
```

The documentation will be available at: **http://localhost:4000**

## GitHub Pages Deployment

Documentation is automatically deployed to GitHub Pages when changes are pushed to the main branch.

**Live site**: https://jfiser247.github.io/spire-dev

### How it works
1. GitHub Actions workflow (`.github/workflows/jekyll.yml`) automatically builds the site
2. Jekyll converts markdown files in `_pages/` to HTML
3. Site is deployed to GitHub Pages
4. Navigation is generated from `_config.yml` configuration

## File Structure

```
├── _config.yml              # Jekyll configuration
├── _layouts/                # HTML templates
├── _includes/               # Reusable components
├── _pages/                  # Documentation pages
├── index.md                 # Homepage
├── Gemfile                  # Ruby dependencies
└── .github/workflows/       # GitHub Actions
```

## Adding Documentation

1. Create new `.md` file in `_pages/`
2. Add front matter:
   ```yaml
   ---
   layout: page
   title: Your Page Title
   permalink: /your-url-path/
   ---
   ```
3. Write content in Markdown
4. Update navigation in `_config.yml` if needed

## Migration from MkDocs

- Removed: `mkdocs.yml`, `docs-mkdocs/`, `site/`
- Added: Jekyll configuration and pages
- Updated: Dashboard links to use Jekyll URLs
- Scripts: Created `start-jekyll-server.sh`

## Benefits

- ✅ **GitHub Pages integration** - Automatic deployment
- ✅ **No MkDocs dependencies** - Simpler setup
- ✅ **GitHub-native** - Better integration with repository
- ✅ **Custom themes** - Easy to customize
- ✅ **Fast builds** - Incremental building