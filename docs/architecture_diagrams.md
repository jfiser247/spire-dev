# SPIRE Architecture Diagrams

This document provides visual representations of both basic and enterprise SPIRE deployments available in this project.

## Basic Development Architecture

### Minikube Cluster Layout

```mermaid
graph TB
    SS[SPIRE Server]
    PG[(MySQL Database)]
    RE[Registration Entries]
    SA[SPIRE Agent]
    WA[Workload Attestation]
    US[User Service]
    PA[Payment API]
    IS[Inventory Service]
    
    SS --> PG
    SS --> RE
    SA --> WA
    US --> PA
    PA --> IS
    
    SA -.-> SS
    US -.-> SA
    PA -.-> SA  
    IS -.-> SA
```

### Component Interaction Flow

```mermaid
flowchart TD
    SA["SPIRE Agent"]
    SS["SPIRE Server"]
    WP["Workload Pod"]
    US["User Service"]
    PA["Payment API"]
    IS["Inventory Service"]
    
    subgraph REG["1. Agent Registration"]
        SA -->|"k8s_psat Token"| SS
        SS -->|"Validates Token"| SS
        SS -->|"Agent SVID"| SA
    end
    
    subgraph ATT["2. Workload Attestation"]
        WP -->|"Request SVID"| SA
        SA -->|"Attestation Request"| SS
        SS -->|"Issues SVID"| SA
        SA -->|"Deliver SVID"| WP
    end
    
    subgraph COMM["3. Service Communication"]
        US -->|"mTLS with SPIFFE ID"| PA
        PA -->|"mTLS with SPIFFE ID"| IS
        IS -->|"Response"| PA
        PA -->|"Response"| US
    end
    
    subgraph LIFE["4. Certificate Lifecycle"]
        SS -->|"Auto-rotation Signal"| SA
        SA -->|"Updates SVIDs"| WP
        WP -->|"Refresh Certificates"| WP
    end
```

## Enterprise Multi-Cluster Architecture

### Upstream and Downstream Topology

```mermaid
graph TB
    USS[SPIRE Server Upstream]
    UDB[(MySQL Database Upstream)]
    UFE[Federation Endpoint]
    UCM[Controller Manager Upstream]
    
    DSS[SPIRE Server Downstream]
    DDB[(MySQL Database Downstream)]
    DSA[SPIRE Agents]
    DCM[Controller Manager Downstream]
    
    EA[Enterprise API]
    DP[Data Processor]
    SG[Security Gateway]
    
    USS --> UDB
    USS --> UFE
    UCM --> USS
    
    DSS --> DDB
    DCM --> DSS
    DSA --> DSS
    
    UFE -.-> DSS
    DSS -.-> UFE
    
    DSA -.-> EA
    DSA -.-> DP
    DSA -.-> SG
```

### Trust Hierarchy and Certificate Chain

```mermaid
graph TD
    ECA[External Enterprise CA] --> USS
    USS[Upstream SPIRE Server]
    DSS[Downstream SPIRE Server]
    EA[enterprise-api]
    DP[data-processor]
    SG[security-gateway]
    
    USS --> DSS
    DSS --> EA
    DSS --> DP
    DSS --> SG
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

```mermaid
graph TB
    USS_GRPC[spire-upstream-server gRPC]
    USS_FED[spire-upstream-server Federation]  
    USS_DB[spire-upstream-db]
    NP_31081[NodePort 31081]
    NP_31443[NodePort 31443]
    
    DSS_GRPC[spire-downstream-server gRPC]
    DSS_FED[spire-downstream-server Federation]
    DSS_DB[spire-downstream-db]
    EA_SVC[enterprise-api]
    DP_SVC[data-processor]
    SG_SVC[security-gateway]
    NP_32081[NodePort 32081]
    NP_32443[NodePort 32443]
    NP_30080[NodePort 30080]
    
    DASH[Dashboard Server]
    
    USS_GRPC --> NP_31081
    USS_FED --> NP_31443
    DSS_GRPC --> NP_32081
    DSS_FED --> NP_32443
    SG_SVC --> NP_30080
    
    USS_FED -.-> DSS_FED
    DSS_FED -.-> USS_FED
    
    DASH -.-> USS_GRPC
    DASH -.-> DSS_GRPC
```

## Service Mesh Integration Points

### SPIFFE Integration Locations

```mermaid
graph TD
    SM[Service Mesh]
    SWA[SPIRE Workload API]
    ES[Envoy Sidecars]
    AC[Application Containers]
    IC[Init Containers]
    SA[Service Accounts]
    SOCKET[Unix Domain Socket]
    
    SM --> SWA
    SWA --> SOCKET
    SOCKET --> ES
    SOCKET --> AC
    SOCKET --> IC
    SOCKET --> SA
```

## Monitoring and Observability

### Dashboard Architecture

```mermaid
graph TD
    WB[Web Browser]
    DS[Dashboard Server]
    UAS[upstream-spire-cluster]
    DAS[downstream-spire-cluster]
    WAS[workload-cluster]
    CM[kubectl Contexts]
    
    UAS -.-> CM
    DAS -.-> CM  
    WAS -.-> CM
    
    WB --> DS
    DS --> UAS
    DS --> DAS
    DS --> WAS
```

## Security Architecture

### Identity and Access Flow

```mermaid
graph TD
    KN[K8s Node]
    C[Container]
    W[Workload]
    SA[SPIRE Agent]
    SS[SPIRE Server]
    SVA[Service A]
    SVB[Service B]
    DS[Downstream]
    US[Upstream]
    
    KN --> SS
    SS --> KN
    C --> SA
    SA --> C
    W --> SA
    SA --> SS
    SS --> SA
    SA --> W
    SVA --> SVB
    SVB --> SVA
    DS --> US
    US --> DS
```

---

These diagrams provide a comprehensive view of the SPIRE architecture implementations available in this project, from basic development setups to enterprise-grade multi-cluster deployments.