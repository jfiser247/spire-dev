# SPIRE Architecture Diagrams

This document provides visual representations of both basic and enterprise SPIRE deployments available in this project.

## Basic Development Architecture

### Minikube Cluster Layout

```mermaid
graph TB
    subgraph "BASIC DEVELOPMENT ARCHITECTURE - Single Cluster"
        subgraph "Local Development - minikube cluster"
            subgraph "Context: workload-cluster"
                subgraph "spire-server namespace"
                    SS[SPIRE Server]
                    PG[(MySQL Database)]
                    RE[Registration Entries]
                    
                    SS --> PG
                    SS --> RE
                end
                
                subgraph "spire-system namespace"
                    SA[SPIRE Agent<br/>DaemonSet]
                    WA[Workload Attestation]
                    
                    SA --> WA
                end
                
                subgraph "production namespace"
                    US[User Service]
                    PA[Payment API]
                    IS[Inventory Service]
                    
                    US --> PA
                    PA --> IS
                end
            end
        end
    end
    
    %% Connections
    SA --> SS
    US --> SA
    PA --> SA
    IS --> SA
    
    %% Trust Domain and Role
    TD["Trust Domain: example.org<br/>Cluster Role: Development and Testing"]
    
    %% Styling
    classDef server fill:#ffecb3,stroke:#ff8f00,stroke-width:2px
    classDef database fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef agent fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef workload fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef info fill:#f5f5f5,stroke:#424242,stroke-width:1px
    
    class SS server
    class PG database
    class SA,WA agent
    class US,PA,IS workload
    class TD info
```

### Component Interaction Flow

```mermaid
sequenceDiagram
    participant SA as SPIRE Agent
    participant SS as SPIRE Server
    participant WP as Workload Pod
    participant US as User Service
    participant PA as Payment API
    participant IS as Inventory Service
    
    Note over SA,SS: 1. Agent Registration
    SA->>SS: k8s_psat Token
    SS->>SS: Validates Service Account Token
    SS->>SA: Agent SVID Issued
    
    Note over WP,SS: 2. Workload Attestation
    WP->>SA: Request SVID (Unix Socket)
    SA->>SS: Workload Attestation Request
    SS->>SA: Issues SVID
    SA->>WP: Deliver SVID
    
    Note over US,IS: 3. Service-to-Service Communication
    US->>PA: mTLS + SPIFFE ID
    PA->>IS: mTLS + SPIFFE ID
    IS->>PA: Response
    PA->>US: Response
    
    Note over SS,IS: 4. Certificate Lifecycle
    SS->>SA: Auto-rotation Signal
    SA->>WP: Updates SVIDs
    WP->>WP: Refresh Certificates
```

## Enterprise Multi-Cluster Architecture

### Upstream and Downstream Topology

```mermaid
graph TB
    subgraph "🏢 ENTERPRISE MULTI-CLUSTER ARCHITECTURE (Hierarchical Trust Model)"
        subgraph "🏢 ENTERPRISE ROOT AUTHORITY"
            subgraph "🔒 Upstream SPIRE Cluster"
                subgraph "upstream-spire-cluster"
                    subgraph "Trust Domain: enterprise-root.org"
                        USS[🔐 SPIRE Server<br/>Root CA]
                        UDB[(🗃️ MySQL Database)]
                        UFE[🔗 Federation Endpoint]
                        UCM[⚙️ Controller Manager]
                        
                        USS --> UDB
                        USS --> UFE
                        UCM --> USS
                    end
                end
            end
        end
        
        subgraph "🌍 REGIONAL/WORKLOAD AUTHORITY"
            subgraph "🌐 Downstream SPIRE Cluster"
                subgraph "downstream-spire-cluster"
                    subgraph "Trust Domain: downstream.example.org"
                        DSS[🔐 SPIRE Server<br/>Regional CA]
                        DDB[(🗃️ MySQL Database)]
                        DSA[🤖 SPIRE Agents<br/>DaemonSet]
                        DCM[⚙️ Controller Manager]
                        
                        DSS --> DDB
                        DCM --> DSS
                        DSA --> DSS
                    end
                end
                
                subgraph "spire-downstream namespace"
                    CP[🔧 Control Plane Components]
                    TB[🔗 Trust Bundle Management]
                end
                
                subgraph "downstream-workloads namespace"
                    EA[🏢 Enterprise API]
                    DP[📊 Data Processor]
                    SG[🛡️ Security Gateway]
                end
                
                subgraph "🌐 External Access"
                    SGW[🔒 Security Gateway<br/>NodePort]
                    EXT[🌍 External Traffic Ingress]
                    
                    SGW --> EXT
                end
            end
        end
    end
    
    %% Federation relationship
    UFE -.->|🌐 Federation<br/>Trust Bundle| DSS
    DSS -.->|🌐 Federation<br/>Trust Bundle| UFE
    
    %% Workload connections
    DSA --> EA
    DSA --> DP
    DSA --> SG
    
    %% External access
    SG --> SGW
    
    %% Styling
    classDef upstream fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef downstream fill:#f3e5f5,stroke:#4a148c,stroke-width:3px
    classDef server fill:#ffecb3,stroke:#ff8f00,stroke-width:2px
    classDef database fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef agent fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef workload fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef external fill:#f5f5f5,stroke:#424242,stroke-width:2px
    
    class USS,DSS server
    class UDB,DDB database
    class DSA agent
    class EA,DP,SG workload
    class SGW,EXT external
```

