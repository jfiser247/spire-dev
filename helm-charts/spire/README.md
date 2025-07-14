# SPIRE Helm Chart

This Helm chart provides a complete deployment of SPIRE (SPIFFE Runtime Environment) with PostgreSQL database support, designed for production-grade identity management in Kubernetes environments.

## 🎯 **Overview**

This chart deploys:
- **SPIRE Server**: Central identity authority with StatefulSet deployment
- **SPIRE Agent**: DaemonSet deployment across all nodes  
- **PostgreSQL Database**: Persistent storage for SPIRE data (using Bitnami chart)
- **RBAC Configuration**: Service accounts, roles, and bindings
- **Example Workloads**: Sample services demonstrating SPIFFE integration

## ✅ **Prerequisites**

- Kubernetes 1.24+ (recommended for SPIRE 1.12.4)
- Helm 3.8.0+
- PV provisioner support (for persistent volumes)
- StorageClass configured (optional, uses default if not specified)
- Container runtime: Docker Desktop or Rancher Desktop

## 📦 **Installation**

### Quick Start

```bash
# Add the repository (if using a chart repository)
helm repo add spire ./helm-charts
helm repo update

# Install with default values
helm install spire ./helm-charts/spire

# Or install with custom values
helm install spire ./helm-charts/spire -f custom-values.yaml
```

### Environment-Specific Deployments

#### Development Environment
```bash
helm install spire-dev ./helm-charts/spire \
  --namespace spire-dev \
  --create-namespace \
  --values ./helm-charts/spire/values/development.yaml
```

#### Production Environment
```bash
helm install spire-prod ./helm-charts/spire \
  --namespace spire-prod \
  --create-namespace \
  --values ./helm-charts/spire/values/production.yaml
```

#### Custom Configuration
```bash
helm install spire ./helm-charts/spire \
  --namespace spire \
  --create-namespace \
  --set global.trustDomain=my-company.com \
  --set spireServer.replicaCount=3 \
  --set postgresql.auth.postgresPassword=secretpassword
```

## ⚙️ **Configuration**

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.trustDomain` | SPIFFE trust domain | `example.org` |
| `global.clusterName` | Kubernetes cluster name | `spire-cluster` |
| `spireServer.enabled` | Enable SPIRE Server | `true` |
| `spireServer.replicaCount` | Number of server replicas | `1` |
| `spireServer.image.tag` | SPIRE Server image tag | `1.6.3` |
| `spireAgent.enabled` | Enable SPIRE Agent | `true` |
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.postgresPassword` | PostgreSQL password | `postgres` |

### Resource Configuration

```yaml
# Custom resource limits
spireServer:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

spireAgent:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
```

### Storage Configuration

```yaml
# Custom storage settings
spireServer:
  persistence:
    enabled: true
    storageClass: "fast-ssd"
    size: 5Gi

postgresql:
  primary:
    persistence:
      storageClass: "fast-ssd"
      size: 20Gi
```

### Security Configuration

```yaml
# Production security settings
security:
  podSecurityStandards:
    enabled: true
    enforce: "restricted"

# RBAC settings
rbac:
  create: true
  serviceAccount:
    create: true
```

## 🔧 **Advanced Configuration**

### Custom SPIRE Configuration

Override the default SPIRE server configuration:

```yaml
spireServer:
  config:
    logLevel: "DEBUG"
    telemetry:
      enabled: true
      prometheusPort: 9988
```

### Registration Entries

Configure automatic registration entries:

```yaml
registrationEntries:
  enabled: true
  entries:
    - spiffeId: "spiffe://example.org/workload/user-service"
      parentId: "spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster"
      selectors:
        - "k8s:ns:production"
        - "k8s:sa:user-service"
      ttl: 1800
```

### External Database

Use an external PostgreSQL database:

```yaml
postgresql:
  enabled: false

externalDatabase:
  connectionString: "postgres://user:pass@host:5432/spire?sslmode=require"
```

### High Availability

Configure SPIRE Server for high availability:

```yaml
spireServer:
  replicaCount: 3
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/component: spire-server
        topologyKey: kubernetes.io/hostname
```

## 📊 **Monitoring & Observability**

### Prometheus Integration

Enable Prometheus metrics:

```yaml
monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
```

### Grafana Dashboards

Enable Grafana dashboard provisioning:

```yaml
monitoring:
  grafana:
    enabled: true
    dashboards:
      spire: true
```

### Metrics Endpoints

The chart exposes the following metrics endpoints:
- SPIRE Server: `http://spire-server:9988/metrics`
- SPIRE Agent: `http://spire-agent:9988/metrics`

## 🔐 **Security Considerations**

### Production Security Checklist

- [ ] Use strong PostgreSQL passwords
- [ ] Enable Pod Security Standards
- [ ] Configure network policies
- [ ] Use dedicated node selectors
- [ ] Enable RBAC with least privilege
- [ ] Configure proper storage encryption
- [ ] Review and customize SPIFFE IDs
- [ ] Set appropriate TTL values

### Example Production Security Configuration

