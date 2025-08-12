# SPIRE Helm Deployment Guide

## 🎯 **Complete Guide for Deploying SPIRE with Helm**

This guide provides comprehensive instructions for deploying, managing, and upgrading SPIRE using Helm charts, replacing the manual Kubernetes manifest approach with a production-ready, templated solution.

---

## 📋 **Table of Contents**

1. [Benefits of Helm vs Manual Manifests](#benefits-of-helm-vs-manual-manifests)
2. [Migration from Manual Setup](#migration-from-manual-setup)
3. [Installation Procedures](#installation-procedures)
4. [Configuration Management](#configuration-management)
5. [Environment Management](#environment-management)
6. [Upgrade Procedures](#upgrade-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## 🚀 **Benefits of Helm vs Manual Manifests**

### **Current Manual Approach Issues**
- ❌ **No templating** - Hard-coded values across environments
- ❌ **Manual updates** - Error-prone configuration changes
- ❌ **No versioning** - Difficult to track and rollback changes
- ❌ **Environment drift** - Inconsistent configs across dev/staging/prod
- ❌ **Complex upgrades** - Manual coordination of multiple manifests

### **Helm Chart Advantages**
- ✅ **Templating** - Single source with environment-specific values
- ✅ **Version control** - Track, rollback, and manage releases
- ✅ **Dependencies** - Automatic MySQL deployment and management
- ✅ **Validation** - Built-in configuration validation
- ✅ **Atomic operations** - All-or-nothing deployments
- ✅ **Environment consistency** - Identical structure across environments

### **Comparison Table**

| Feature | Manual Manifests | Helm Charts |
|---------|------------------|-------------|
| **Deployment** | `kubectl apply -f` multiple files | `helm install` single command |
| **Updates** | Manual file editing | `helm upgrade` with new values |
| **Rollbacks** | Manual backup/restore | `helm rollback` single command |
| **Environment Management** | Separate manifest sets | Single chart + environment values |
| **Dependency Management** | Manual coordination | Automatic with dependencies |
| **Configuration Validation** | None | Built-in validation |
| **Status Tracking** | Manual checking | `helm status` comprehensive view |

---

## 🔄 **Migration from Manual Setup**

### **Pre-Migration Assessment**

First, analyze your current deployment:

```bash
# Document current state
kubectl get all -n spire -o yaml > current-spire-state.yaml
kubectl get configmaps -n spire -o yaml > current-configmaps.yaml
kubectl get secrets -n spire -o yaml > current-secrets.yaml

# Check resource usage
kubectl top pods -n spire
kubectl describe pvc -n spire
```

### **Migration Strategy Options**

#### **Option 1: Blue-Green Migration (Recommended)**

Deploy Helm chart alongside existing setup:

```bash
# 1. Deploy Helm chart in new namespace
helm install spire-new ./helm-charts/spire \
  --namespace spire-new \
  --create-namespace \
  --values migration-values.yaml

# 2. Verify new deployment
kubectl get pods -n spire-new
helm test spire-new -n spire-new

# 3. Migrate data (if needed)
kubectl exec -n spire spire-server-0 -- tar czf - /run/spire/data | \
kubectl exec -n spire-new spire-server-0 -i -- tar xzf - -C /

# 4. Update DNS/ingress to point to new deployment
# 5. Remove old deployment
kubectl delete namespace spire
```

#### **Option 2: In-Place Migration**

Replace existing resources with Helm:

```bash
# 1. Backup current state
kubectl get all -n spire -o yaml > backup-$(date +%Y%m%d).yaml

# 2. Delete existing resources (keeps PVCs)
kubectl delete deployment,statefulset,daemonset,service,configmap -n spire --all

# 3. Install Helm chart in same namespace
helm install spire ./helm-charts/spire \
  --namespace spire \
  --values migration-values.yaml

# 4. Verify data persistence
kubectl exec -n spire spire-server-0 -- ls -la /run/spire/data
```

### **Migration Values File**

Create `migration-values.yaml` matching your current setup:

```yaml
# migration-values.yaml
global:
  trustDomain: "example.org"  # Match your current domain
  clusterName: "spire-server-cluster"  # Match current cluster name

spireServer:
  image:
    tag: "1.6.3"  # Match your current version
  config:
    logLevel: "INFO"  # Match current log level
  persistence:
    size: "1Gi"  # Match current PVC size

spireAgent:
  image:
    tag: "1.6.3"  # Match your current version
  config:
    logLevel: "INFO"

mysql:
  auth:
    mysqlRootPassword: "mysql"  # Use your current password
    database: "spire"  # Match current database name

# Copy your existing registration entries
registrationEntries:
  enabled: true
  entries:
    # Copy from your current registration-entries.yaml
    - spiffeId: "spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster"
      parentId: "spiffe://example.org/spire/server"
      selectors:
        - "k8s_psat:cluster:spire-server-cluster"
      ttl: 3600
```

---

## 📦 **Installation Procedures**

### **Prerequisites Check**

```bash
# Verify Helm installation
helm version

# Check Kubernetes connectivity
kubectl cluster-info

# Verify storage class
kubectl get storageclass

# Check node resources
kubectl top nodes
```

### **Fresh Installation**

#### **Development Environment**

```bash
# Create development environment
helm install spire-dev ./helm-charts/spire \
  --namespace spire-dev \
  --create-namespace \
  --values ./helm-charts/spire/values/development.yaml \
  --timeout 10m
```

#### **Production Environment**

```bash
# Create production environment with custom values
cat > prod-values.yaml <<EOF
global:
  trustDomain: "company.internal"
  clusterName: "prod-k8s-cluster"

spireServer:
  replicaCount: 3  # Production; learning env uses 1
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
  persistence:
    size: 10Gi
    storageClass: "fast-ssd"

mysql:
  auth:
    existingSecret: "mysql-credentials"
  primary:
    persistence:
      size: 50Gi
      storageClass: "fast-ssd"

monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
EOF

helm install spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --create-namespace \
  --values ./helm-charts/spire/values/production.yaml \
  --values prod-values.yaml \
  --timeout 15m
```

### **Installation Verification**

```bash
# Check deployment status
helm status spire-prod -n spire-prod

# Verify all pods are running
kubectl get pods -n spire-prod

# Check services
kubectl get svc -n spire-prod

# Test SPIRE server health
kubectl exec -n spire-prod deployment/spire-prod-server -- \
  /opt/spire/bin/spire-server healthcheck

# Verify registration entries
kubectl exec -n spire-prod deployment/spire-prod-server -- \
  /opt/spire/bin/spire-server entry show
```

---

## ⚙️ **Configuration Management**

### **Environment-Specific Configurations**

#### **Development Values**
```yaml
# values/development.yaml
global:
  trustDomain: "dev.company.internal"
  
spireServer:
  config:
    logLevel: "DEBUG"
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
  persistence:
    size: 1Gi

mysql:
  primary:
    persistence:
      size: 2Gi
```

#### **Staging Values**
```yaml
# values/staging.yaml
global:
  trustDomain: "staging.company.internal"
  
spireServer:
  config:
    logLevel: "INFO"
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
  persistence:
    size: 5Gi

mysql:
  primary:
    persistence:
      size: 10Gi
```

#### **Production Values**
```yaml
# values/production.yaml
global:
  trustDomain: "company.internal"
  
spireServer:
  replicaCount: 3  # Production; learning env uses 1
  config:
    logLevel: "WARN"
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
  persistence:
    size: 20Gi
    storageClass: "fast-ssd"

mysql:
  primary:
    persistence:
      size: 100Gi
      storageClass: "fast-ssd"
```

### **Configuration Validation**

```bash
# Validate configuration before deployment
helm template spire ./helm-charts/spire \
  --values production-values.yaml \
  --validate

# Dry-run installation
helm install spire ./helm-charts/spire \
  --namespace spire \
  --values production-values.yaml \
  --dry-run

# Use helm diff plugin for comparing changes
helm diff upgrade spire ./helm-charts/spire \
  --values production-values.yaml
```

---

## 🌍 **Environment Management**

### **Multi-Environment Deployment**

#### **Automated Environment Setup**

```bash
#!/bin/bash
# deploy-environments.sh

ENVIRONMENTS=("dev" "staging" "prod")
CHART_PATH="./helm-charts/spire"

for env in "${ENVIRONMENTS[@]}"; do
  echo "Deploying SPIRE to $env environment..."
  
  helm upgrade --install spire-$env $CHART_PATH \
    --namespace spire-$env \
    --create-namespace \
    --values $CHART_PATH/values/$env.yaml \
    --wait \
    --timeout 10m
  
  # Verify deployment
  if helm status spire-$env -n spire-$env; then
    echo "✅ $env deployment successful"
  else
    echo "❌ $env deployment failed"
    exit 1
  fi
done
```

#### **Environment Promotion Pipeline**

```bash
#!/bin/bash
# promote-environment.sh

SOURCE_ENV=${1:-dev}
TARGET_ENV=${2:-staging}

echo "Promoting SPIRE from $SOURCE_ENV to $TARGET_ENV"

# Get source environment values
helm get values spire-$SOURCE_ENV -n spire-$SOURCE_ENV > /tmp/source-values.yaml

# Apply to target with environment-specific overrides
helm upgrade --install spire-$TARGET_ENV ./helm-charts/spire \
  --namespace spire-$TARGET_ENV \
  --create-namespace \
  --values /tmp/source-values.yaml \
  --values ./helm-charts/spire/values/$TARGET_ENV.yaml
```

### **Configuration Drift Detection**

```bash
#!/bin/bash
# check-drift.sh

ENVIRONMENTS=("dev" "staging" "prod")

for env in "${ENVIRONMENTS[@]}"; do
  echo "Checking configuration drift for $env..."
  
  # Compare deployed values with desired state
  helm get values spire-$env -n spire-$env > /tmp/deployed-$env.yaml
  
  if diff -u ./values/$env.yaml /tmp/deployed-$env.yaml; then
    echo "✅ $env: No drift detected"
  else
    echo "⚠️  $env: Configuration drift detected"
  fi
done
```

---

## 🔄 **Upgrade Procedures**

### **Chart Version Upgrades**

#### **Minor Version Upgrade**

```bash
# Check current version
helm list -n spire-prod

# Update chart dependencies
helm dependency update ./helm-charts/spire

# Upgrade with safety checks
helm upgrade spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --reuse-values \
  --wait \
  --timeout 10m

# Verify upgrade
kubectl rollout status deployment/spire-prod-server -n spire-prod
kubectl rollout status daemonset/spire-prod-agent -n spire-prod
```

#### **Major Version Upgrade**

```bash
# Backup current state
helm get all spire-prod -n spire-prod > backup-pre-upgrade.yaml
kubectl exec -n spire-prod spire-prod-server-0 -- \
  tar czf - /run/spire/data > data-backup.tar.gz

# Review changelog and breaking changes
# Update values.yaml for compatibility

# Perform upgrade with extended timeout
helm upgrade spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --values ./values/production.yaml \
  --wait \
  --timeout 20m \
  --force  # Only if required for breaking changes

# Verify all components
kubectl get pods -n spire-prod
helm test spire-prod -n spire-prod
```

### **Application Version Upgrades**

#### **SPIRE Server/Agent Upgrade**

```bash
# Update SPIRE version in values
cat > spire-upgrade-values.yaml <<EOF
spireServer:
  image:
    tag: "1.7.0"  # New version
spireAgent:
  image:
    tag: "1.7.0"  # New version
EOF

# Apply upgrade
helm upgrade spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --reuse-values \
  --values spire-upgrade-values.yaml \
  --wait
```

#### **Database Upgrade**

```bash
# MySQL major version upgrade
cat > db-upgrade-values.yaml <<EOF
mysql:
  image:
    tag: "14.0.0"
  primary:
    persistence:
      size: 100Gi  # Increase if needed
EOF

# Backup database first
kubectl exec -n spire-prod spire-prod-mysql-0 -- \
  mysqldump --all-databases -u root -p > db-backup-$(date +%Y%m%d).sql

# Apply upgrade with extended timeout
helm upgrade spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --reuse-values \
  --values db-upgrade-values.yaml \
  --wait \
  --timeout 30m
```

### **Rollback Procedures**

#### **Quick Rollback**

```bash
# List releases
helm history spire-prod -n spire-prod

# Rollback to previous version
helm rollback spire-prod 1 -n spire-prod

# Verify rollback
kubectl get pods -n spire-prod
helm status spire-prod -n spire-prod
```

#### **Data Recovery Rollback**

```bash
# Rollback chart version
helm rollback spire-prod 1 -n spire-prod

# Restore data if needed
kubectl exec -n spire-prod spire-prod-server-0 -i -- \
  tar xzf - -C / < data-backup.tar.gz

# Restart server to reload data
kubectl rollout restart statefulset/spire-prod-server -n spire-prod
```

---

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Chart Installation Failures**

```bash
# Check chart syntax
helm lint ./helm-charts/spire

# Debug template rendering
helm template spire ./helm-charts/spire \
  --values ./values/production.yaml \
  --debug

# Check resource conflicts
kubectl describe events -n spire-prod
```

#### **Resource Allocation Issues**

```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod resource requests
kubectl describe pod -n spire-prod spire-prod-server-0

# Adjust resource requests in values
cat > resource-fix.yaml <<EOF
spireServer:
  resources:
    requests:
      cpu: 500m  # Reduce if nodes can't handle
      memory: 512Mi
EOF

helm upgrade spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --reuse-values \
  --values resource-fix.yaml
```

#### **Storage Issues**

```bash
# Check PVC status
kubectl get pvc -n spire-prod

# Check storage class
kubectl describe storageclass

# Fix storage issues
kubectl patch pvc spire-data-spire-prod-server-0 -n spire-prod \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

### **Diagnostic Commands**

#### **Health Checks**

```bash
# Comprehensive health check script
#!/bin/bash
# health-check.sh

NAMESPACE=${1:-spire-prod}
RELEASE=${2:-spire-prod}

echo "=== Helm Release Status ==="
helm status $RELEASE -n $NAMESPACE

echo "=== Pod Status ==="
kubectl get pods -n $NAMESPACE

echo "=== Service Status ==="
kubectl get svc -n $NAMESPACE

echo "=== ConfigMap Status ==="
kubectl get configmap -n $NAMESPACE

echo "=== PVC Status ==="
kubectl get pvc -n $NAMESPACE

echo "=== SPIRE Server Health ==="
kubectl exec -n $NAMESPACE deployment/$RELEASE-server -- \
  /opt/spire/bin/spire-server healthcheck || echo "Health check failed"

echo "=== Registration Entries ==="
kubectl exec -n $NAMESPACE deployment/$RELEASE-server -- \
  /opt/spire/bin/spire-server entry show || echo "Entry show failed"

echo "=== Recent Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
```

#### **Performance Monitoring**

```bash
# Resource usage monitoring
#!/bin/bash
# monitor-resources.sh

NAMESPACE=${1:-spire-prod}

echo "=== CPU and Memory Usage ==="
kubectl top pods -n $NAMESPACE

echo "=== Storage Usage ==="
kubectl exec -n $NAMESPACE spire-prod-server-0 -- df -h /run/spire/data

echo "=== Database Size ==="
kubectl exec -n $NAMESPACE spire-prod-mysql-0 -- \
  mysql -u root -p -e "SELECT table_schema 'Database Name', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) 'Database Size (MB)' FROM information_schema.tables WHERE table_schema='spire' GROUP BY table_schema;"

echo "=== Network Connectivity ==="
kubectl exec -n $NAMESPACE spire-prod-agent-$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=spire-agent -o jsonpath='{.items[0].metadata.name}' | cut -d'-' -f4-) -- \
  nc -zv spire-prod-server 8081
```

---

## ⭐ **Best Practices**

### **Configuration Management**

#### **Values File Organization**

```
values/
├── base.yaml                 # Base configuration
├── development.yaml          # Development overrides
├── staging.yaml             # Staging overrides
├── production.yaml          # Production overrides
└── local/
    ├── dev-cluster-1.yaml   # Cluster-specific configs
    ├── dev-cluster-2.yaml
    └── prod-cluster-1.yaml
```

#### **Secret Management**

```bash
# Use Kubernetes secrets for sensitive data
kubectl create secret generic mysql-credentials \
  --from-literal=mysql-root-password=super-secret-password \
  -n spire-prod

# Reference in values.yaml
mysql:
  auth:
    existingSecret: "mysql-credentials"
    secretKeys:
      adminPasswordKey: "mysql-root-password"
```

#### **Version Pinning**

```yaml
# Pin specific versions in production
spireServer:
  image:
    tag: "1.6.3"  # Exact version, not "latest"

mysql:
  image:
    tag: "8.0.35"  # Exact MySQL version

# Use chart version constraints
dependencies:
  - name: mysql
    version: "~12.1.0"  # Allow patch updates only
```

### **Deployment Strategies**

#### **Blue-Green Deployments**

```bash
#!/bin/bash
# blue-green-deploy.sh

CURRENT_COLOR=$(helm list -n spire-prod -o json | jq -r '.[0].name' | grep -o 'blue\|green')
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "Current: $CURRENT_COLOR, Deploying: $NEW_COLOR"

# Deploy new environment
helm install spire-$NEW_COLOR ./helm-charts/spire \
  --namespace spire-$NEW_COLOR \
  --create-namespace \
  --values ./values/production.yaml

# Test new environment
helm test spire-$NEW_COLOR -n spire-$NEW_COLOR

# Switch traffic (update ingress/DNS)
# ...

# Remove old environment
helm uninstall spire-$CURRENT_COLOR -n spire-$CURRENT_COLOR
kubectl delete namespace spire-$CURRENT_COLOR
```

#### **Canary Deployments**

```yaml
# Canary deployment with weighted traffic
spireServer:
  replicaCount: 3  # Production; learning env uses 1
  
  # Label for canary identification
  podLabels:
    version: "v1.7.0"
    deployment: "canary"

  # Canary-specific configuration
  canary:
    enabled: true
    weight: 10  # 10% traffic
```

### **Monitoring and Alerting**

#### **Prometheus Integration**

```yaml
# values/monitoring.yaml
monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
      path: /metrics
      
  alerts:
    enabled: true
    rules:
      - alert: SPIREServerDown
        expr: up{job="spire-server"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "SPIRE Server is down"
```

#### **Grafana Dashboards**

```yaml
monitoring:
  grafana:
    enabled: true
    dashboards:
      spire:
        enabled: true
        datasource: prometheus
        url: "https://grafana.com/api/dashboards/12345/revisions/1/download"
```

### **Security Hardening**

#### **Pod Security Standards**

```yaml
security:
  podSecurityStandards:
    enabled: true
    enforce: "restricted"
    
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
```

#### **Network Policies**

```yaml
networking:
  networkPolicies:
    enabled: true
    ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
        ports:
        - protocol: TCP
          port: 9988  # Metrics port
```

### **Backup and Recovery**

#### **Automated Backups**

```bash
#!/bin/bash
# backup-spire.sh

NAMESPACE=${1:-spire-prod}
BACKUP_DIR="/backups/spire/$(date +%Y%m%d-%H%M%S)"

mkdir -p $BACKUP_DIR

# Backup Helm release values
helm get values spire-prod -n $NAMESPACE > $BACKUP_DIR/helm-values.yaml

# Backup SPIRE data
kubectl exec -n $NAMESPACE spire-prod-server-0 -- \
  tar czf - /run/spire/data > $BACKUP_DIR/spire-data.tar.gz

# Backup database
kubectl exec -n $NAMESPACE spire-prod-mysql-0 -- \
  mysqldump --all-databases -u root -p | gzip > $BACKUP_DIR/database.sql.gz

# Backup Kubernetes manifests
kubectl get all,configmap,secret,pvc -n $NAMESPACE -o yaml > $BACKUP_DIR/k8s-manifests.yaml

echo "Backup completed: $BACKUP_DIR"
```

#### **Recovery Procedures**

```bash
#!/bin/bash
# restore-spire.sh

BACKUP_DIR=$1
NAMESPACE=${2:-spire-prod}

# Restore Helm release
helm install spire-prod ./helm-charts/spire \
  --namespace $NAMESPACE \
  --create-namespace \
  --values $BACKUP_DIR/helm-values.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spire -n $NAMESPACE --timeout=300s

# Restore SPIRE data
kubectl exec -n $NAMESPACE spire-prod-server-0 -i -- \
  tar xzf - -C / < $BACKUP_DIR/spire-data.tar.gz

# Restore database
gunzip -c $BACKUP_DIR/database.sql.gz | \
kubectl exec -n $NAMESPACE spire-prod-mysql-0 -i -- \
  mysql -u root -p

echo "Restore completed from: $BACKUP_DIR"
```

---

## 📚 **Additional Resources**

### **Documentation Links**
- [Helm Documentation](https://helm.sh/docs/)
- [SPIRE Helm Chart README](./helm-charts/spire/README.md)
- [SPIFFE Service Integration Guide](./spiffe_service_integration_guide.md)

### **Useful Helm Plugins**

```bash
# Install useful Helm plugins
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/chartmuseum/helm-push
helm plugin install https://github.com/helm/helm-2to3
```

### **Community Resources**
- [Helm Community Charts](https://github.com/helm/charts)
- [SPIRE Community](https://spiffe.io/community/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Ready to deploy SPIRE with Helm?** Start with the development environment and gradually move to production following this guide's best practices.

---
*Last updated: January 2024*
*Version: 1.0*