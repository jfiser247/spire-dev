# SPIRE Architecture Diagrams

This document provides visual representations of both basic and enterprise SPIRE deployments available in this project.

## Basic Development Architecture

### Minikube Cluster Layout

```mermaid
graph TB
    subgraph BASIC["🏗️ BASIC DEVELOPMENT ARCHITECTURE"]
        subgraph CLUSTER["📦 minikube workload-cluster"]
            subgraph SERVER_NS["🔐 spire-server namespace"]
                SS[🖥️ SPIRE Server<br/>Trust Authority]
                PG[(🗄️ MySQL Database<br/>Persistent Storage)]
                RE[📋 Registration Entries<br/>Identity Policies]
                
                SS --> PG
                SS --> RE
            end
            
            subgraph SYSTEM_NS["🤖 spire-system namespace"]
                SA[🔧 SPIRE Agent<br/>DaemonSet<br/>Node Identity]
                WA[🛡️ Workload Attestation<br/>Process Validation]
                
                SA --> WA
            end
            
            subgraph WORKLOAD_NS["⚡ spire-workload namespace"]
                US[👤 User Service<br/>User Management API]
                PA[💳 Payment API<br/>Payment Processing]
                IS[📦 Inventory Service<br/>Stock Management]
                
                US --> PA
                PA --> IS
            end
        end
    end
    
    %% Cross-namespace connections
    SA -.->|Authenticates| SS
    US -.->|Gets SVID from| SA
    PA -.->|Gets SVID from| SA  
    IS -.->|Gets SVID from| SA
    
    %% Trust domain info
    subgraph INFO["ℹ️ Trust Configuration"]
        TD[🌐 Trust Domain: example.org<br/>🎯 Role: Development & Testing<br/>🔒 Security: Privileged Pods]
    end
    
    %% Styling for better visual separation
    classDef serverStyle fill:#fff8e1,stroke:#f57f17,stroke-width:3px,color:#e65100
    classDef databaseStyle fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#1b5e20
    classDef agentStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#4a148c
    classDef workloadStyle fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#0d47a1
    classDef infoStyle fill:#fafafa,stroke:#616161,stroke-width:2px,color:#424242
    classDef namespaceStyle fill:#f5f5f5,stroke:#757575,stroke-width:2px
    
    class SS serverStyle
    class PG databaseStyle
    class SA,WA agentStyle
    class US,PA,IS workloadStyle
    class RE,TD infoStyle
    
    %% Namespace styling
    class SERVER_NS,SYSTEM_NS,WORKLOAD_NS namespaceStyle
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
    subgraph ENTERPRISE["🏢 ENTERPRISE MULTI-CLUSTER ARCHITECTURE"]
        
        subgraph ROOT_AUTH["🔒 ENTERPRISE ROOT AUTHORITY"]
            subgraph UPSTREAM_CLUSTER["🔐 upstream-spire-cluster"]
                USS[🏛️ SPIRE Server<br/>Root Certificate Authority<br/>Trust Domain: enterprise-root.org]
                UDB[(🗄️ MySQL Database<br/>Root CA Storage<br/>Certificate Policies)]
                UFE[🌐 Federation Endpoint<br/>Trust Bundle Distribution<br/>Cross-Cluster Auth)]
                UCM[⚙️ Controller Manager<br/>Policy Enforcement<br/>Lifecycle Management]
                
                USS --> UDB
                USS --> UFE
                UCM --> USS
            end
        end
        
        subgraph REGIONAL_AUTH["⚡ REGIONAL/WORKLOAD AUTHORITY"]
            subgraph DOWNSTREAM_CLUSTER["🌐 downstream-spire-cluster"]
                DSS[🏢 SPIRE Server<br/>Regional Certificate Authority<br/>Trust Domain: downstream.example.org]
                DDB[(🗄️ MySQL Database<br/>Regional CA Storage<br/>Workload Identities)]
                DSA[🤖 SPIRE Agents<br/>DaemonSet<br/>Node Attestation]
                DCM[⚙️ Controller Manager<br/>Regional Policy Management]
                
                DSS --> DDB
                DCM --> DSS
                DSA --> DSS
            end
            
            subgraph CONTROL_PLANE["🔧 spire-downstream namespace"]
                CP[🔧 Control Plane<br/>Configuration Management]
                TB[🔗 Trust Bundle Management<br/>Federation State]
            end
            
            subgraph WORKLOADS["⚡ downstream-workloads namespace"] 
                EA[🏢 Enterprise API<br/>Business Logic Services<br/>Customer Management]
                DP[📊 Data Processor<br/>Analytics & Reporting<br/>Data Transformation]
                SG[🛡️ Security Gateway<br/>Access Control<br/>Traffic Management]
            end
            
            subgraph EXTERNAL["🌍 External Access Layer"]
                SGW[🔒 Security Gateway<br/>NodePort Service<br/>External Load Balancer]
                EXT[🌍 External Traffic<br/>Internet Ingress<br/>API Gateway]
                
                SGW --> EXT
            end
        end
    end
    
    %% Federation relationships
    UFE -.->|🔐 Trust Bundle Exchange<br/>Certificate Chain Validation| DSS
    DSS -.->|🔐 Cross-Domain Authentication<br/>Identity Federation| UFE
    
    %% Workload identity provisioning
    DSA -.->|🎟️ Issues SPIFFE SVIDs| EA
    DSA -.->|🎟️ Issues SPIFFE SVIDs| DP
    DSA -.->|🎟️ Issues SPIFFE SVIDs| SG
    
    %% External access flow
    SG --> SGW
    
    %% Enhanced styling with better contrast
    classDef upstreamStyle fill:#e3f2fd,stroke:#0d47a1,stroke-width:4px,color:#01579b
    classDef downstreamStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:4px,color:#6a1b9a
    classDef serverStyle fill:#fff8e1,stroke:#f57c00,stroke-width:3px,color:#e65100
    classDef databaseStyle fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#1b5e20
    classDef agentStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px,color:#bf360c
    classDef workloadStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px,color:#880e4f
    classDef externalStyle fill:#f5f5f5,stroke:#424242,stroke-width:3px,color:#212121
    classDef namespaceStyle fill:#fafafa,stroke:#757575,stroke-width:2px
    
    class USS,DSS serverStyle
    class UDB,DDB databaseStyle
    class DSA,UCM,DCM agentStyle
    class EA,DP,SG workloadStyle
    class SGW,EXT,UFE externalStyle
    class CP,TB workloadStyle
    
    %% Cluster and namespace containers
    class UPSTREAM_CLUSTER upstreamStyle
    class DOWNSTREAM_CLUSTER,CONTROL_PLANE,WORKLOADS,EXTERNAL downstreamStyle
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
    subgraph HOST["💻 Host Machine - macOS"]
        subgraph DOCKER["🐳 Docker Desktop Container Runtime"]
            
            subgraph UPSTREAM["🔒 upstream-spire-cluster"]
                subgraph UP_NS["🔐 spire-upstream namespace"]
                    USS_GRPC[🖥️ spire-upstream-server<br/>Port: 8081 (gRPC)<br/>Certificate Authority]
                    USS_FED[🌐 spire-upstream-server<br/>Port: 8443 (Federation)<br/>Trust Bundle Endpoint]  
                    USS_DB[🗄️ spire-upstream-db<br/>Port: 5432<br/>PostgreSQL Database]
                end
                
                subgraph UP_PORTS["🌍 NodePort Services"]
                    NP_31081[🔗 31081 → 8081<br/>External gRPC Access]
                    NP_31443[🔗 31443 → 8443<br/>External Federation]
                end
            end
            
            subgraph DOWNSTREAM["⚡ downstream-spire-cluster"]
                subgraph DOWN_NS["🔐 spire-downstream namespace"]
                    DSS_GRPC[🖥️ spire-downstream-server<br/>Port: 8081 (gRPC)<br/>Regional Authority]
                    DSS_FED[🌐 spire-downstream-server<br/>Port: 8443 (Federation)<br/>Trust Validation]
                    DSS_DB[🗄️ spire-downstream-db<br/>Port: 5432<br/>PostgreSQL Database]
                end
                
                subgraph DOWN_WL["⚡ downstream-workloads namespace"]
                    EA_SVC[🏢 enterprise-api<br/>Port: 80<br/>Business Logic API]
                    DP_SVC[📊 data-processor<br/>Port: 80<br/>Data Processing Service]
                    SG_SVC[🛡️ security-gateway<br/>Port: 8080<br/>Security Gateway]
                end
                
                subgraph DOWN_PORTS["🌍 NodePort Services"]
                    NP_32081[🔗 32081 → 8081<br/>External gRPC Access]
                    NP_32443[🔗 32443 → 8443<br/>External Federation]
                    NP_30080[🔗 30080 → 8080<br/>External Gateway Access]
                end
            end
        end
        
        subgraph DASHBOARD["🖥️ Management Interface"]
            DASH[📊 Dashboard Server<br/>localhost:3000<br/>Enterprise Monitoring<br/>Multi-cluster Management]
        end
    end
    
    %% Internal service connections
    USS_GRPC --> NP_31081
    USS_FED --> NP_31443
    DSS_GRPC --> NP_32081
    DSS_FED --> NP_32443
    SG_SVC --> NP_30080
    
    %% Cross-cluster federation
    USS_FED -.->|🔐 Trust Bundle Exchange| DSS_FED
    DSS_FED -.->|🔐 Certificate Validation| USS_FED
    
    %% Dashboard monitoring connections
    DASH -.->|📈 kubectl API Monitoring| UPSTREAM
    DASH -.->|📈 kubectl API Monitoring| DOWNSTREAM
    
    %% Enhanced styling
    classDef serverStyle fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#e65100
    classDef databaseStyle fill:#e8f5e8,stroke:#388e3c,stroke-width:3px,color:#1b5e20
    classDef serviceStyle fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#0d47a1
    classDef nodeportStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px,color:#880e4f
    classDef dashboardStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#4a148c
    classDef namespaceStyle fill:#f8f9fa,stroke:#6c757d,stroke-width:2px
    classDef clusterStyle fill:#fff8e1,stroke:#ff8f00,stroke-width:2px
    
    class USS_GRPC,USS_FED,DSS_GRPC,DSS_FED serverStyle
    class USS_DB,DSS_DB databaseStyle
    class EA_SVC,DP_SVC,SG_SVC serviceStyle
    class NP_31081,NP_31443,NP_32081,NP_32443,NP_30080 nodeportStyle
    class DASH dashboardStyle
    
    %% Container and namespace styling  
    class UP_NS,DOWN_NS,DOWN_WL,UP_PORTS,DOWN_PORTS namespaceStyle
    class UPSTREAM,DOWNSTREAM clusterStyle
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
    subgraph DASHBOARD_ARCH["📊 Dashboard Architecture Overview"]
        subgraph CLIENT_LAYER["🌐 Client Access Layer"]
            WB[🌐 Web Browser<br/>localhost:3000<br/>Real-time Dashboard UI<br/>Multi-tab Interface]
        end
        
        subgraph SERVER_LAYER["🖥️ Backend Server Layer"]
            DS[🚀 Dashboard Server<br/>Node.js Express Application<br/>• Auto-detects Deployment Type<br/>• Real-time Data Fetching<br/>• Multi-cluster Support<br/>• RESTful API Endpoints<br/>• WebSocket Communication]
        end
        
        subgraph K8S_LAYER["☸️ Kubernetes Integration Layer"]
            UAS[🔒 upstream-spire-cluster<br/>Enterprise Root Authority<br/>Trust Domain: enterprise-root.org]
            DAS[⚡ downstream-spire-cluster<br/>Regional Workload Authority<br/>Trust Domain: downstream.example.org]
            WAS[🛠️ workload-cluster<br/>Basic Development Environment<br/>Trust Domain: example.org]
            
            subgraph KUBECTL_LAYER["🔧 kubectl Context Management"]
                CM[📋 kubectl Contexts<br/>• Configuration Management<br/>• Cluster Authentication<br/>• API Server Routing]
            end
            
            UAS -.-> CM
            DAS -.-> CM  
            WAS -.-> CM
        end
    end
    
    %% Communication flows
    WB -->|📡 HTTP/WebSocket<br/>Real-time Updates| DS
    DS -->|☸️ kubectl API Calls<br/>Pod Data Retrieval| UAS
    DS -->|☸️ kubectl API Calls<br/>Service Monitoring| DAS
    DS -->|☸️ kubectl API Calls<br/>Development Data| WAS
    
    %% Enhanced styling
    classDef browserStyle fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#0d47a1
    classDef serverStyle fill:#fff8e1,stroke:#f57c00,stroke-width:3px,color:#e65100
    classDef k8sStyle fill:#e8f5e8,stroke:#388e3c,stroke-width:3px,color:#1b5e20
    classDef mgmtStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#4a148c
    classDef layerStyle fill:#fafafa,stroke:#757575,stroke-width:2px
    
    class WB browserStyle
    class DS serverStyle
    class UAS,DAS,WAS k8sStyle
    class CM mgmtStyle
    
    %% Layer containers
    class CLIENT_LAYER,SERVER_LAYER,K8S_LAYER,KUBECTL_LAYER layerStyle
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