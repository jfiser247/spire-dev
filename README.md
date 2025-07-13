# Multi-Minikube SPIRE Cluster Setup

This project implements a multi-minikube cluster running a SPIRE server, SPIRE database, and client workload cluster, with example database policy records for different workload services.

## Architecture

The setup consists of two minikube clusters:

1. **SPIRE Server Cluster**: Hosts the SPIRE server and PostgreSQL database
2. **Workload Cluster**: Hosts the SPIRE agent and example workload services

## Components

- **SPIRE Server**: Manages SPIFFE IDs and issues SVIDs (SPIFFE Verifiable Identity Documents)
- **PostgreSQL Database**: Stores SPIRE registration entries and other data
- **SPIRE Agent**: Runs on the workload cluster and attests workloads
- **Example Workload Services**: Three different services that obtain SPIFFE IDs from the SPIRE agent

## Prerequisites

- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [bash](https://www.gnu.org/software/bash/)

## Setup Instructions

1. Clone this repository:
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Make the scripts executable:
   ```
   chmod +x scripts/setup-clusters.sh
   chmod +x scripts/verify-setup.sh
   chmod +x scripts/push-changes.sh
   ```

3. Run the setup script:
   ```
   ./scripts/setup-clusters.sh
   ```
   This script will:
   - Create two minikube clusters
   - Deploy the SPIRE server and database to the server cluster
   - Deploy the SPIRE agent and workload services to the workload cluster
   - Register SPIFFE IDs for the workload services

4. Verify the setup:
   ```
   ./scripts/verify-setup.sh
   ```
   This script will:
   - Check the status of all components
   - Verify that each workload service can obtain its SPIFFE ID

## Workload Services

The setup includes three example workload services:

1. **service1**: An nginx web server with SPIFFE ID `spiffe://example.org/workload/service1`
2. **service2**: An Apache httpd web server with SPIFFE ID `spiffe://example.org/workload/service2`
3. **service3**: A Python HTTP server with SPIFFE ID `spiffe://example.org/workload/service3`

Each service is configured to access the SPIRE agent socket and can obtain its SPIFFE ID using the Workload API.

## Monitoring Dashboard

The project includes both a comprehensive web-based and desktop monitoring dashboard that provides deep visibility into SPIRE server and agent operations, workload registrations, and advanced telemetry metrics.

### Web Dashboard

A modern, enterprise-grade web-based dashboard with interactive drilldown capabilities for comprehensive SPIFFE/SPIRE monitoring.

#### Dashboard Tabs

- **Overview Tab**: Real-time cluster status with clickable component health cards
- **SPIRE Server Tab**: Detailed server component status and pod monitoring
- **Database Tab**: PostgreSQL database monitoring with storage and connection metrics
- **Agents Tab**: SPIRE agent health tracking across all nodes
- **Workloads Tab**: Service deployment status with detailed workload metrics
- **SPIRE Metrics Tab**: ⭐ **NEW** - Advanced telemetry with interactive drilldown capabilities
- **Commands Tab**: Comprehensive kubectl commands for troubleshooting and metrics collection

#### 🔍 Interactive SPIRE Metrics & Telemetry

The enhanced dashboard now includes industry-standard SPIFFE/SPIRE observability metrics with interactive drilldown capabilities:

##### Clickable Metric Tiles
Each metric tile is interactive and opens detailed analysis modals:

1. **Server RPC Calls** 📊
   - **Summary**: Total RPC operations across all SPIRE server endpoints
   - **Drilldown Details**:
     - Real-time RPC call volumes and response times
     - Success rates and error analysis
     - Breakdown by RPC method (attest_agent, fetch_x509_svid, fetch_jwt_svid, etc.)
     - Performance trends and peak operation analysis
     - Recent activity timeline with timing details

2. **Agent Connections** 🔗
   - **Summary**: Active SPIRE agent connections and health status
   - **Drilldown Details**:
     - Connection pool usage and session duration analysis
     - Failed connection tracking and retry patterns
     - Individual agent status with node mapping
     - Heartbeat monitoring and data transfer metrics
     - Connection timeline and health trends

3. **SVID Issuance Rate** 🎫
   - **Summary**: Real-time SVID (SPIFFE Verifiable Identity Document) issuance metrics
   - **Drilldown Details**:
     - Current issuance rates and daily volume analysis
     - X.509 vs JWT SVID distribution breakdown
     - Issuance performance metrics and timing analysis
     - Common selectors and workload patterns
     - Recent issuance activity with SPIFFE ID details

4. **Certificate Expiry** ⏰
   - **Summary**: Certificate lifecycle monitoring and expiry warnings
   - **Drilldown Details**:
     - Immediate expiry alerts (< 24 hours)
     - Weekly expiry forecasting and planning
     - Auto-renewal success rates and failure analysis
     - CA certificate validity and rotation tracking
     - Detailed expiry timeline and renewal history

##### Advanced Metrics Tables
- **SPIRE Server Metrics**: Comprehensive tracking of server-side operations
- **SPIRE Agent Metrics**: Agent-specific performance and health indicators
- **Alert Thresholds**: Production-ready monitoring with severity levels
- **Telemetry Configuration**: Prometheus endpoints and collection settings

##### Interactive Features
- **Hover Effects**: Visual indicators showing clickable elements with magnifying glass icons
- **Modal Dialogs**: Detailed metric analysis with smooth fade-in animations
- **Trend Analysis**: Visual trend indicators (↗ up, ↘ down, → stable, ⚠ warning)
- **Keyboard Navigation**: ESC key support for closing modals
- **Responsive Design**: Mobile-friendly layout with touch support

#### Accessing the Web Dashboard

The setup script will display the dashboard URL when complete:

```bash
./scripts/setup-clusters.sh
```

Look for this output:
```
🌐 Web Dashboard Available:
  Open in browser: file:///path/to/project/web-dashboard.html
```

Simply copy and paste the file path into your browser address bar to access the dashboard.

#### Production-Ready Features
- **Real-time Data**: Auto-refresh capabilities with configurable intervals (5s-60s)
- **Prometheus Integration**: Ready for production metrics collection (port 9988)
- **Alert Management**: Industry-standard thresholds for operational monitoring
- **Performance Monitoring**: Response time tracking and error rate analysis
- **Security Compliance**: Certificate lifecycle and expiry management
- **Operational Insights**: Historical trends and capacity planning data

#### Dashboard Capabilities
- **Responsive Design**: Optimized for desktop and mobile browsers
- **Live Updates**: Real-time status with color-coded health indicators
- **Tabbed Interface**: Organized monitoring sections with smooth transitions
- **Interactive Elements**: Clickable tiles and detailed drilldown modals
- **Command Integration**: Built-in kubectl and metrics collection commands
- **Export Ready**: Structured for integration with monitoring platforms

### Desktop Dashboard (JavaFX)

A traditional desktop application is also available for advanced monitoring.

#### Running the Desktop Dashboard

```bash
mvn clean javafx:run
```

#### Desktop Dashboard Features
- **Workload Registrations**: View all registered workloads with their SPIFFE IDs, parent IDs, and selectors
- **Agent Status**: Monitor the health and status of all SPIRE agents
- **Workload Metrics**: View statistics about registrations, agents, and workloads
- **Settings**: Configure connection settings for the Kubernetes clusters

## Useful Commands

### Check SPIRE Server Status
```bash
kubectl --context spire-server-cluster -n spire get pods
```

### Check SPIRE Agent Status
```bash
kubectl --context workload-cluster -n spire get pods
```

### Check Workload Services
```bash
kubectl --context workload-cluster -n workload get pods
```

### List SPIRE Registration Entries
```bash
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- /opt/spire/bin/spire-server entry show
```

### SPIRE Metrics and Telemetry Commands

#### Access SPIRE Server Metrics (Prometheus Format)
```bash
# Port-forward to access metrics endpoint
kubectl --context spire-server-cluster -n spire port-forward spire-server-0 9988:9988 &

# Fetch metrics
curl http://localhost:9988/metrics
```

#### Access SPIRE Agent Metrics
```bash
# Get agent pod name
AGENT_POD=$(kubectl --context workload-cluster -n spire get pod -l app=spire-agent -o jsonpath='{.items[0].metadata.name}')

# Port-forward to agent metrics
kubectl --context workload-cluster -n spire port-forward $AGENT_POD 9988:9988 &

# Fetch agent metrics
curl http://localhost:9988/metrics
```

#### View SPIRE Server Telemetry Configuration
```bash
kubectl --context spire-server-cluster -n spire get configmap spire-server -o yaml | grep -A 20 telemetry
```

#### Monitor Real-time SPIRE Operations
```bash
# Watch SPIRE server logs
kubectl --context spire-server-cluster -n spire logs -f spire-server-0

# Watch agent logs
kubectl --context workload-cluster -n spire logs -f -l app=spire-agent

# Monitor certificate operations
kubectl --context spire-server-cluster -n spire logs spire-server-0 | grep -i "certificate\|svid\|attest"
```

### Push Git Changes
```
./scripts/push-changes.sh
```
This script will:
- Check for uncommitted changes
- Verify if there are commits to push
- Push the changes to the remote repository

## Cleanup

To delete the minikube clusters:
```
minikube delete -p spire-server-cluster
minikube delete -p workload-cluster
```

## Project Structure

```
.
├── k8s/                           # Kubernetes manifests
│   ├── spire-db/                  # Database components
│   │   ├── namespace.yaml
│   │   ├── postgres-deployment.yaml
│   │   ├── postgres-pvc.yaml
│   │   └── postgres-service.yaml
│   ├── spire-server/              # SPIRE server components
│   │   ├── namespace.yaml
│   │   ├── registration-entries.yaml
│   │   ├── server-configmap.yaml
│   │   ├── server-rbac.yaml
│   │   ├── server-service.yaml
│   │   └── server-statefulset.yaml
│   └── workload-cluster/          # Workload cluster components
│       ├── agent-configmap.yaml
│       ├── agent-daemonset.yaml
│       ├── agent-rbac.yaml
│       ├── namespace.yaml
│       ├── service1-deployment.yaml
│       ├── service2-deployment.yaml
│       └── service3-deployment.yaml
├── scripts/                       # Setup and utility scripts
│   ├── setup-clusters.sh          # Main setup script
│   ├── verify-setup.sh           # Verification script
│   └── push-changes.sh           # Git push script
├── src/                          # Desktop dashboard source
│   └── main/
│       ├── java/                 # JavaFX application code
│       └── resources/            # FXML and other resources
├── web-dashboard.html            # Web-based monitoring dashboard
├── pom.xml                       # Maven build configuration
└── README.md                     # This file
```

## Technical Architecture

### SPIRE Metrics & Telemetry Implementation

The enhanced dashboard implements industry-standard SPIFFE/SPIRE observability following the official telemetry specifications:

#### Metrics Collection Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SPIRE Server  │    │   SPIRE Agent   │    │  Web Dashboard  │
│                 │    │                 │    │                 │
│ Port 9988       │    │ Port 9988       │    │ Interactive UI  │
│ /metrics        │◄──►│ /metrics        │◄──►│ Drilldown       │
│ (Prometheus)    │    │ (Prometheus)    │    │ Modals          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌─────────────────┐
                    │   Prometheus    │
                    │   (Optional)    │
                    │   Production    │
                    │   Integration   │
                    └─────────────────┘
```

#### Key Metrics Categories

1. **SPIRE Server Metrics**
   - `spire_server.rpc.*` - RPC operation counters and timing
   - `spire_server.ca.*` - Certificate authority operations
   - `spire_server.datastore.*` - Database operation metrics

2. **SPIRE Agent Metrics**
   - `spire_agent.cache_manager.*` - SVID cache performance
   - `spire_agent.sds_api.*` - Service Discovery Service metrics
   - `spire_agent.sync_manager.*` - Entry synchronization tracking

3. **Operational Metrics**
   - Connection health and session management
   - Certificate lifecycle and expiry monitoring
   - Performance trends and capacity planning

#### Dashboard Technology Stack
- **Frontend**: Modern HTML5/CSS3/JavaScript
- **UI Framework**: CSS Grid and Flexbox for responsive design
- **Animations**: CSS3 transitions and keyframe animations
- **Data Handling**: Asynchronous JavaScript with Promise-based architecture
- **Modal System**: Custom modal implementation with keyboard navigation
- **Real-time Updates**: Configurable auto-refresh with background data fetching

#### Production Integration
- **Prometheus Compatible**: Standard `/metrics` endpoints on port 9988
- **Grafana Ready**: Metrics structured for dashboard import
- **Alert Manager**: Pre-configured thresholds for operational alerts
- **Kubernetes Native**: Integrated with kubectl and cluster operations
```

## 🎯 **Production Helm Charts Template**

This repository includes **production-ready Helm charts** that serve as a comprehensive template for implementing SPIRE in production Kubernetes environments. The charts replace manual Kubernetes manifests with a templated, configurable, and maintainable solution.

### 📦 **Helm Chart Architecture**

```
helm-charts/spire/
├── Chart.yaml                    # Chart metadata with PostgreSQL dependency
├── values.yaml                   # Default configuration values
├── values/
│   ├── development.yaml          # Development environment overrides
│   └── production.yaml           # Production environment overrides
├── templates/
│   ├── _helpers.tpl              # Template functions and helpers
│   ├── namespace.yaml            # Namespace management
│   ├── server-*.yaml             # SPIRE Server components
│   ├── agent-*.yaml              # SPIRE Agent components
│   └── workload-*.yaml           # Example workload services
└── README.md                     # Detailed chart documentation
```

### 🚀 **Key Advantages Over Manual Manifests**

| Feature | Manual K8s Manifests | Helm Charts Template |
|---------|----------------------|----------------------|
| **Deployment** | Multiple `kubectl apply` commands | Single `helm install` command |
| **Environment Management** | Separate manifest sets per environment | Single chart + environment values |
| **Configuration** | Hard-coded values in YAML | Templated with environment variables |
| **Updates** | Manual file editing and reapplication | `helm upgrade` with value overrides |
| **Rollbacks** | Manual backup and restore | `helm rollback` to previous version |
| **Dependencies** | Manual PostgreSQL setup | Automatic dependency management |
| **Validation** | No built-in validation | Template validation and dry-run |
| **Versioning** | Git-based file tracking | Helm release versioning |

### 🏭 **Production Implementation Guide**

#### **1. Template Customization for Your Environment**

**Step 1: Clone and Customize Values**
```bash
# Copy the chart template to your infrastructure repository
cp -r helm-charts/spire /path/to/your/infrastructure/charts/

# Create organization-specific values
cat > /path/to/your/infrastructure/charts/spire/values/company-production.yaml <<EOF
global:
  trustDomain: "company.internal"
  clusterName: "prod-k8s-cluster"
  imageRegistry: "your-registry.company.com"

spireServer:
  replicaCount: 3  # High availability
  image:
    repository: "spiffe/spire-server"
    tag: "1.6.3"
  
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
  
  persistence:
    size: 20Gi
    storageClass: "fast-ssd"
  
  config:
    logLevel: "WARN"

postgresql:
  auth:
    existingSecret: "postgresql-credentials"
  primary:
    persistence:
      size: 100Gi
      storageClass: "fast-ssd"
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi

# Production security settings
security:
  podSecurityStandards:
    enabled: true
    enforce: "restricted"

# Enable monitoring
monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
EOF
```

**Step 2: Customize Registration Entries**
```yaml
# Add your organization's SPIFFE ID structure
registrationEntries:
  enabled: true
  entries:
    # Node attestation entry
    - spiffeId: "spiffe://company.internal/spire/agent/k8s_psat/prod-cluster"
      parentId: "spiffe://company.internal/spire/server"
      selectors:
        - "k8s_psat:cluster:prod-cluster"
      ttl: 3600
    
    # Application-specific entries
    - spiffeId: "spiffe://company.internal/workload/user-service"
      parentId: "spiffe://company.internal/spire/agent/k8s_psat/prod-cluster"
      selectors:
        - "k8s:ns:production"
        - "k8s:sa:user-service"
        - "k8s:pod-label:app:user-service"
      ttl: 900  # 15 minutes for production security
    
    - spiffeId: "spiffe://company.internal/workload/payment-api"
      parentId: "spiffe://company.internal/spire/agent/k8s_psat/prod-cluster"
      selectors:
        - "k8s:ns:production"
        - "k8s:sa:payment-api"
        - "k8s:pod-label:app:payment-api"
      ttl: 900
```

#### **2. Multi-Environment Deployment Strategy**

**Environment Structure:**
```bash
# Recommended directory structure
infrastructure/
├── charts/
│   └── spire/                    # Customized chart from this template
└── environments/
    ├── development/
    │   ├── values.yaml          # Dev-specific values
    │   └── secrets.yaml         # Dev secrets (encrypted)
    ├── staging/
    │   ├── values.yaml          # Staging-specific values
    │   └── secrets.yaml         # Staging secrets (encrypted)
    └── production/
        ├── values.yaml          # Production-specific values
        └── secrets.yaml         # Production secrets (encrypted)
```

**Deployment Automation:**
```bash
#!/bin/bash
# deploy-spire.sh - Production deployment script

ENVIRONMENT=${1:-production}
CHART_PATH="./charts/spire"
VALUES_PATH="./environments/$ENVIRONMENT"

echo "🚀 Deploying SPIRE to $ENVIRONMENT environment..."

# Validate configuration
helm lint $CHART_PATH --values $VALUES_PATH/values.yaml
if [ $? -ne 0 ]; then
    echo "❌ Chart validation failed"
    exit 1
fi

# Deploy with production settings
helm upgrade --install spire-$ENVIRONMENT $CHART_PATH \
  --namespace spire-$ENVIRONMENT \
  --create-namespace \
  --values $VALUES_PATH/values.yaml \
  --wait \
  --timeout 15m \
  --atomic  # Rollback on failure

# Verify deployment
if helm status spire-$ENVIRONMENT -n spire-$ENVIRONMENT; then
    echo "✅ SPIRE deployment successful"
    
    # Run post-deployment tests
    helm test spire-$ENVIRONMENT -n spire-$ENVIRONMENT
    
    # Verify SPIRE server health
    kubectl exec -n spire-$ENVIRONMENT deployment/spire-$ENVIRONMENT-server -- \
      /opt/spire/bin/spire-server healthcheck
else
    echo "❌ SPIRE deployment failed"
    exit 1
fi
```

#### **3. Security Hardening for Production**

**Network Security:**
```yaml
# values/security-hardened.yaml
networking:
  networkPolicies:
    enabled: true
    
  # Restrict ingress to SPIRE server
  ingress:
    spireServer:
      - from:
        - namespaceSelector:
            matchLabels:
              name: spire-production
        ports:
        - protocol: TCP
          port: 8081
      - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
        ports:
        - protocol: TCP
          port: 9988  # Metrics port

# Pod security contexts
spireServer:
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    capabilities:
      drop:
        - ALL

spireAgent:
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
        - ALL
      add:
        - NET_ADMIN  # Required for agent operations
```

**Secret Management:**
```bash
# Create production secrets
kubectl create secret generic postgresql-credentials \
  --from-literal=postgres-password="$(openssl rand -base64 32)" \
  --namespace spire-production

kubectl create secret generic spire-server-ca \
  --from-file=ca.crt=/path/to/your/ca.crt \
  --from-file=ca.key=/path/to/your/ca.key \
  --namespace spire-production
```

#### **4. High Availability Configuration**

**Multi-Zone Deployment:**
```yaml
# Production HA configuration
spireServer:
  replicaCount: 3
  
  # Anti-affinity for zone distribution
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/component: spire-server
        topologyKey: topology.kubernetes.io/zone
    
    # Prefer different nodes
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: node-role.kubernetes.io/spire
            operator: In
            values:
            - "true"

# Database HA with read replicas
postgresql:
  architecture: replication
  readReplicas:
    replicaCount: 2
  primary:
    persistence:
      size: 100Gi
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
```

#### **5. Monitoring and Observability Integration**

**Prometheus Integration:**
```yaml
# Production monitoring configuration
monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
      scrapeTimeout: 10s
      labels:
        release: prometheus-operator
    
    # Custom alerting rules
    prometheusRule:
      enabled: true
      rules:
        - alert: SPIREServerDown
          expr: up{job="spire-server"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "SPIRE Server instance is down"
            description: "SPIRE Server {{ $labels.instance }} has been down for more than 5 minutes"
        
        - alert: SPIREAgentDown
          expr: up{job="spire-agent"} == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "SPIRE Agent instance is down"

  # Grafana dashboards
  grafana:
    enabled: true
    dashboards:
      spire:
        enabled: true
        datasource: prometheus
```

### 🔄 **Operational Procedures**

#### **Upgrade Strategy**

```bash
#!/bin/bash
# upgrade-spire.sh - Safe production upgrade procedure

ENVIRONMENT="production"
NAMESPACE="spire-$ENVIRONMENT"

echo "🔄 Starting SPIRE upgrade process..."

# 1. Backup current state
echo "📦 Creating backup..."
helm get all spire-$ENVIRONMENT -n $NAMESPACE > "backup-$(date +%Y%m%d-%H%M%S).yaml"

# 2. Database backup
kubectl exec -n $NAMESPACE spire-$ENVIRONMENT-postgresql-0 -- \
  pg_dumpall -U postgres | gzip > "db-backup-$(date +%Y%m%d-%H%M%S).sql.gz"

# 3. Validate new configuration
echo "✅ Validating new configuration..."
helm template spire ./charts/spire \
  --values ./environments/$ENVIRONMENT/values.yaml \
  --validate

# 4. Perform rolling upgrade
echo "🚀 Performing rolling upgrade..."
helm upgrade spire-$ENVIRONMENT ./charts/spire \
  --namespace $NAMESPACE \
  --values ./environments/$ENVIRONMENT/values.yaml \
  --wait \
  --timeout 20m

# 5. Verify upgrade
echo "🔍 Verifying upgrade..."
kubectl rollout status statefulset/spire-$ENVIRONMENT-server -n $NAMESPACE
kubectl rollout status daemonset/spire-$ENVIRONMENT-agent -n $NAMESPACE

# 6. Health check
kubectl exec -n $NAMESPACE deployment/spire-$ENVIRONMENT-server -- \
  /opt/spire/bin/spire-server healthcheck

echo "✅ SPIRE upgrade completed successfully"
```

#### **Disaster Recovery**

```bash
#!/bin/bash
# disaster-recovery.sh - SPIRE disaster recovery procedure

BACKUP_DIR=$1
TARGET_ENVIRONMENT=${2:-production}

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup-directory> [environment]"
    exit 1
fi

echo "🚨 Starting SPIRE disaster recovery..."

# 1. Deploy fresh SPIRE instance
helm install spire-$TARGET_ENVIRONMENT ./charts/spire \
  --namespace spire-$TARGET_ENVIRONMENT \
  --create-namespace \
  --values ./environments/$TARGET_ENVIRONMENT/values.yaml \
  --wait

# 2. Restore database
echo "📥 Restoring database..."
gunzip -c $BACKUP_DIR/db-backup-*.sql.gz | \
kubectl exec -n spire-$TARGET_ENVIRONMENT spire-$TARGET_ENVIRONMENT-postgresql-0 -i -- \
  psql -U postgres

# 3. Restart SPIRE server to reload data
kubectl rollout restart statefulset/spire-$TARGET_ENVIRONMENT-server -n spire-$TARGET_ENVIRONMENT

echo "✅ Disaster recovery completed"
```

### 📊 **Production Readiness Checklist**

Before deploying SPIRE using this template in production:

#### **Infrastructure Requirements**
- [ ] **Kubernetes cluster** version 1.20+ with RBAC enabled
- [ ] **Storage class** configured for persistent volumes (preferably SSD)
- [ ] **Load balancer** or ingress controller for external access
- [ ] **Monitoring stack** (Prometheus, Grafana) deployed
- [ ] **Backup solution** for persistent data

#### **Security Configuration**
- [ ] **Pod Security Standards** enforced (restricted level)
- [ ] **Network policies** configured for traffic isolation
- [ ] **Secrets management** using Kubernetes secrets or external systems
- [ ] **Image scanning** enabled for container vulnerabilities
- [ ] **RBAC policies** following principle of least privilege

#### **Operational Readiness**
- [ ] **Monitoring and alerting** configured for SPIRE components
- [ ] **Log aggregation** setup for centralized logging
- [ ] **Backup procedures** tested and documented
- [ ] **Disaster recovery** plan created and validated
- [ ] **Upgrade procedures** documented and tested
- [ ] **Runbooks** created for common operational tasks

#### **Application Integration**
- [ ] **Service registration** strategy defined
- [ ] **SPIFFE ID naming** convention established
- [ ] **TTL values** configured based on security requirements
- [ ] **Workload attestation** selectors defined
- [ ] **mTLS implementation** validated across services

### 📚 **Template Customization Examples**

#### **Multi-Cluster Federation**

```yaml
# values/multi-cluster.yaml
spireServer:
  config:
    # Enable federation
    federation:
      enabled: true
      bundleEndpoint:
        address: "0.0.0.0"
        port: 8443
      
  # Federation service
  federationService:
    enabled: true
    type: LoadBalancer
    port: 8443

# Cross-cluster trust configuration
federatedTrustDomains:
  - trustDomain: "cluster-east.company.internal"
    bundleEndpointURL: "https://spire-east.company.internal:8443"
  - trustDomain: "cluster-west.company.internal"
    bundleEndpointURL: "https://spire-west.company.internal:8443"
```

#### **Custom Node Attestation**

```yaml
# values/custom-attestation.yaml
spireServer:
  config:
    plugins:
      nodeAttestors:
        k8s_psat:
          enabled: true
          config:
            clusters:
              production-cluster:
                service_account_allow_list:
                  - "spire:spire-agent"
        
        # Add custom attestation plugin
        custom_attestor:
          enabled: true
          plugin_cmd: "/opt/custom-attestor"
          plugin_data:
            config_path: "/etc/custom-attestor/config.yaml"
```

### 🎯 **Getting Started with the Template**

#### **Quick Start for Production**

1. **Copy the template:**
```bash
git clone <this-repository>
cp -r helm-charts/spire /path/to/your/infrastructure/
```

2. **Customize for your organization:**
```bash
# Edit chart values for your environment
vi /path/to/your/infrastructure/spire/values/production.yaml

# Add your trust domain and cluster configuration
# Configure your image registry and versions
# Set up your storage classes and resource requirements
```

3. **Deploy to production:**
```bash
helm install spire-prod /path/to/your/infrastructure/spire \
  --namespace spire-production \
  --create-namespace \
  --values /path/to/your/infrastructure/spire/values/production.yaml
```

4. **Verify and integrate:**
```bash
# Verify deployment
helm status spire-prod -n spire-production

# Test SPIRE functionality
kubectl exec -n spire-production deployment/spire-prod-server -- \
  /opt/spire/bin/spire-server entry show
```

This Helm chart template provides a **production-ready foundation** for implementing SPIRE in enterprise Kubernetes environments, with comprehensive security, monitoring, and operational capabilities built-in.

For detailed implementation guidance, see:
- [Helm Deployment Guide](HELM_DEPLOYMENT_GUIDE.md) - Complete deployment procedures
- [SPIFFE Service Integration Guide](SPIFFE_SERVICE_INTEGRATION_GUIDE.md) - Service onboarding
- [Chart Documentation](helm-charts/spire/README.md) - Detailed chart reference
