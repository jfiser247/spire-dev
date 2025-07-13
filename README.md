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

The project includes both a web-based and desktop monitoring dashboard that provides visibility into the SPIRE server and agent status, workload registrations, and other metrics.

### Web Dashboard

A modern web-based dashboard is automatically available after running the setup script.

#### Features
- **Overview Tab**: Real-time cluster status and component health
- **SPIRE Server Tab**: Server component status and monitoring
- **Agents Tab**: SPIRE agent health and status tracking  
- **Workloads Tab**: Service deployment status and metrics
- **Commands Tab**: Useful kubectl commands for troubleshooting

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

#### Dashboard Features
- **Responsive Design**: Works on desktop and mobile browsers
- **Real-time Status**: Color-coded status indicators for all components
- **Tabbed Interface**: Organized sections for different aspects of monitoring
- **Refresh Controls**: Manual refresh buttons for real-time updates
- **Command Reference**: Built-in kubectl command examples

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
```
kubectl --context spire-server-cluster -n spire get pods
```

### Check SPIRE Agent Status
```
kubectl --context workload-cluster -n spire get pods
```

### Check Workload Services
```
kubectl --context workload-cluster -n workload get pods
```

### List SPIRE Registration Entries
```
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- /opt/spire/bin/spire-server entry show
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
