---
layout: default
title: Home
permalink: /
---

# SPIRE Local Development Environment

Welcome to the **SPIRE Local Development Environment** - your gateway to learning and experimenting with SPIFFE/SPIRE identity infrastructure! 

## 🎯 What is this project?

This project is designed to help you **learn, test, and experiment** with SPIFFE/SPIRE on your local machine. Whether you're new to zero-trust identity concepts or want to understand how SPIRE works in practice, this environment provides:

- 📚 **Learning-focused setup** - Perfect for understanding SPIFFE/SPIRE concepts
- 🧪 **Local testing environment** - Safe sandbox for experimentation
- 🔧 **Development workflow** - Rapid iteration and testing
- 📖 **Educational examples** - Real workload integration scenarios

## 🚀 Get Started in Minutes

The fastest way to start learning SPIRE:

1. **[Quick Start Workload Integration]({{ "/quick-start-workload-integration/" | relative_url }})** - Get your first workloads talking with SPIFFE identities
2. **[Fresh Install Setup]({{ "/fresh-install-guide/" | relative_url }})** - One command to set up everything locally
3. **[Troubleshooting Guide]({{ "/troubleshooting/" | relative_url }})** - Solutions to common learning hurdles

## 🎓 Learning Path

### Beginner - Understanding SPIRE
- [SPIFFE Service Integration Guide]({{ "/spiffe-service-integration/" | relative_url }}) - Learn how services get SPIFFE identities
- [Workload Integration Guide]({{ "/workload-integration/" | relative_url }}) - Hands-on workload integration
- [Architecture Diagrams]({{ "/architecture-diagrams/" | relative_url }}) - Visual understanding of SPIRE components

### Intermediate - Local Development
- [Project Structure]({{ "/project-structure/" | relative_url }}) - Navigate the codebase and scripts
- [Architecture Validation]({{ "/architecture-validation/" | relative_url }}) - Verify your local setup
- [Security Policy Requirements]({{ "/security-policies/" | relative_url }}) - Understanding security policies

## 🏢 Advanced: Enterprise Concepts

Once you're comfortable with SPIRE basics, explore enterprise patterns:

- [Enterprise Architecture]({{ "/enterprise-architecture/" | relative_url }}) - Multi-cluster and production patterns
- [Enterprise Deployment Guide]({{ "/enterprise-deployment/" | relative_url }}) - Production deployment strategies
- [Helm Deployment Guide]({{ "/helm-deployment/" | relative_url }}) - GitOps-ready deployments
- [Enterprise CRD Requirements]({{ "/enterprise-crd-requirements/" | relative_url }}) - Kubernetes operator patterns

## 🛠️ Development Workflow

This environment supports rapid development and testing:

```bash
# Fresh setup - tears down everything and rebuilds
./scripts/fresh-install.sh

# Quick workload registration for testing
./scripts/register-workload.sh

# Validate your setup is working
./scripts/verify-setup.sh
```

## 💡 Perfect for...

- **Learning SPIFFE/SPIRE concepts** without complex infrastructure
- **Testing identity policies** and workload attestation
- **Prototyping zero-trust architectures** before production
- **Understanding mTLS and SVID rotation** in practice
- **Developing SPIRE integrations** with real examples

## 🎯 What you'll learn

By working through this environment, you'll understand:
- How SPIRE Servers and Agents work together
- Workload attestation and SVID issuance
- Service-to-service mTLS with automatic certificate rotation
- Kubernetes integration patterns
- Federation and trust domain concepts

## 📚 Resources for Learning

- [SPIFFE Official Website](https://spiffe.io) - Concepts and specifications
- [SPIRE GitHub Repository](https://github.com/spiffe/spire) - Source code and issues
- [SPIFFE Community](https://spiffe.io/community/) - Get help and share experiences

---

*This learning environment is designed for local development and testing. Ready to dive deeper into production patterns? Check out the Advanced section above!*