# SPIRE Enterprise Documentation

Welcome to the comprehensive SPIFFE/SPIRE enterprise deployment documentation. This guide provides everything you need to deploy, configure, and operate SPIRE in enterprise environments.

## 🚀 Quick Navigation

<div class="grid cards" markdown>

-   :fontawesome-solid-rocket:{ .lg .middle } **Quick Start**

    ---

    Get up and running with SPIRE in minutes with our one-command setup.

    [:octicons-arrow-right-24: Getting Started](getting-started.md)

-   :fontawesome-solid-building:{ .lg .middle } **Enterprise Architecture**

    ---

    Learn about upstream/downstream trust hierarchies and CRD-free deployments.

    [:octicons-arrow-right-24: Architecture Overview](architecture/overview.md)

-   :fontawesome-solid-gear:{ .lg .middle } **Deployment Guides**

    ---

    Step-by-step deployment guides for all environments and configurations.

    [:octicons-arrow-right-24: Deployment Guides](deployment/basic-development.md)

-   :fontawesome-solid-shield:{ .lg .middle } **Enterprise Features**

    ---

    CRD requirements, compliance, and enterprise-specific configurations.

    [:octicons-arrow-right-24: Enterprise Guide](enterprise/crd-requirements.md)

</div>

## 🏗️ Architecture Options

This project supports multiple SPIRE deployment architectures to meet different organizational requirements:

### :fontawesome-solid-laptop: Basic Development

Perfect for local development and testing:

```bash
./scripts/fresh-install.sh
```

- Single cluster deployment
- Quick setup (5-8 minutes)
- Local development focused
- Real-time dashboard included

### :fontawesome-solid-building: Enterprise Multi-Cluster

Production-ready upstream/downstream architecture:

```bash
./scripts/fresh-install.sh enterprise
```

- Hierarchical trust domains
- Federation between clusters
- Production-grade security
- HA database support

### :fontawesome-solid-lock: CRD-Free Enterprise

For organizations with strict CRD policies:

```bash
./scripts/fresh-install.sh crd-free
```

- No Custom Resource Definitions
- Namespace-scoped permissions only
- External SPIRE server integration
- Enterprise compliance ready

## 📊 Features

!!! success "Enterprise Ready"
    - **Multiple Deployment Options**: Basic, Enterprise, and CRD-free
    - **Real-time Dashboard**: Live monitoring with health indicators
    - **Federation Support**: Cross-domain trust management
    - **Compliance Ready**: SOX, PCI-DSS, FedRAMP compatible

!!! info "Development Friendly"
    - **One-Command Setup**: Complete environment in minutes
    - **Reproducible**: 100% consistent deployments
    - **Interactive Dashboard**: Click-through pod inspection
    - **Comprehensive Testing**: Built-in verification scripts

## 🔧 Quick Start Commands

| Deployment Type | Command | Use Case |
|----------------|---------|----------|
| **Basic** | `./scripts/fresh-install.sh` | Local development |
| **Enterprise** | `./scripts/fresh-install.sh enterprise` | Production with CRDs |
| **CRD-Free** | `./scripts/fresh-install.sh crd-free` | Restricted environments |

## 📖 Documentation Structure

This documentation is organized into the following sections:

- **[Architecture](architecture/overview.md)**: Design patterns and architectural decisions
- **[Deployment](deployment/basic-development.md)**: Step-by-step deployment guides
- **[Integration](integration/spiffe-service-integration.md)**: Service integration patterns
- **[Operations](operations/troubleshooting.md)**: Operational procedures and troubleshooting
- **[Enterprise](enterprise/crd-requirements.md)**: Enterprise-specific features and requirements

## 🌐 Dashboard Access

After deployment, access the interactive dashboard:

```bash
# Dashboard automatically starts
open http://localhost:3000/web-dashboard.html

# Documentation server (this site)
open http://localhost:8000
```

## 🤝 Contributing

This project demonstrates enterprise SPIRE deployment patterns. For contributions to the SPIRE project itself, see:

- [SPIRE GitHub Repository](https://github.com/spiffe/spire)
- [SPIFFE Documentation](https://spiffe.io/docs/)
- [Community Guidelines](https://github.com/spiffe/spire/blob/main/CONTRIBUTING.md)

---

!!! tip "Need Help?"
    - **Quick Issues**: Check the [Troubleshooting Guide](operations/troubleshooting.md)
    - **Architecture Questions**: See [Architecture Overview](architecture/overview.md)
    - **Enterprise Requirements**: Review [CRD Requirements](enterprise/crd-requirements.md)