### Trust Hierarchy and Certificate Chain

```mermaid
graph TD
    ECA[External Enterprise CA<br/>Optional] --> USS
    
    subgraph "Trust Hierarchy & Certificate Chain"
        USS[🔒 Upstream SPIRE Server<br/>Root Certificate Authority<br/><br/>• Issues Intermediate Certs<br/>• Manages Trust Policies<br/>• Federation Bundle Endpoint<br/>• Trust Domain: enterprise-root.org]
        
        DSS[🌐 Downstream SPIRE Server<br/>Regional Certificate Authority<br/><br/>• Issues Workload SVIDs<br/>• Local Trust Management<br/>• Agent Attestation<br/>• Trust Domain: downstream.example.org]
        
        subgraph "🏢 Enterprise Workload Services"
            EA[🏢 enterprise-api<br/>SPIFFE ID: spiffe://downstream.example.org/enterprise-api]
            DP[📊 data-processor<br/>SPIFFE ID: spiffe://downstream.example.org/data-processor]
            SG[🛡️ security-gateway<br/>SPIFFE ID: spiffe://downstream.example.org/security-gateway]
        end
    end
    
    USS -->|Intermediate Certificate| DSS
    DSS -->|SVID Certificates| EA
    DSS -->|SVID Certificates| DP
    DSS -->|SVID Certificates| SG
    
    %% Styling
    classDef rootCA fill:#ffcdd2,stroke:#d32f2f,stroke-width:3px
    classDef intermediate fill:#fff3e0,stroke:#ff8f00,stroke-width:2px
    classDef workload fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef optional fill:#f5f5f5,stroke:#757575,stroke-width:1px,stroke-dasharray: 5 5
    
    class ECA optional
    class USS rootCA
    class DSS intermediate
    class EA,DP,SG workload
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
    subgraph "Host Machine (macOS)"
        subgraph "Docker Desktop/Rancher Desktop"
            subgraph "upstream-spire-cluster (minikube)"
                subgraph "spire-upstream namespace"
                    USS_GRPC[spire-upstream-server:8081<br/>GRPC]
                    USS_FED[spire-upstream-server:8443<br/>Federation]
                    USS_DB[spire-upstream-db:5432<br/>Database]
                end
                
                subgraph "NodePort Services - Upstream"
                    NP_31081[31081 → spire-upstream-server:8081]
                    NP_31443[31443 → spire-upstream-server:8443]
                end
                
                USS_GRPC --> NP_31081
                USS_FED --> NP_31443
            end
            
            subgraph "downstream-spire-cluster (minikube)"
                subgraph "spire-downstream namespace"
                    DSS_GRPC[spire-downstream-server:8081<br/>GRPC]
                    DSS_FED[spire-downstream-server:8443<br/>Federation]
                    DSS_DB[spire-downstream-db:5432<br/>Database]
                end
                
                subgraph "downstream-workloads namespace"
                    EA_SVC[enterprise-api:80]
                    DP_SVC[data-processor:80]
                    SG_SVC[security-gateway:8080]
                end
                
                subgraph "NodePort Services - Downstream"
                    NP_32081[32081 → spire-downstream-server:8081]
                    NP_32443[32443 → spire-downstream-server:8443]
                    NP_30080[30080 → security-gateway:8080]
                end
                
                DSS_GRPC --> NP_32081
                DSS_FED --> NP_32443
                SG_SVC --> NP_30080
            end
        end
        
        subgraph "Dashboard Server (Node.js)"
            DASH[localhost:3000<br/>Enterprise Dashboard]
        end
    end
    
    %% Cross-cluster communication
    USS_FED -.->|Federation| DSS_FED
    DSS_FED -.->|Federation| USS_FED
    
    %% Dashboard connections
    DASH -.->|kubectl API| upstream-spire-cluster
    DASH -.->|kubectl API| downstream-spire-cluster
    
    %% Styling
    classDef server fill:#ffecb3,stroke:#ff8f00,stroke-width:2px
    classDef database fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef nodeport fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef dashboard fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    
    class USS_GRPC,USS_FED,DSS_GRPC,DSS_FED server
    class USS_DB,DSS_DB database
    class EA_SVC,DP_SVC,SG_SVC service
    class NP_31081,NP_31443,NP_32081,NP_32443,NP_30080 nodeport
    class DASH dashboard
```

