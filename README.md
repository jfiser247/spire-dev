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

The project includes a graphical monitoring dashboard that provides visibility into the SPIRE server and agent status, workload registrations, and other metrics.

### Features

- **Workload Registrations**: View all registered workloads with their SPIFFE IDs, parent IDs, and selectors
- **Agent Status**: Monitor the health and status of all SPIRE agents
- **Workload Metrics**: View statistics about registrations, agents, and workloads
- **Settings**: Configure connection settings for the Kubernetes clusters

### Running the Dashboard

To run the monitoring dashboard:

```
mvn clean javafx:run
```

### Screenshots

The dashboard provides a tabbed interface with the following views:

1. **Workload Registrations**: Lists all registered workloads
2. **Agent Status**: Shows the status of all SPIRE agents
3. **Workload Metrics**: Displays statistics and metrics
4. **Settings**: Allows configuration of connection settings

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

## Cleanup

To delete the minikube clusters:
```
minikube delete -p spire-server-cluster
minikube delete -p workload-cluster
```

## Project Structure

```
.
├── k8s
│   ├── spire-db
│   │   ├── namespace.yaml
│   │   ├── postgres-deployment.yaml
│   │   ├── postgres-pvc.yaml
│   │   └── postgres-service.yaml
│   ├── spire-server
│   │   ├── namespace.yaml
│   │   ├── registration-entries.yaml
│   │   ├── server-configmap.yaml
│   │   ├── server-rbac.yaml
│   │   ├── server-service.yaml
│   │   └── server-statefulset.yaml
│   └── workload-cluster
│       ├── agent-configmap.yaml
│       ├── agent-daemonset.yaml
│       ├── agent-rbac.yaml
│       ├── namespace.yaml
│       ├── service1-deployment.yaml
│       ├── service2-deployment.yaml
│       └── service3-deployment.yaml
└── scripts
    ├── setup-clusters.sh
    └── verify-setup.sh
```
