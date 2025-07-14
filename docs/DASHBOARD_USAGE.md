# SPIRE Dashboard Usage Guide

**🍎 Fresh Mac Install → 🔬 Local Testing → 🏢 Enterprise Monitoring**

## Real-Time Pod Data Dashboard

### 💻 Perfect for Fresh Mac Laptop Development
The SPIRE monitoring dashboard works immediately after a **fresh Mac laptop setup**, connecting directly to your newly created **minikube clusters** and providing real-time pod data that's perfect for:
- **Fresh environment testing** of SPIFFE identity propagation
- **Rapid iteration** during development 
- **Debugging** agent connectivity issues on a clean Mac
- **Validating** fresh installation success instantly

### 🚀 Quick Start After Fresh Install

1. **Complete fresh setup** (if not already done):
   ```bash
   ./scripts/fresh-install.sh
   ```

2. **Start the dashboard server:**
   ```bash
   ./web/start-dashboard.sh
   ```
   The server will start on port 3000 and display a confirmation message.

3. **Open the dashboard in your browser:**
   ```bash
   # macOS
   open http://localhost:3000/web-dashboard.html
   
   # Or manually visit:
   # http://localhost:3000/web-dashboard.html
   ```

### Features

✅ **Real-time pod data** from both SPIRE server and workload clusters  
✅ **Automatic fallback** to mock data if clusters are unavailable  
✅ **Data source indicator** showing whether using real or mock data  
✅ **Live age calculations** that update dynamically  
✅ **Enterprise service names** (user-service, payment-api, inventory-service)  

### 🌐 Localhost Web Server Approach

The dashboard uses a **Node.js web server** instead of static file:// URLs, providing several advantages:

**Benefits:**
- ✅ **Real-time API integration** with live Kubernetes data
- ✅ **CORS-free operation** - no browser security restrictions  
- ✅ **Dynamic data updates** via REST API endpoints
- ✅ **Professional development experience** similar to production web apps
- ✅ **Easy testing and debugging** with standard web development tools

### API Endpoint

The dashboard server provides a REST API endpoint:

- **URL:** `http://localhost:3000/api/pod-data`
- **Method:** GET
- **Response:** JSON with real pod data from kubectl
- **CORS:** Enabled for local development

### 📡 Data Sources

#### Local Testing Environment
The dashboard pulls real-time data from your minikube clusters:
- **SPIRE Server Cluster:** `spire-server-cluster` context
- **Workload Cluster:** `workload-cluster` context  
- **Namespaces:** `spire` and `workload`

#### 🏢 Enterprise Adaptation
*For production deployment*, configure the dashboard to connect to:
- Multiple production Kubernetes clusters across regions
- Enterprise namespaces with proper RBAC permissions
- Service mesh integration (Istio, Linkerd) for additional metrics
- Centralized logging aggregation for historical analysis

### Pod Information Displayed

| Component | Data Shown |
|-----------|-------------|
| **SPIRE Server** | Pod name, status, readiness, restarts, age |
| **Database** | Pod name, status, readiness, restarts, node, image, age |
| **Storage** | PVC name, status, capacity, access modes, storage class, age |
| **Agents** | Pod name, node, status, readiness, age |
| **Workloads** | Service name, type, description, status, readiness, restarts, age |

### Troubleshooting

**Dashboard shows "Mock data" indicator:**
- Run fresh install to ensure clean environment: `./fresh-install.sh`
- Verify kubectl contexts: `kubectl config get-contexts`
- Check if clusters are running: `minikube profile list`

**Server won't start:**
- Ensure fresh Mac prerequisites: `brew install node`
- Check if port 3000 is available or run fresh install: `./fresh-install.sh`
- Verify Node.js installation: `node --version`

**Environment feels inconsistent:**
- Reset to fresh Mac state: `./fresh-install.sh`
- This tears down everything and rebuilds from scratch

### Development

To modify the dashboard:
1. Edit `web-dashboard.html` for UI changes
2. Edit `server.js` for API modifications  
3. Edit `scripts/get-pod-data.sh` for data collection changes

The dashboard automatically refreshes data every 30 seconds when using real-time mode.