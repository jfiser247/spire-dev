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

1. **[Quick Start Workload Integration](quick_start_workload_integration.md)** - Get your first workloads talking with SPIFFE identities
2. **[Fresh Install Script](script_fixes_summary.md)** - One command to set up everything locally
3. **[Troubleshooting Guide](troubleshooting.md)** - Solutions to common learning hurdles

## 🎓 Learning Path

### Beginner - Understanding SPIRE
- [SPIFFE Service Integration Guide](spiffe_service_integration_guide.md) - Learn how services get SPIFFE identities
- [Workload Integration Guide](workload_integration_guide.md) - Hands-on workload integration
- [Architecture Diagrams](architecture_diagrams.md) - Visual understanding of SPIRE components

### Intermediate - Local Development
- [Project Structure](project_structure.md) - Navigate the codebase and scripts
- [Architecture Validation](architecture_validation.md) - Verify your local setup
- [Namespace Labeling Fix](namespace_labeling_fix.md) - Understanding Kubernetes integration

## 🏢 Advanced: Enterprise Concepts

Once you're comfortable with SPIRE basics, explore enterprise patterns:

- [Enterprise Architecture](enterprise_architecture_diagram.md) - Multi-cluster and production patterns
- [Enterprise Deployment Guide](enterprise_deployment_guide.md) - Production deployment strategies
- [Helm Deployment Guide](helm_deployment_guide.md) - GitOps-ready deployments
- [Enterprise CRD Requirements](enterprise_crd_requirements.md) - Kubernetes operator patterns

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