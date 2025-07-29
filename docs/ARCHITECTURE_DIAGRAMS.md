# SPIRE Architecture Diagrams

This document provides visual representations of both basic and enterprise SPIRE deployments available in this project.

## Basic Development Architecture

### Minikube Cluster Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BASIC DEVELOPMENT ARCHITECTURE                       │
│                              (Single Cluster)                              │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │        🖥️  Local Development       │
                    │         minikube cluster            │
                    │     Context: workload-cluster       │
                    └─────────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐            ┌───────────────┐            ┌───────────────┐
│ spire-server  │            │ spire-system  │            │  production   │
│   namespace   │            │   namespace   │            │   namespace   │
├───────────────┤            ├───────────────┤            ├───────────────┤
│ 🔐 SPIRE      │            │ 🤖 SPIRE      │            │ 👤 User       │
│    Server     │◄───────────┤    Agent      │◄───────────│    Service    │
│               │            │  (DaemonSet)  │            │               │
│ 🗃️ PostgreSQL │            │               │            │ 💳 Payment    │
│   Database    │            │ 🔗 Workload   │            │    API        │
│               │            │   Attestation │            │               │
│ 📋 Reg.       │            │               │            │ 📦 Inventory  │
│   Entries     │            │               │            │    Service    │
└───────────────┘            └───────────────┘            └───────────────┘

Trust Domain: example.org
Cluster Role: Development and Testing
```

### Component Interaction Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPONENT INTERACTION FLOW                          │
└─────────────────────────────────────────────────────────────────────────────┘

1. Agent Registration
   SPIRE Agent ──(k8s_psat)──► SPIRE Server ──► Validates Service Account Token

2. Workload Attestation  
   Workload Pod ──(Unix Socket)──► SPIRE Agent ──► SPIRE Server ──► Issues SVID

3. Service-to-Service Communication
   User Service ──(mTLS + SPIFFE)──► Payment API ──(mTLS + SPIFFE)──► Inventory

4. Certificate Lifecycle
   SPIRE Server ──(Auto-rotation)──► Updates SVIDs ──► Workloads Refresh Certs
```

## Enterprise Multi-Cluster Architecture

### Upstream and Downstream Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ENTERPRISE MULTI-CLUSTER ARCHITECTURE                  │
│                         (Hierarchical Trust Model)                         │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │    🏢 ENTERPRISE ROOT AUTHORITY    │
                    │                                     │
                    │   🔒 Upstream SPIRE Cluster        │
                    │   Trust Domain: enterprise-root.org│
                    │   Context: upstream-spire-cluster   │
                    │                                     │
                    │ ┌─────────────────────────────────┐ │
                    │ │    🔐 SPIRE Server (Root CA)   │ │
                    │ │    🗃️ PostgreSQL Database      │ │
                    │ │    🔗 Federation Endpoint      │ │
                    │ │    ⚙️ Controller Manager       │ │
                    │ └─────────────────────────────────┘ │
                    └─────────────────────────────────────┘
                                      │
                               🌐 Federation
                               (Trust Bundle)
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │  🌍 REGIONAL/WORKLOAD AUTHORITY    │
                    │                                     │
                    │  🌐 Downstream SPIRE Cluster       │
                    │  Trust Domain: downstream.example.org│
                    │  Context: downstream-spire-cluster  │
                    │                                     │
                    │ ┌─────────────────────────────────┐ │
                    │ │  🔐 SPIRE Server (Regional CA) │ │
                    │ │  🗃️ PostgreSQL Database        │ │
                    │ │  🤖 SPIRE Agents (DaemonSet)   │ │
                    │ │  ⚙️ Controller Manager         │ │
                    │ └─────────────────────────────────┘ │
                    └─────────────────────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐            ┌───────────────┐            ┌───────────────┐
│spire-downstream│           │downstream-workloads        │  🌐 External  │
│   namespace   │            │   namespace   │            │    Access     │
├───────────────┤            ├───────────────┤            ├───────────────┤
│ 🔧 Control    │            │ 🏢 Enterprise │            │ 🔒 Security   │
│   Plane       │            │    API        │            │   Gateway     │
│   Components  │            │               │            │ (NodePort)    │
│               │            │ 📊 Data       │            │               │
│ 🔗 Trust      │            │   Processor   │            │ 🌍 External   │
│   Bundle      │            │               │            │   Traffic     │
│   Management  │            │ 🛡️ Security   │            │   Ingress     │
│               │            │   Gateway     │            │               │
└───────────────┘            └───────────────┘            └───────────────┘
```

### Trust Hierarchy and Certificate Chain

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TRUST HIERARCHY & CERTIFICATE CHAIN                  │
└─────────────────────────────────────────────────────────────────────────────┘

External Enterprise CA (Optional)
         │
         ▼
┌─────────────────────────────────────┐
│  🔒 Upstream SPIRE Server          │
│  (Root Certificate Authority)       │
│                                     │
│  • Issues Intermediate Certs        │
│  • Manages Trust Policies          │
│  • Federation Bundle Endpoint      │
│  • Trust Domain: enterprise-root.org│
└─────────────────────────────────────┘
         │
         │ Intermediate Certificate
         ▼
┌─────────────────────────────────────┐
│  🌐 Downstream SPIRE Server        │
│  (Regional Certificate Authority)   │
│                                     │
│  • Issues Workload SVIDs           │
│  • Local Trust Management          │
│  • Agent Attestation               │
│  • Trust Domain: downstream.example.org│
└─────────────────────────────────────┘
         │
         │ SVID Certificates
         ▼
┌─────────────────────────────────────┐
│  🏢 Enterprise Workload Services   │
│                                     │
│  • enterprise-api                  │
│    SPIFFE ID: spiffe://downstream.example.org/enterprise-api│
│  • data-processor                  │
│    SPIFFE ID: spiffe://downstream.example.org/data-processor│
│  • security-gateway                │
│    SPIFFE ID: spiffe://downstream.example.org/security-gateway│
└─────────────────────────────────────┘
```