```yaml
# Strong security configuration
security:
  podSecurityStandards:
    enabled: true
    enforce: "restricted"

networking:
  networkPolicies:
    enabled: true

postgresql:
  auth:
    existingSecret: "postgresql-credentials"

spireServer:
  nodeSelector:
    node-role.kubernetes.io/spire: "true"
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    capabilities:
      drop:
        - ALL
```

## 🚀 **Deployment Examples**

### Multi-Environment Setup

Deploy across multiple environments:

```bash
# Development
helm install spire-dev ./helm-charts/spire \
  -n spire-dev --create-namespace \
  -f values/development.yaml

# Staging  
helm install spire-staging ./helm-charts/spire \
  -n spire-staging --create-namespace \
  -f values/staging.yaml

# Production
helm install spire-prod ./helm-charts/spire \
  -n spire-prod --create-namespace \
  -f values/production.yaml
```

### Blue-Green Deployment

Deploy a new version alongside existing:

```bash
# Deploy green environment
helm install spire-green ./helm-charts/spire \
  -n spire-green --create-namespace \
  --set global.trustDomain=green.example.org

# Test and validate...

# Switch traffic and cleanup blue
helm uninstall spire-blue -n spire-blue
```

## 🔄 **Upgrade Procedures**

### Regular Updates

```bash
# Check current version
helm list -n spire

# Update to new chart version
helm upgrade spire ./helm-charts/spire \
  -n spire \
  -f my-values.yaml

# Rollback if needed
helm rollback spire 1 -n spire
```

### Configuration Changes

```bash
# Update configuration
helm upgrade spire ./helm-charts/spire \
  -n spire \
  --reuse-values \
  --set spireServer.config.logLevel=DEBUG
```

### Database Migrations

For major PostgreSQL upgrades:

```bash
# Backup database first
kubectl exec -n spire spire-postgresql-0 -- pg_dumpall -U postgres > backup.sql

# Upgrade with careful planning
helm upgrade spire ./helm-charts/spire \
  -n spire \
  --set postgresql.image.tag=14.0.0
```

## 🛠️ **Troubleshooting**

### Common Issues

#### SPIRE Server Not Starting

```bash
# Check logs
kubectl logs -n spire deployment/spire-server

# Check configuration
kubectl describe configmap -n spire spire-server-config

# Verify database connectivity
kubectl exec -n spire deployment/spire-server -- nc -zv postgresql 5432
```

#### Agent Registration Issues

```bash
# Check agent logs
kubectl logs -n spire daemonset/spire-agent

# Verify server connectivity
kubectl exec -n spire daemonset/spire-agent -- nc -zv spire-server 8081

# Check registration entries
kubectl exec -n spire deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show
```

#### Database Connection Problems

```bash
# Check PostgreSQL status
kubectl get pods -n spire -l app.kubernetes.io/name=postgresql

# Test database connection
kubectl exec -n spire spire-postgresql-0 -- \
  psql -U postgres -d spire -c "SELECT version();"
```

### Debug Mode

Enable debug logging:

```yaml
spireServer:
  config:
    logLevel: "DEBUG"

spireAgent:
  config:
    logLevel: "DEBUG"
```

## 📚 **Migration from Manual Deployment**

### From Existing Kubernetes Manifests

1. **Backup existing data**:
```bash
kubectl exec -n spire spire-server-0 -- tar czf - /run/spire/data > spire-backup.tar.gz
```

2. **Export current configuration**:
```bash
kubectl get configmap -n spire spire-server-config -o yaml > current-config.yaml
```

3. **Create values file matching current setup**:
```yaml
# values-migration.yaml
global:
  trustDomain: "your-current-domain"

spireServer:
  config:
    # Match your current configuration
    logLevel: "INFO"
```

4. **Deploy with Helm**:
```bash
helm install spire ./helm-charts/spire \
  -n spire \
  -f values-migration.yaml
```

5. **Restore data if needed**:
```bash
kubectl exec -n spire spire-server-0 -- tar xzf - -C / < spire-backup.tar.gz
```

## 📖 **Additional Resources**

### Related Documentation
- [SPIFFE Service Integration Guide](../../SPIFFE_SERVICE_INTEGRATION_GUIDE.md)
- [SPIRE Documentation](https://spiffe.io/docs/latest/spire-about/)
- [Helm Documentation](https://helm.sh/docs/)

### Chart Dependencies
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/master/bitnami/postgresql)

### Support
- **Issues**: GitHub Issues for chart-specific problems
- **SPIRE Community**: [SPIFFE Slack](https://spiffe.slack.com)
- **Internal Support**: `#spire-support` Slack channel

## 🏷️ **Chart Information**

- **Chart Version**: 1.0.0
- **App Version**: 1.6.3
- **Kubernetes Version**: 1.20+
- **Helm Version**: 3.2.0+

## 📄 **License**

This chart is licensed under the Apache 2.0 License. See [LICENSE](LICENSE) for details.

---

For complete configuration options, see [values.yaml](values.yaml) and environment-specific value files in the [values/](values/) directory.