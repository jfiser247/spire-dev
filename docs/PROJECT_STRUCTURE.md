# SPIFFE/SPIRE Project Structure

This document outlines the organized structure of the SPIFFE/SPIRE local development environment.

## 📁 Repository Structure

```mermaid
graph TD
    subgraph "spire-dev/"
        README[README.md<br/>Main project documentation]
        
        subgraph "docs - All documentation files"
            HELM_DOC[helm_deployment_guide.md<br/>Production Helm deployment]
            PROJ_DOC[project_structure.md<br/>This file]
            SPIFFE_DOC[spiffe_service_integration_guide.md<br/>Service integration guide]
            TROUBLE_DOC[troubleshooting.md<br/>Troubleshooting guide]
        end
        
        subgraph "scripts - All executable scripts"
            FRESH[fresh-install.sh<br/>Complete fresh Mac setup]
            SETUP[setup-clusters.sh<br/>Manual cluster setup]
            VERIFY[verify-setup.sh<br/>Installation verification]
        end
        
        subgraph "web - Web dashboard components"
            SERVER[server.js<br/>Node.js dashboard server]
            START_DASH[start-dashboard.sh<br/>Dashboard startup script]
            WEB_DASH[web-dashboard.html<br/>Dashboard frontend]
        end
        
        subgraph "k8s - Kubernetes manifests"
            subgraph "spire-db"
                DB_COMP[Database components]
            end
            subgraph "spire-server"
                SERVER_COMP[SPIRE server components]
            end
            subgraph "workload-cluster"
                WORKLOAD_COMP[Workload and agent components]
            end
        end
        
        subgraph "helm-charts - Production Helm charts"
            subgraph "spire"
                HELM_CHART[Complete SPIRE Helm chart]
            end
        end
        
        subgraph "src - Java demo application"
            subgraph "main"
                SPRING_APP[Spring Boot demo app]
            end
        end
    end
    
    %% Styling
    classDef doc fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef script fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef web fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef k8s fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef helm fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef src fill:#ffecb3,stroke:#ff8f00,stroke-width:2px
    classDef main fill:#f5f5f5,stroke:#424242,stroke-width:1px
    
    class README,HELM_DOC,PROJ_DOC,SPIFFE_DOC,TROUBLE_DOC doc
    class FRESH,SETUP,VERIFY script
    class SERVER,START_DASH,WEB_DASH web
    class DB_COMP,SERVER_COMP,WORKLOAD_COMP k8s
    class HELM_CHART helm
    class SPRING_APP src
```

## 🎯 Key Components

### **🚀 Entry Points**
- **`./scripts/fresh-install.sh`** - Main entry point for fresh Mac setup
- **`./web/start-dashboard.sh`** - Start real-time monitoring dashboard
- **`README.md`** - Primary documentation and getting started guide

### **📖 Documentation Strategy**
All documentation is centralized in the `docs/` directory:
- **Centralized location** for easy maintenance
- **Clear separation** from code and scripts
- **Linked from README** for discoverability

### **🔧 Scripts Organization**
All executable scripts are in the `scripts/` directory:
- **Consistent location** for all automation
- **Executable permissions** maintained
- **Interdependent scripts** in same location

### **🌐 Web Components**
Web-related files are isolated in the `web/` directory:
- **Self-contained** dashboard application
- **Isolated dependencies** (Node.js, etc.)
- **Clear separation** from infrastructure code

## 🔄 Workflow Patterns

### **Fresh Mac Setup**
1. `./scripts/fresh-install.sh` - Complete environment setup
2. `./web/start-dashboard.sh` - Start monitoring
3. Open `http://localhost:3000/web-dashboard.html`

### **Development Iteration**
1. Make changes to configurations
2. `./scripts/fresh-install.sh` - Reset to clean state
3. Test changes with dashboard

### **Production Deployment**
1. Review `docs/helm_deployment_guide.md`
2. Use Helm charts in `helm-charts/spire/`
3. Adapt configurations for production

## 📊 Best Practices Applied

### **Repository Organization**
- ✅ **Separation of concerns** - docs, scripts, web, k8s separated
- ✅ **Consistent naming** - kebab-case for files and directories
- ✅ **Logical grouping** - related files in same directories
- ✅ **Clear entry points** - obvious starting scripts

### **Documentation Strategy**
- ✅ **Single source of truth** - all docs in `docs/`
- ✅ **Cross-linked** - documents reference each other appropriately
- ✅ **Hierarchical** - README → specific guides
- ✅ **Practical focus** - emphasizes fresh Mac laptop workflow

### **Script Organization**
- ✅ **Executable permissions** maintained across moves
- ✅ **Relative path updates** for new structure
- ✅ **Consistent interfaces** - all scripts callable from project root
- ✅ **Clear dependencies** - scripts reference correct paths

### **Web Application Structure**
- ✅ **Self-contained** - all web files in dedicated directory
- ✅ **Proper path handling** - scripts work from any location
- ✅ **Clear entry point** - single startup script

## 🏢 Enterprise Considerations

This structure supports enterprise adoption by:
- **Clear separation** of development vs production components
- **Documented pathways** from local to enterprise deployment
- **Modular organization** for team collaboration
- **Best practices** that scale to larger projects

The organized structure makes it easy for teams to:
1. **Onboard new developers** with clear entry points
2. **Maintain documentation** in centralized location  
3. **Extend functionality** with consistent patterns
4. **Deploy to production** using organized Helm charts