## Minikube Cluster Details

### Basic Development Clusters

| Cluster | Profile | Resources | Purpose |
|---------|---------|-----------|---------|
| workload-cluster | Default | 2 CPU, 2GB RAM | Development and testing |

### Enterprise Clusters

| Cluster | Profile | Resources | Purpose |
|---------|---------|-----------|---------|
| upstream-spire-cluster | upstream-spire-cluster | 2 CPU, 3GB RAM | Root Certificate Authority |
| downstream-spire-cluster | downstream-spire-cluster | 2 CPU, 3GB RAM | Regional Authority + Workloads |

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              NETWORK TOPOLOGY                               │
└─────────────────────────────────────────────────────────────────────────────┘

Host Machine (macOS)
├── Docker Desktop/Rancher Desktop
│   ├── upstream-spire-cluster (minikube)
│   │   ├── spire-upstream namespace
│   │   │   ├── spire-upstream-server:8081 (GRPC)
│   │   │   ├── spire-upstream-server:8443 (Federation)
│   │   │   └── spire-upstream-db:5432 (Database)
│   │   └── NodePort Services
│   │       ├── 31081 → spire-upstream-server:8081
│   │       └── 31443 → spire-upstream-server:8443
│   │
│   └── downstream-spire-cluster (minikube)
│       ├── spire-downstream namespace
│       │   ├── spire-downstream-server:8081 (GRPC)
│       │   ├── spire-downstream-server:8443 (Federation)
│       │   └── spire-downstream-db:5432 (Database)
│       ├── downstream-workloads namespace
│       │   ├── enterprise-api:80
│       │   ├── data-processor:80
│       │   └── security-gateway:8080
│       └── NodePort Services
│           ├── 32081 → spire-downstream-server:8081
│           ├── 32443 → spire-downstream-server:8443
│           └── 30080 → security-gateway:8080
│
└── Dashboard Server (Node.js)
    └── localhost:3000 → Enterprise Dashboard
```

## Service Mesh Integration Points

### SPIFFE Integration Locations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SERVICE MESH INTEGRATION POINTS                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────┐
│          Service Mesh               │
│      (Istio/Linkerd/Consul)        │
└─────────────────────────────────────┘
                  │
                  │ SPIFFE Integration
                  ▼
┌─────────────────────────────────────┐
│        SPIRE Workload API           │
│                                     │
│  • Automatic SVID Provisioning     │
│  • Certificate Rotation            │
│  • Trust Bundle Updates            │
│  • Identity Validation             │
└─────────────────────────────────────┘
                  │
                  │ Unix Domain Socket
                  │ /run/spire/sockets/agent.sock
                  ▼
┌─────────────────────────────────────┐
│       Application Workloads        │
│                                     │
│  • Envoy Sidecars                  │
│  • Application Containers          │
│  • Init Containers                 │
│  • Service Accounts                │
└─────────────────────────────────────┘
```

## Monitoring and Observability

### Dashboard Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DASHBOARD ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────┐
│         Web Browser                 │
│    http://localhost:3000            │
└─────────────────────────────────────┘
                  │
                  │ HTTP/WebSocket
                  ▼
┌─────────────────────────────────────┐
│      Dashboard Server               │
│      (Node.js + Express)            │
│                                     │
│  • Auto-detects Deployment Type    │
│  • Real-time Data Fetching         │
│  • Multi-cluster Support           │
│  • RESTful API Endpoints           │
└─────────────────────────────────────┘
                  │
                  │ kubectl API calls
                  ▼
┌─────────────────────────────────────┐
│    Kubernetes API Servers          │
│                                     │
│  • upstream-spire-cluster          │
│  • downstream-spire-cluster        │
│  • workload-cluster (basic)        │
│                                     │
│  Contexts managed by kubectl       │
└─────────────────────────────────────┘
```

## Security Architecture

### Identity and Access Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY & IDENTITY FLOW                          │
└─────────────────────────────────────────────────────────────────────────────┘

1. Node Identity (Kubernetes Service Account Token)
   K8s Node ──(Service Account JWT)──► SPIRE Server ──► Validates Token

2. Workload Identity (Process/Container Attestation)
   Container ──(Process Info)──► SPIRE Agent ──► Validates Selector Rules

3. Service Identity (SPIFFE SVID)
   Workload ──(SVID Request)──► SPIRE Agent ──► Issues X.509 SVID

4. Inter-Service Communication (mTLS)
   Service A ──(mTLS + SPIFFE ID)──► Service B ──► Validates Identity

5. Cross-Cluster Trust (Federation)
   Downstream ──(Trust Bundle)──► Upstream ──► Validates Cross-Domain
```

---

These diagrams provide a comprehensive view of the SPIRE architecture implementations available in this project, from basic development setups to enterprise-grade multi-cluster deployments.