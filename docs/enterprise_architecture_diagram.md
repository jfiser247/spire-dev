# Enterprise SPIRE Architecture Diagram

This document provides detailed diagrams of the enterprise SPIRE deployment architecture, showing the relationship between SPIRE servers, agents, databases, and workloads across upstream and downstream clusters.

> **⚠️ Prerequisites**: This architecture is created by running:
> ```bash
> ./scripts/fresh-install.sh enterprise
> ```
> **Clusters created**: `upstream-spire-cluster` + `downstream-spire-cluster`

## Enterprise Multi-Cluster Architecture

```mermaid
graph TB
    US[SPIRE Server Upstream]
    UDB[(MySQL Database Upstream)]
    UCM[Controller Manager Upstream]
    UFE[Federation Endpoint Upstream]
    UNP[NodePort 31081]
    UNFP[NodePort 31443]
    
    DS[SPIRE Server Downstream]
    DDB[(MySQL Database Downstream)]
    DCM[Controller Manager Downstream]
    DFE[Federation Endpoint Downstream]
    DA1[SPIRE Agent 1]
    DA2[SPIRE Agent 2]
    DA3[SPIRE Agent 3]
    WDA1[Workload Agent 1]
    WDA2[Workload Agent 2]
    WDA3[Workload Agent 3]
    
    EA[Enterprise API]
    DP[Data Processor]
    SG[Security Gateway]
    
    DNP[NodePort 32081]
    DNFP[NodePort 32443]
    DSGP[NodePort 30080]
    
    EXT[External Clients]
    DEV[Developers]
    DASH[Dashboard]
    SM[Service Mesh]
    CI[CI/CD Pipeline]
    MON[Monitoring]
    
    US --> UDB
    US --> UFE
    UCM --> US
    US --> UNP
    UFE --> UNFP
    
    DS --> DDB
    DS --> DFE
    DCM --> DS
    DS --> DNP
    DFE --> DNFP
    SG --> DSGP
    
    DA1 --> DS
    DA2 --> DS
    DA3 --> DS
    WDA1 --> DS
    WDA2 --> DS
    WDA3 --> DS
    
    EA --> WDA1
    EA --> WDA2
    DP --> WDA1
    SG --> WDA3
    
    UFE -.-> DFE
    DFE -.-> UFE
    DS -.-> US
    
    EXT --> DSGP
    DEV --> DASH
    DASH -.-> US
    DASH -.-> DS
    
    SM -.-> WDA1
    SM -.-> WDA2
    SM -.-> WDA3
    CI -.-> DS
    MON -.-> US
    MON -.-> DS
```

## Component Interaction Flow

```mermaid
graph TD
    K8s[Kubernetes Node]
    DA[SPIRE Agent]
    DS[SPIRE Server Downstream]  
    US[SPIRE Server Upstream]
    W[Workload Pod]
    API[Enterprise API]
    
    K8s --> DA
    DA --> DS
    DS --> DA
    DS --> US
    US --> DS
    W --> DA
    DA --> DS
    DS --> DA
    DA --> W
    US --> DS
    DS --> US
    API --> DA
    DA --> API
    API --> W
    W --> API
    DS --> DA
    DA --> W
    W --> W
```

## Trust Domain Architecture

```mermaid
graph TD
    ROOT[Enterprise Root CA]
    US_TD[Upstream SPIRE Server]
    DS_TD[Downstream SPIRE Server]
    EA_ID[Enterprise API]
    DP_ID[Data Processor]
    SG_ID[Security Gateway]
    FB[Trust Bundle Exchange]
    
    ROOT --> US_TD
    US_TD --> DS_TD
    DS_TD --> EA_ID
    DS_TD --> DP_ID  
    DS_TD --> SG_ID
    US_TD --> FB
    DS_TD --> FB
    FB --> US_TD
    FB --> DS_TD
```

## Data Flow Architecture

