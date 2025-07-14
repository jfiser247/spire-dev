# SPIRE Development Project - Claude Documentation

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

## Documentation Preferences

### Code Style
- Use enterprise-grade naming conventions (avoid generic service1/2/3)
- Follow SPIFFE ID format: `spiffe://example.org/workload/service-name`
- Prefer descriptive service names that reflect business purpose
- Use consistent indentation and formatting

### Documentation Standards
- Always include real examples instead of placeholder text
- Use realistic enterprise service scenarios
- Provide complete configuration examples
- Include troubleshooting sections for common issues

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