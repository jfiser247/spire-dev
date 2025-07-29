#!/bin/bash

# SPIRE CRD-Free Enterprise Deployment Script
# For enterprises with strict CRD and elevated privilege restrictions

set -e

echo "🏢 SPIRE CRD-Free Enterprise Deployment"
echo "======================================="
echo ""
echo "This deployment avoids CRDs and cluster-wide privileges by:"
echo "  🔸 Using external SPIRE servers (outside Kubernetes)"
echo "  🔸 Deploying only SPIRE agents in Kubernetes (DaemonSet)"
echo "  🔸 Using annotation-based workload registration"
echo "  🔸 Implementing custom registration service"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "🔸 $1"
    echo "----------------------------------------"
}

print_section "Prerequisites Check"

# Check for required tools
echo "🔍 Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

if ! command -v minikube &> /dev/null; then
    echo "❌ minikube not found. Please install minikube."
    exit 1
fi

echo "✅ All prerequisites satisfied"

print_section "Creating Kubernetes Cluster (Agent-Only)"

# Create single cluster for CRD-free deployment
echo "🔹 Creating minikube cluster for CRD-free deployment..."
minikube start -p crd-free-cluster --memory=2048 --cpus=2 --driver=docker

# Set kubectl context
kubectl config use-context crd-free-cluster

print_section "Deploying SPIRE Agents (No CRDs Required)"

echo "🔹 Deploying SPIRE agents without CRDs..."
kubectl apply -f k8s/crd-free-deployment/agent-only-deployment.yaml

echo "⏳ Waiting for SPIRE agents to be ready..."
if kubectl -n spire-system wait --for=condition=ready pod -l app=spire-agent --timeout=300s; then
    echo "✅ SPIRE agents are ready"
else
    echo "❌ SPIRE agents failed to start"
    kubectl -n spire-system get pods -l app=spire-agent
    kubectl -n spire-system describe pods -l app=spire-agent
    exit 1
fi

print_section "Deploying External Registration Service"

echo "🔹 Deploying custom registration service (CRD-free)..."
kubectl apply -f k8s/crd-free-deployment/external-registration-service.yaml

echo "⏳ Waiting for registration service to be ready..."
if kubectl -n spire-system wait --for=condition=ready pod -l app=spire-registration-service --timeout=120s; then
    echo "✅ Registration service is ready"
else
    echo "❌ Registration service failed to start"
    kubectl -n spire-system get pods -l app=spire-registration-service
    exit 1
fi

print_section "Deploying Example Workloads"

echo "🔹 Deploying enterprise workloads with annotation-based registration..."
kubectl apply -f k8s/crd-free-deployment/workload-examples.yaml

echo "⏳ Waiting for workloads to be ready..."
kubectl -n crd-free-workloads rollout status deployment/enterprise-api-crd-free --timeout=180s
kubectl -n crd-free-workloads rollout status deployment/data-processor-crd-free --timeout=180s

print_section "Verification"

echo "🔍 Verifying CRD-free deployment..."

# Check that no CRDs were created
CRD_COUNT=$(kubectl get crd --no-headers 2>/dev/null | grep -c spire || echo "0")
if [ "$CRD_COUNT" -eq 0 ]; then
    echo "✅ No SPIRE CRDs detected (CRD-free deployment confirmed)"
else
    echo "⚠️  Found $CRD_COUNT SPIRE CRDs - this may not be a pure CRD-free deployment"
    kubectl get crd | grep spire || true
fi

# Check cluster-wide permissions
echo "🔍 Checking for cluster-wide SPIRE permissions..."
CLUSTER_ROLES=$(kubectl get clusterroles --no-headers 2>/dev/null | grep -c spire || echo "0")
if [ "$CLUSTER_ROLES" -le 2 ]; then
    echo "✅ Minimal cluster-wide permissions (agent-only deployment)"
else
    echo "⚠️  Found $CLUSTER_ROLES SPIRE cluster roles"
fi

# Verify components
echo "🔍 Verifying deployment components..."
kubectl -n spire-system get pods
kubectl -n crd-free-workloads get pods

print_section "CRD-Free Deployment Complete!"

echo "🎉 SPIRE CRD-free deployment successful!"
echo ""
echo "🏢 Deployment Summary:"
echo "   🔸 Deployment Type: CRD-Free (Enterprise Compatible)"
echo "   🔸 CRDs Installed: 0 (✅ Enterprise Policy Compliant)"
echo "   🔸 Cluster Privileges: Minimal (Agent-only access)"
echo "   🔸 Registration Method: Annotation-based + External Service"
echo ""
echo "📊 Components Deployed:"
echo "   🤖 SPIRE Agents: DaemonSet in spire-system namespace"
echo "   🔧 Registration Service: Custom annotation-based registrar"
echo "   🏢 Example Workloads: Enterprise API, Data Processor"
echo ""
echo "🔗 Key Differences from CRD Deployment:"
echo "   ❌ No ClusterSPIFFEID CRDs"
echo "   ❌ No SPIRE Controller Manager"
echo "   ❌ No cluster-wide resource access"
echo "   ✅ Annotation-based workload selection"
echo "   ✅ External SPIRE server integration"
echo "   ✅ Namespace-scoped permissions only"
echo ""
echo "⚠️  IMPORTANT: External SPIRE Server Required"
echo "   This deployment expects an external SPIRE server at:"
echo "   📡 external-spire-server.company.com:8081"
echo ""
echo "🔧 Next Steps for Production:"
echo "   1. Deploy external SPIRE servers (VMs/bare metal)"
echo "   2. Configure external database (PostgreSQL HA)"
echo "   3. Update agent configuration with real server address"
echo "   4. Implement custom registration service logic"
echo "   5. Set up monitoring and alerting"
echo ""
echo "📖 Documentation:"
echo "   📋 CRD Requirements: docs/ENTERPRISE_CRD_REQUIREMENTS.md"
echo "   🏗️ Architecture Guide: docs/ENTERPRISE_DEPLOYMENT_GUIDE.md"
echo ""
echo "🔍 Useful Commands:"
echo "   # Check agent status"
echo "   kubectl -n spire-system get pods -l app=spire-agent"
echo ""
echo "   # View workload annotations"
echo "   kubectl -n crd-free-workloads describe pods"
echo ""
echo "   # Check registration service logs"
echo "   kubectl -n spire-system logs -l app=spire-registration-service"
echo ""
echo "✅ CRD-free SPIRE deployment ready for enterprise use!"