## Service Mesh Integration Points

### SPIFFE Integration Locations

```mermaid
graph TD
    subgraph "Service Mesh Integration Points"
        SM[Service Mesh<br/>Istio/Linkerd/Consul]
        
        subgraph "SPIRE Workload API"
            SWA[SPIRE Workload API<br/><br/>• Automatic SVID Provisioning<br/>• Certificate Rotation<br/>• Trust Bundle Updates<br/>• Identity Validation]
        end
        
        subgraph "Application Workloads"
            ES[Envoy Sidecars]
            AC[Application Containers]
            IC[Init Containers]
            SA[Service Accounts]
        end
        
        SOCKET[Unix Domain Socket<br/>/run/spire/sockets/agent.sock]
    end
    
    SM -->|SPIFFE Integration| SWA
    SWA --> SOCKET
    SOCKET --> ES
    SOCKET --> AC
    SOCKET --> IC
    SOCKET --> SA
    
    %% Styling
    classDef mesh fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef api fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef socket fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef workload fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    
    class SM mesh
    class SWA api
    class SOCKET socket
    class ES,AC,IC,SA workload
```

## Monitoring and Observability

### Dashboard Architecture

```mermaid
graph TD
    subgraph "Dashboard Architecture"
        WB[Web Browser<br/>localhost port 3000]
        
        subgraph "Dashboard Server Node.js Express"
            DS[Dashboard Server<br/>Auto-detects Deployment Type<br/>Real-time Data Fetching<br/>Multi-cluster Support<br/>RESTful API Endpoints]
        end
        
        subgraph "Kubernetes API Servers"
            UAS[upstream-spire-cluster]
            DAS[downstream-spire-cluster]
            WAS[workload-cluster basic]
            CM[Contexts managed by kubectl]
            
            UAS --> CM
            DAS --> CM
            WAS --> CM
        end
    end
    
    WB -->|HTTP WebSocket| DS
    DS -->|kubectl API| UAS
    DS -->|kubectl API| DAS
    DS -->|kubectl API| WAS
    
    %% Styling
    classDef browser fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef server fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef k8s fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class WB browser
    class DS server
    class UAS,DAS,WAS,CM k8s
```

## Security Architecture

### Identity and Access Flow

```mermaid
sequenceDiagram
    participant KN as K8s Node
    participant C as Container
    participant W as Workload
    participant SA as SPIRE Agent
    participant SS as SPIRE Server
    participant SVA as Service A
    participant SVB as Service B
    participant DS as Downstream
    participant US as Upstream
    
    Note over KN,SS: 1. Node Identity (Kubernetes Service Account Token)
    KN->>SS: Service Account JWT
    SS->>SS: Validates Token
    SS->>KN: Node Identity Confirmed
    
    Note over C,SA: 2. Workload Identity (Process/Container Attestation)
    C->>SA: Process Info
    SA->>SA: Validates Selector Rules
    SA->>C: Attestation Complete
    
    Note over W,SA: 3. Service Identity (SPIFFE SVID)
    W->>SA: SVID Request
    SA->>SS: Forward Request
    SS->>SA: Issues X.509 SVID
    SA->>W: Delivers SVID
    
    Note over SVA,SVB: 4. Inter-Service Communication (mTLS)
    SVA->>SVB: mTLS + SPIFFE ID
    SVB->>SVB: Validates Identity
    SVB->>SVA: Response
    
    Note over DS,US: 5. Cross-Cluster Trust (Federation)
    DS->>US: Trust Bundle
    US->>US: Validates Cross-Domain
    US->>DS: Federation Confirmed
```

---

These diagrams provide a comprehensive view of the SPIRE architecture implementations available in this project, from basic development setups to enterprise-grade multi-cluster deployments.