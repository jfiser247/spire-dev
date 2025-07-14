# SPIRE Dashboard Usage Guide

**🔬 Local Testing → 🏢 Enterprise Monitoring**

## Real-Time Pod Data Dashboard

### 💻 Perfect for Local Laptop Development
The SPIRE monitoring dashboard connects directly to your **minikube clusters**, providing real-time pod data that's perfect for:
- **Local testing** of SPIFFE identity propagation
- **Rapid iteration** during development 
- **Debugging** agent connectivity issues on your laptop
- **Validating** configuration changes instantly

### 🚀 Quick Start for Local Testing

1. **Start the dashboard server:**
   ```bash
   ./start-dashboard.sh
   ```

2. **Open the dashboard:**
   Visit [http://localhost:3000/web-dashboard.html](http://localhost:3000/web-dashboard.html)

### Features

✅ **Real-time pod data** from both SPIRE server and workload clusters  
✅ **Automatic fallback** to mock data if clusters are unavailable  
✅ **Data source indicator** showing whether using real or mock data  
✅ **Live age calculations** that update dynamically  
✅ **Enterprise service names** (user-service, payment-api, inventory-service)  

### API Endpoint

The dashboard server provides a REST API endpoint:

- **URL:** `http://localhost:3000/api/pod-data`
- **Method:** GET
- **Response:** JSON with real pod data from kubectl

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
- Ensure both Kubernetes clusters are running
- Verify kubectl contexts: `kubectl config get-contexts`
- Check if get-pod-data.sh script has proper permissions

**Server won't start:**
- Ensure Node.js is installed: `node --version`
- Check if port 3000 is available
- Verify script permissions: `chmod +x start-dashboard.sh`

### Development

To modify the dashboard:
1. Edit `web-dashboard.html` for UI changes
2. Edit `server.js` for API modifications  
3. Edit `scripts/get-pod-data.sh` for data collection changes

The dashboard automatically refreshes data every 30 seconds when using real-time mode.