```mermaid
graph LR
    US_API[SPIRE Server API Upstream]
    US_FED[Federation API Upstream]
    US_DB[(MySQL Upstream)]
    
    DS_API[SPIRE Server API Downstream]
    DS_FED[Federation API Downstream]
    DS_DB[(MySQL Downstream)]
    
    AG1[Agent 1]
    AG2[Agent 2]
    AG3[Agent 3]
    
    WL1[Enterprise API]
    WL2[Data Processor]
    WL3[Security Gateway]
    
    CLIENT[External Client]
    DASHBOARD[Enterprise Dashboard]
    
    US_API --> US_DB
    US_API --> US_FED
    DS_API --> DS_DB
    DS_API --> DS_FED
    
    DS_API --> AG1
    DS_API --> AG2
    DS_API --> AG3
    
    AG1 -.-> WL1
    AG2 -.-> WL2
    AG3 -.-> WL3
    
    US_FED -.-> DS_FED
    DS_FED -.-> US_FED
    DS_API -.-> US_API
    
    CLIENT --> WL3
    DASHBOARD -.-> US_API
    DASHBOARD -.-> DS_API
```

## Kubernetes Resource Architecture

```mermaid
graph TB
    U_NS[Namespace spire-upstream]
    U_SS[StatefulSet spire-upstream-server]
    U_SVC[Service spire-upstream-server]
    U_CM[ConfigMap spire-upstream-server-config]
    U_SA[ServiceAccount spire-upstream-server]
    U_CR[ClusterRole spire-upstream-server-role]
    U_CRB[ClusterRoleBinding spire-upstream-server-binding]
    U_DEP[Deployment spire-upstream-db]
    U_PVC[PVC spire-upstream-db-pvc]
    
    D_NS[Namespace spire-downstream]
    D_SS[StatefulSet spire-downstream-server]
    D_SVC[Service spire-downstream-server]
    D_CM[ConfigMap spire-downstream-server-config]
    D_SA[ServiceAccount spire-downstream-server]
    D_CR[ClusterRole spire-downstream-server-role]
    D_CRB[ClusterRoleBinding spire-downstream-server-binding]
    D_DEP[Deployment spire-downstream-db]
    D_PVC[PVC spire-downstream-db-pvc]
    D_DS[DaemonSet spire-downstream-agent]
    
    W_NS[Namespace downstream-workloads]
    W_DS[DaemonSet spire-downstream-agent]
    W_DEP1[Deployment enterprise-api]
    W_DEP2[Deployment data-processor] 
    W_DEP3[Deployment security-gateway]
    W_SVC1[Service enterprise-api]
    W_SVC2[Service data-processor]
    W_SVC3[Service security-gateway]
    W_SA[ServiceAccount spire-downstream-agent]
    
    U_NS --> U_SS
    U_NS --> U_SVC
    U_NS --> U_CM
    U_NS --> U_SA
    U_NS --> U_DEP
    U_NS --> U_PVC
    U_SA --> U_CR
    U_CR --> U_CRB
    U_SS --> U_CM
    U_SS --> U_SA
    U_DEP --> U_PVC
    
    D_NS --> D_SS
    D_NS --> D_SVC
    D_NS --> D_CM
    D_NS --> D_SA
    D_NS --> D_DEP
    D_NS --> D_PVC
    D_NS --> D_DS
    D_SA --> D_CR
    D_CR --> D_CRB
    D_SS --> D_CM
    D_SS --> D_SA
    D_DEP --> D_PVC
    D_DS --> D_SA
    
    W_NS --> W_DS
    W_NS --> W_DEP1
    W_NS --> W_DEP2
    W_NS --> W_DEP3
    W_NS --> W_SVC1
    W_NS --> W_SVC2
    W_NS --> W_SVC3
    W_NS --> W_SA
    W_DS --> W_SA
    W_DEP1 --> W_SVC1
    W_DEP2 --> W_SVC2
    W_DEP3 --> W_SVC3
```