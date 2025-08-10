#!/bin/bash
set -e

echo "🏢 Creating enterprise SPIRE clusters..."
echo "========================================"
echo ""
echo "This script demonstrates enterprise deployment with:"
echo "  🔸 Upstream SPIRE cluster (Root CA/Identity Provider)"
echo "  🔸 Downstream SPIRE cluster (Regional/Workload cluster)"
echo "  🔸 Federation between clusters for multi-tenant trust"
echo "  🔸 Enterprise workload services with mTLS"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "🔸 $1"
    echo "----------------------------------------"
}

print_section "Creating minikube clusters for enterprise architecture"

# Create the upstream SPIRE cluster (acts as root CA)
echo "🔹 Creating upstream cluster (Root Identity Provider)..."
minikube start -p upstream-spire-cluster --memory=3072 --cpus=2 --driver=docker

# Create the downstream SPIRE cluster (workload cluster)
echo "🔹 Creating downstream cluster (Regional/Workload cluster)..."
minikube start -p downstream-spire-cluster --memory=3072 --cpus=2 --driver=docker

echo "✅ Enterprise clusters created successfully!"

print_section "Deploying upstream SPIRE cluster (Root Identity Provider)"

# Set up kubectl context for upstream cluster
kubectl config use-context upstream-spire-cluster

# Deploy upstream cluster components
echo "🔹 Deploying upstream SPIRE server and database..."
kubectl apply -f k8s/upstream-cluster/namespace.yaml
kubectl apply -f k8s/upstream-cluster/mysql-deployment.yaml
kubectl apply -f k8s/upstream-cluster/bundle-configmap.yaml
kubectl apply -f k8s/upstream-cluster/server-configmap.yaml
kubectl apply -f k8s/upstream-cluster/controller-manager-config.yaml
kubectl apply -f k8s/upstream-cluster/server-rbac.yaml
kubectl apply -f k8s/upstream-cluster/server-service.yaml
kubectl apply -f k8s/upstream-cluster/server-statefulset.yaml

echo "⏳ Waiting for upstream SPIRE server to be ready..."
# Allow time for pods to be created
sleep 15

# Wait for upstream components with extended timeout
if kubectl -n spire-upstream wait --for=condition=ready pod -l app=spire-upstream-db --timeout=300s; then
    echo "✅ Upstream database is ready"
else
    echo "❌ Upstream database timeout"
    kubectl -n spire-upstream get pods
    kubectl -n spire-upstream describe pods -l app=spire-upstream-db
    exit 1
fi

if kubectl -n spire-upstream wait --for=condition=ready pod -l app=spire-upstream-server --timeout=600s; then
    echo "✅ Upstream SPIRE server is ready"
else
    echo "❌ Upstream SPIRE server timeout"
    kubectl -n spire-upstream get pods
    kubectl -n spire-upstream describe pods -l app=spire-upstream-server
    exit 1
fi

print_section "Deploying downstream SPIRE cluster (Regional/Workload cluster)"

# Switch to downstream cluster
kubectl config use-context downstream-spire-cluster

# Deploy downstream cluster components
echo "🔹 Deploying downstream SPIRE server and workload services..."
kubectl apply -f k8s/downstream-cluster/namespace.yaml
kubectl apply -f k8s/downstream-cluster/mysql-deployment.yaml
kubectl apply -f k8s/downstream-cluster/bundle-configmap.yaml
kubectl apply -f k8s/downstream-cluster/server-configmap.yaml
kubectl apply -f k8s/downstream-cluster/controller-manager-config.yaml
kubectl apply -f k8s/downstream-cluster/server-rbac.yaml
kubectl apply -f k8s/downstream-cluster/server-service.yaml
kubectl apply -f k8s/downstream-cluster/server-statefulset.yaml

echo "⏳ Waiting for downstream SPIRE server to be ready..."
# Allow time for pods to be created
sleep 15

# Wait for downstream components
if kubectl -n spire-downstream wait --for=condition=ready pod -l app=spire-downstream-db --timeout=300s; then
    echo "✅ Downstream database is ready"
else
    echo "❌ Downstream database timeout"
    kubectl -n spire-downstream get pods
    kubectl -n spire-downstream describe pods -l app=spire-downstream-db
    exit 1
fi

if kubectl -n spire-downstream wait --for=condition=ready pod -l app=spire-downstream-server --timeout=600s; then
    echo "✅ Downstream SPIRE server is ready"
else
    echo "❌ Downstream SPIRE server timeout"
    kubectl -n spire-downstream get pods
    kubectl -n spire-downstream describe pods -l app=spire-downstream-server
    exit 1
fi

print_section "Deploying SPIRE agents and enterprise workloads"

# Deploy agents and workloads in downstream cluster
echo "🔹 Deploying SPIRE agents..."
kubectl apply -f k8s/downstream-cluster/agent-configmap.yaml
kubectl apply -f k8s/downstream-cluster/agent-rbac.yaml
kubectl apply -f k8s/downstream-cluster/agent-daemonset.yaml

echo "🔹 Deploying enterprise workload services..."
kubectl apply -f k8s/downstream-cluster/workload-services.yaml

echo "⏳ Waiting for agents and workloads to be ready..."
# Wait for agents
if kubectl -n spire-downstream wait --for=condition=ready pod -l app=spire-downstream-agent --timeout=300s; then
    echo "✅ Downstream SPIRE agents are ready"
