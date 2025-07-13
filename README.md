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
