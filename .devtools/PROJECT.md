# SPIRE Development Project - AI Assistant Documentation

## Project Overview
This is a SPIFFE/SPIRE development project demonstrating multi-cluster identity management with Kubernetes. The project includes enterprise-grade service examples and comprehensive monitoring dashboards.

## Service Architecture
- **user-service**: User Management API (replaces generic service1)
- **payment-api**: Payment Processing API (replaces generic service2)  
- **inventory-service**: Inventory Management API (replaces generic service3)

## Key Components
- SPIRE Server Cluster (`spire-server-cluster` context)
- Workload Cluster (`workload-cluster` context)
- Real-time monitoring dashboard with live pod data
- Helm charts for multi-environment deployment
- PostgreSQL database with comprehensive policies

## Documentation Theme & Emphasis

### 🎯 **Primary Focus: SPIFFE/SPIRE Local Laptop Testing**
This project centers on **local development and testing of SPIFFE/SPIRE identity management** on macOS laptops using minikube/kind clusters. All documentation should emphasize:

- **Local-first approach**: Start with laptop testing, then scale to enterprise
- **Developer experience**: Easy setup, clear testing steps, quick iteration
- **Multi-cluster simulation**: Two local clusters representing real enterprise topology
- **Enterprise readiness**: Every local example shows the path to production deployment

### 📋 Documentation Standards

#### **Structure Every Guide With:**
1. **Local Setup** - Laptop/minikube implementation first
2. **Testing & Validation** - How to verify it works locally  
3. **Enterprise Extension** - How to adapt for production Kubernetes clusters
4. **Scaling Considerations** - Multi-region, HA, security hardening

#### **Writing Style:**
- **Practical examples**: Real commands that work on local clusters
- **Enterprise context**: Always explain "In production, you would..."
- **Security focus**: Highlight identity management best practices
- **Troubleshooting**: Common local issues and production gotchas

#### **Code & Configuration:**
- Use enterprise-grade naming conventions (avoid generic service1/2/3)
- Follow SPIFFE ID format: `spiffe://example.org/workload/service-name`
- Show both local and production-ready configurations
- Include resource limits, security contexts, and monitoring

### Development Workflow
- Test changes across both clusters (server and workload)
- Verify dashboard shows real pod data, not mock data
- Update Helm values for all environments (dev, prod)
- Always check kubectl contexts before making changes

## Important Context
- This project was recently updated to use enterprise service names throughout
- The web dashboard now pulls real-time data from Kubernetes APIs
- All generic service references have been replaced with meaningful names
- Kubernetes contexts: `spire-server-cluster` and `workload-cluster`

## Tools and Scripts
- `./start-dashboard.sh`: Launch real-time monitoring dashboard
- `./scripts/get-pod-data.sh`: Fetch live pod data from clusters
- `./scripts/setup-clusters.sh`: Initialize SPIRE infrastructure
- `./scripts/verify-setup.sh`: Validate deployment status

## Recent Changes
- Updated all service names to enterprise standards
- Implemented real-time pod data integration
- Enhanced dashboard with live cluster information
- Created comprehensive Helm chart configurations