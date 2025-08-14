# GitHub Pages Documentation Setup

This repository automatically deploys MkDocs documentation to GitHub Pages using GitHub Actions.

## 🌐 Live Documentation

**Documentation Site**: https://jfiser247.github.io/spire-dev

## 🔄 Automatic Deployment

The documentation is automatically built and deployed when:
- Changes are pushed to the `main` branch
- Files in `docs/` directory are modified
- `mkdocs.yml` configuration is updated
- Workflow file is changed

## 📁 Repository Structure

```
├── .github/workflows/
│   └── deploy-mkdocs.yml    # GitHub Actions workflow
├── docs/                    # Documentation source files
├── mkdocs.yml              # MkDocs configuration
├── requirements.txt        # Python dependencies
└── scripts/
    └── start-docs-server.sh # Local development server
```

## 🛠️ How It Works

1. **Trigger**: Push to `main` branch with documentation changes
2. **Build**: GitHub Actions runs MkDocs build with Material theme
3. **Deploy**: Built site is pushed to `gh-pages` branch
4. **Serve**: GitHub Pages serves from `gh-pages` branch

## 🔧 GitHub Pages Configuration

**Repository Settings → Pages:**
- **Source**: Deploy from a branch
- **Branch**: `gh-pages`
- **Folder**: `/ (root)`

## 🏠 Local Development

Run documentation locally:
```bash
./scripts/start-docs-server.sh
```
Available at: http://localhost:8000

## ⚙️ Workflow Features

- **Smart Triggering**: Only runs on documentation changes
- **Caching**: pip dependencies cached for faster builds
- **Force Deploy**: Uses `force_orphan` for clean gh-pages history
- **Verbose Output**: Build logs for debugging
- **Commit Attribution**: Proper bot user for automated commits

## 📝 Adding Documentation

1. Create/edit `.md` files in `docs/` directory
2. Update navigation in `mkdocs.yml` if needed
3. Commit and push to `main` branch
4. GitHub Actions automatically deploys within 2-3 minutes

## 🐛 Troubleshooting

### Build Failures
Check the Actions tab: https://github.com/jfiser247/spire-dev/actions

### Local Testing
```bash
# Test build locally
mkdocs build

# Check for broken links
mkdocs build --verbose
```

### Dependencies
Update `requirements.txt` for new MkDocs plugins or themes.