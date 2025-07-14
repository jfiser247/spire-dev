# SPIFFE/SPIRE Fresh Mac Laptop Troubleshooting Guide

**🍎 When in doubt, start fresh!**

This guide helps you troubleshoot common issues with your SPIFFE/SPIRE Mac laptop development environment. The **#1 recommended solution** for most issues is running the fresh install script.

## 🚀 Quick Fix: Fresh Install

**For 90% of issues, this solves everything:**
```bash
./fresh-install.sh
```

This completely tears down and rebuilds your environment as if you just got a new MacBook.

## 🔧 Common Issues and Solutions

### 1. **"Clusters won't start" or "minikube errors"**

**Symptoms:**
- `minikube start` fails
- Cluster creation hangs
- Docker driver issues

**Fresh Mac Solution:**
```bash
./fresh-install.sh
```

**Manual troubleshooting:**
```bash
# Check Docker is running
docker ps

# Reset minikube completely
minikube delete --all
minikube cache reload

# Restart Docker Desktop and try again
```

### 2. **"Dashboard shows mock data" or "API not responding"**

**Symptoms:**
- Dashboard shows yellow "Mock data" indicator
- Real pod data not loading
- API endpoint returns errors

**Fresh Mac Solution:**
```bash
./fresh-install.sh
```

**Manual verification:**
```bash
# Check if clusters are running
minikube profile list

# Verify kubectl contexts
kubectl config get-contexts

# Test API manually
curl http://localhost:3000/api/pod-data
```

### 3. **"SPIRE Agent not starting" or "Pod CrashLoopBackOff"**

**Symptoms:**
- SPIRE agent pods failing
- Workload services not getting SVIDs
- Trust bundle issues

**Fresh Mac Solution:**
```bash
./fresh-install.sh
```

**Manual debugging:**
```bash
# Check agent logs
kubectl --context workload-cluster -n spire logs -l app=spire-agent

# Verify server is reachable
kubectl --context spire-server-cluster -n spire get pods

# Check trust bundle
kubectl --context workload-cluster -n spire get configmap spire-bundle -o yaml
```

### 4. **"Environment feels slow or inconsistent"**

**Symptoms:**
- Pods taking long to start
- Inconsistent behavior
- Resource constraints

**Fresh Mac Solution:**
```bash
./fresh-install.sh
```

**Resource optimization:**
```bash
# Check Docker Desktop resources (8GB+ RAM recommended)
docker system info

# Clean up Docker
docker system prune -a

# Restart Docker Desktop
```

### 5. **"Port conflicts" or "Server won't start"**

**Symptoms:**
- Dashboard server fails to start
- Port 3000 already in use
- Node.js errors

**Fresh Mac Solution:**
```bash
./fresh-install.sh
```

**Manual port cleanup:**
```bash
# Find what's using port 3000
lsof -i :3000

# Kill any node processes
pkill -f "node server.js"

# Try starting dashboard again
./start-dashboard.sh
```

### 6. **"Git or repository issues"**

**Symptoms:**
- Git conflicts
- Missing scripts
- Permission errors

**Fresh Mac Solution:**
```bash
# Fresh clone from GitHub
cd ..
rm -rf spire-dev
git clone https://github.com/jfiser247/spire-dev.git
cd spire-dev
./fresh-install.sh
```

## 🍎 Fresh Mac Prerequisites

If the fresh install script reports missing tools:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all Mac laptop development tools
brew install minikube kubectl node jq

# Verify installation
minikube version
kubectl version --client
node --version
jq --version
```

## 🏢 Enterprise Environment Considerations

When adapting this for production:

**Development Environment:**
- Use `./fresh-install.sh` for consistent local development

**CI/CD Environment:**
- Adapt the teardown/setup logic for pipeline environments
- Use containerized builds instead of local minikube

**Production Deployment:**
- Never use fresh install scripts in production
- Use proper Helm charts and blue/green deployments
- Implement proper backup/restore procedures

## 📞 When Fresh Install Doesn't Work

If `./fresh-install.sh` doesn't solve your issue:

1. **Check Mac system requirements:**
   - macOS 10.14+ (Mojave or newer)
   - 8GB+ RAM available
   - Docker Desktop installed and running

2. **Verify Homebrew installation:**
   ```bash
   brew doctor
   ```

3. **Check disk space:**
   ```bash
   df -h
   ```

4. **Restart your Mac** (seriously, this helps with Docker issues)

5. **Create a GitHub issue** with:
   - Output of `./fresh-install.sh`
   - Your macOS version: `sw_vers`
   - Available resources: `docker system info`

## 🔄 Best Practices

1. **Start fresh daily** during active development
2. **Run fresh install** before demos or important tests
3. **Keep your Mac updated** for best Docker/minikube compatibility
4. **Monitor Docker Desktop resources** (increase if needed)
5. **Use the fresh install** when switching between different SPIRE configurations

Remember: **The fresh install approach ensures every developer has an identical, clean environment - just like getting a new MacBook!**