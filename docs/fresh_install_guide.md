# Fresh Install Setup Guide

Get your local SPIRE development environment up and running in minutes! This guide walks you through the complete setup process from scratch.

## What You'll Get

After running the fresh install, you'll have:

- 🔧 **Complete SPIRE setup** - Server, agents, and database all configured
- 🖥️ **Real-time dashboard** - Visual monitoring of your SPIRE deployment  
- 🧪 **Example workloads** - Three demo services to experiment with
- 📊 **Monitoring tools** - Health checks and status indicators
- 🚀 **Ready to code** - Everything needed to start integrating your own services

## Prerequisites

### System Requirements
- **macOS** (tested on macOS 10.15+)
- **8GB RAM minimum** (16GB recommended)
- **10GB free disk space**
- **Docker Desktop** running
- **Terminal/Command line** access

### Required Tools
The script will check for these and help you install missing ones:

- `minikube` - Local Kubernetes cluster
- `kubectl` - Kubernetes command-line tool
- `helm` (optional) - Package manager for Kubernetes

## Step 1: Get the Code

Clone the repository and navigate to the project:

```bash
git clone https://github.com/spiffe/spire-dev.git
cd spire-dev
```

## Step 2: Run the Fresh Install

Execute the fresh install script:

```bash
./scripts/fresh-install.sh
```

The script will guide you through the entire process with clear status updates.

## What Happens During Install

### 🏗️ Infrastructure Setup (1-2 minutes)
- Creates a new minikube cluster
- Configures networking and resource limits
- Sets up Kubernetes namespaces

### 🔐 SPIRE Server Setup (2-3 minutes)
- Deploys MySQL database
- Configures and starts SPIRE server
- Sets up initial trust domain and policies

### 🤖 SPIRE Agent Setup (1-2 minutes)  
- Deploys SPIRE agents to all nodes
- Configures workload attestation
- Establishes secure communication with server

### 👥 Example Workloads (1-2 minutes)
- Deploys three demo services:
  - **User Service** - User authentication and profiles
  - **Payment API** - Payment processing service
  - **Inventory Service** - Product inventory management
- Configures inter-service communication
- Registers all workloads with SPIRE

### 📊 Dashboard Setup (30 seconds)
- Starts real-time monitoring dashboard
- Configures health indicators
- Opens browser to dashboard interface

**Total Time: 5-8 minutes**

## Step 3: Verify Installation

### Check Cluster Health
```bash
# Check all pods are running
kubectl get pods --all-namespaces

# Verify SPIRE server is healthy
kubectl get pods -n spire-server -l app=spire-server

# Check SPIRE agents
kubectl get pods -n spire-system -l app=spire-agent
```

### View Example Workloads
```bash
# Check demo services
kubectl get pods -n production

# View service endpoints
kubectl get services -n production
```

### Access the Dashboard
The fresh install automatically opens the dashboard at:
**http://localhost:3000**

If it doesn't open automatically:
```bash
./web/start-dashboard.sh
open http://localhost:3000
```

## Step 4: Explore Your Environment

### View SPIRE Registrations
```bash
# List all registered workloads
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show

# Check specific workload
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/user-service
```

### Test Service Communication
```bash
# Test user service
kubectl port-forward -n production service/user-service 8081:80 &
curl http://localhost:8081/health

# Test payment API
kubectl port-forward -n production service/payment-api 8082:80 &  
curl http://localhost:8082/health

# Clean up port forwards
pkill -f "kubectl port-forward"
```

### View Service Logs
```bash
# Check user service logs
kubectl logs -n production -l app=user-service

# Follow payment API logs
kubectl logs -n production -l app=payment-api -f

# View SPIRE agent logs
kubectl logs -n spire-system -l app=spire-agent
```

## Understanding the Setup

### Architecture Overview
Your local environment includes:

- **SPIRE Server** - Central identity provider
- **MySQL** - Identity registry database
- **SPIRE Agents** - Workload identity attestation (runs on each node)
- **Demo Services** - Example applications with SPIFFE integration

### Trust Domain
- **Domain**: `example.org`
- **Purpose**: Local development and testing
- **Scope**: Single minikube cluster

### Network Configuration
- **Cluster**: minikube (usually 192.168.49.x)
- **Dashboard**: localhost:3000
- **Services**: Available via kubectl port-forward

## Next Steps

🎯 **Now that your environment is ready:**

1. **Try the Quick Start** - [Integrate your first workload](quick_start_workload_integration.md)
2. **Understand the Architecture** - [Learn how components work together](architecture_diagrams.md)
3. **Explore Code Examples** - Check out the demo services in the `examples/` directory
4. **Register New Workloads** - Use `./scripts/register-workload.sh` to add services

## Common Setup Issues

### 🚨 "minikube not found"
**Solution**: Install minikube:
```bash
# macOS with Homebrew
brew install minikube

# Or download directly
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

### 🚨 "Docker not running"
**Solution**: Start Docker Desktop and wait for it to be ready

### 🚨 "Insufficient resources"
**Solution**: Adjust minikube settings:
```bash
minikube config set memory 4096
minikube config set cpus 2
minikube delete && minikube start
```

### 🚨 "Pods stuck in Pending"
**Solution**: Check resource allocation:
```bash
kubectl describe pod -n spire-server -l app=spire-server
minikube addons enable metrics-server
kubectl top nodes
```

### 🚨 "Dashboard won't open"
**Solution**: Check port availability:
```bash
lsof -i :3000  # Check if port is in use
./web/start-dashboard.sh  # Restart dashboard
```

## Clean Up and Reset

### Restart Fresh Install
```bash
# Clean up everything and start over
./scripts/fresh-install.sh
# The script automatically cleans up previous installations
```

### Manual Cleanup
```bash
# Stop dashboard
pkill -f "node.*dashboard"

# Delete cluster
minikube delete

# Clean up any remaining processes
pkill -f "kubectl port-forward"
```

## Troubleshooting

For detailed troubleshooting help, see:
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Script Fixes Summary](script_fixes_summary.md)** - Known issues and their fixes

## Advanced Options

### Custom Configuration
```bash
# Use different cluster name
CLUSTER_NAME=spire-test ./scripts/fresh-install.sh

# Skip dashboard startup  
SKIP_DASHBOARD=true ./scripts/fresh-install.sh

# Use different trust domain
TRUST_DOMAIN=dev.mycompany.com ./scripts/fresh-install.sh
```

### Development Mode
```bash
# Keep existing cluster if healthy
REUSE_CLUSTER=true ./scripts/fresh-install.sh

# Enable debug logging
DEBUG=true ./scripts/fresh-install.sh
```

## Support

**Need help?**
- Check the [Troubleshooting Guide](troubleshooting.md) for common issues
- Review the [Architecture Diagrams](architecture_diagrams.md) to understand component relationships
- Look at working examples in the `examples/` directory
- Join the [SPIFFE Community](https://spiffe.io/community/) for support