else
    echo "❌ Downstream SPIRE agents timeout"
    kubectl -n spire-downstream get pods -l app=spire-downstream-agent
fi

if kubectl -n downstream-workloads wait --for=condition=ready pod -l app=spire-downstream-agent --timeout=300s; then
    echo "✅ Workload namespace SPIRE agents are ready"
else
    echo "❌ Workload namespace SPIRE agents timeout"
    kubectl -n downstream-workloads get pods -l app=spire-downstream-agent
fi

# Wait for workload services
echo "⏳ Waiting for enterprise workload services..."
kubectl -n downstream-workloads rollout status deployment/enterprise-api --timeout=300s
kubectl -n downstream-workloads rollout status deployment/data-processor --timeout=300s
kubectl -n downstream-workloads rollout status deployment/security-gateway --timeout=300s

print_section "Configuring trust bundles and federation"

# Get upstream trust bundle
echo "🔹 Extracting upstream trust bundle..."
kubectl config use-context upstream-spire-cluster
UPSTREAM_SERVER_POD=$(kubectl -n spire-upstream get pod -l app=spire-upstream-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$UPSTREAM_SERVER_POD" ]; then
    echo "❌ Failed to get upstream SPIRE server pod name"
    kubectl -n spire-upstream get pods
    exit 1
fi

# Wait for upstream server API and get bundle
for i in {1..5}; do
    if kubectl -n spire-upstream exec $UPSTREAM_SERVER_POD -- /opt/spire/bin/spire-server bundle show -socketPath /run/spire/sockets/server.sock -format pem > /tmp/upstream-bundle.pem 2>/dev/null; then
        if [ -s /tmp/upstream-bundle.pem ]; then
            echo "✅ Upstream bundle retrieved successfully"
            break
        fi
    fi
    echo "⏳ Waiting for upstream server API... (attempt $i/5)"
    sleep 10
done

# Get downstream trust bundle
echo "🔹 Extracting downstream trust bundle..."
kubectl config use-context downstream-spire-cluster
DOWNSTREAM_SERVER_POD=$(kubectl -n spire-downstream get pod -l app=spire-downstream-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$DOWNSTREAM_SERVER_POD" ]; then
    echo "❌ Failed to get downstream SPIRE server pod name"
    kubectl -n spire-downstream get pods
    exit 1
fi

# Wait for downstream server API and get bundle
for i in {1..5}; do
    if kubectl -n spire-downstream exec $DOWNSTREAM_SERVER_POD -- /opt/spire/bin/spire-server bundle show -socketPath /run/spire/sockets/server.sock -format pem > /tmp/downstream-bundle.pem 2>/dev/null; then
        if [ -s /tmp/downstream-bundle.pem ]; then
            echo "✅ Downstream bundle retrieved successfully"
            break
        fi
    fi
    echo "⏳ Waiting for downstream server API... (attempt $i/5)"
    sleep 10
done

# Update bundle ConfigMaps
echo "🔹 Updating trust bundle ConfigMaps..."
kubectl config use-context upstream-spire-cluster
kubectl -n spire-upstream create configmap spire-bundle --from-file=bundle.crt=/tmp/upstream-bundle.pem --dry-run=client -o yaml | kubectl apply -f -

kubectl config use-context downstream-spire-cluster
kubectl -n spire-downstream create configmap spire-bundle --from-file=bundle.crt=/tmp/downstream-bundle.pem --dry-run=client -o yaml | kubectl apply -f -
kubectl -n downstream-workloads create configmap spire-bundle --from-file=bundle.crt=/tmp/downstream-bundle.pem --dry-run=client -o yaml | kubectl apply -f -

print_section "Enterprise deployment completed successfully!"

echo "🎉 Enterprise SPIRE clusters are ready!"
echo ""
echo "🏢 Architecture Overview:"
echo "   🔸 Upstream Cluster (Root CA): upstream-spire-cluster"
echo "     - Trust Domain: enterprise-root.org"
echo "     - Namespace: spire-upstream"
echo "     - Role: Root Certificate Authority & Identity Provider"
echo ""
echo "   🔸 Downstream Cluster (Regional): downstream-spire-cluster"  
echo "     - Trust Domain: downstream.example.org"
echo "     - Namespaces: spire-downstream, downstream-workloads"
echo "     - Role: Regional server with enterprise workloads"
echo ""
echo "📊 Web Dashboard:"
echo "   Start server: ./web/start-dashboard.sh"
echo "   Open browser: http://localhost:3000/web-dashboard.html"
echo ""
echo "🔍 Useful commands:"
echo "   # Upstream cluster"
echo "   kubectl --context upstream-spire-cluster -n spire-upstream get pods"
echo ""
echo "   # Downstream cluster"
echo "   kubectl --context downstream-spire-cluster -n spire-downstream get pods"
echo "   kubectl --context downstream-spire-cluster -n downstream-workloads get pods"
echo ""
echo "   # Access enterprise services"
echo "   kubectl --context downstream-spire-cluster port-forward -n downstream-workloads svc/security-gateway 30080:8080"
echo ""
echo "🔄 Run verification:"
echo "   ./scripts/verify-enterprise-setup.sh"
echo ""
echo "🏢 Ready for enterprise security operations!"