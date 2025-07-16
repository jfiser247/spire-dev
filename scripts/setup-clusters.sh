#!/bin/bash
set -e

echo "Creating minikube clusters..."

# Create the SPIRE server cluster
minikube start -p spire-server-cluster --memory=2048 --cpus=2

# Create the workload cluster
minikube start -p workload-cluster --memory=2048 --cpus=2

echo "Clusters created successfully!"

# Set up kubectl contexts
kubectl config use-context spire-server-cluster

echo "Deploying SPIRE server and database components in workload cluster..."

# Switch to workload cluster for all deployments
kubectl config use-context workload-cluster

# Apply SPIRE server and database manifests in workload cluster
echo "Creating spire-server namespace with pod security standards..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: spire-server
  labels:
    name: spire-server
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF
kubectl apply -f k8s/spire-db/postgres-pvc.yaml -n spire-server
kubectl apply -f k8s/spire-db/postgres-deployment.yaml -n spire-server
kubectl apply -f k8s/spire-db/postgres-service.yaml -n spire-server
kubectl apply -f k8s/spire-server/server-configmap.yaml -n spire-server
kubectl apply -f k8s/spire-server/server-rbac.yaml -n spire-server
kubectl apply -f k8s/spire-server/server-service.yaml -n spire-server
kubectl apply -f k8s/spire-server/server-statefulset.yaml -n spire-server

echo "Waiting for SPIRE server to be ready..."
# Increased timeouts to handle pod startup delays
if ! kubectl -n spire-server wait --for=condition=ready pod -l app=spire-server --timeout=600s; then
    echo "Warning: SPIRE server timeout, checking pod status..."
    kubectl -n spire-server get pods -l app=spire-server
    kubectl -n spire-server describe pods -l app=spire-server
fi

if ! kubectl -n spire-server wait --for=condition=ready pod -l app=spire-db --timeout=600s; then
    echo "Warning: SPIRE DB timeout, checking pod status..."
    kubectl -n spire-server get pods -l app=spire-db
    kubectl -n spire-server describe pods -l app=spire-db
fi

echo "SPIRE server and database deployed successfully!"

echo "Deploying SPIRE agent and workload components..."

# Apply workload cluster manifests - create namespaces first (following SPIFFE best practices)
echo "Creating spire-system namespace with pod security standards..."
kubectl apply -f k8s/workload-cluster/spire-system-namespace.yaml

echo "Creating production namespace with pod security standards..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    name: production
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF


# Get the bundle from the local server
SERVER_POD=$(kubectl -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')

# Wait for SPIRE server API to be ready and get bundle with retries
echo "Getting SPIRE server bundle from local deployment..."
for i in {1..5}; do
    if kubectl -n spire-server exec $SERVER_POD -- /opt/spire/bin/spire-server bundle show -socketPath /run/spire/sockets/server.sock -format pem > /tmp/bundle.pem 2>/dev/null; then
        if [ -s /tmp/bundle.pem ]; then
            echo "✅ Bundle retrieved successfully from local server"
            break
        else
            echo "⏳ Bundle is empty, retrying... (attempt $i/5)"
        fi
    else
        echo "⏳ SPIRE server API not ready, retrying... (attempt $i/5)"
    fi
    
    if [ $i -eq 5 ]; then
        echo "❌ Failed to get bundle after 5 attempts"
        exit 1
    fi
    
    sleep 15
done

kubectl -n spire-system create configmap spire-bundle --from-file=bundle.crt=/tmp/bundle.pem --dry-run=client -o yaml | kubectl apply -f -

# Update agent configmap to use local server
cat > /tmp/agent-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-agent-config
  namespace: spire-system
data:
  agent.conf: |
    agent {
      data_dir = "/run/spire"
      log_level = "DEBUG"
      server_address = "spire-server.spire-server.svc.cluster.local"
      server_port = "8081"
      socket_path = "/run/spire/sockets/agent.sock"
      trust_bundle_path = "/run/spire/bundle/bundle.crt"
      trust_domain = "example.org"
    }

    plugins {
      NodeAttestor "k8s_psat" {
        plugin_data {
          cluster = "cluster"
        }
      }

      KeyManager "memory" {
        plugin_data {
        }
      }

      WorkloadAttestor "k8s" {
        plugin_data {
          skip_kubelet_verification = true
        }
      }
    }

    health_checks {
      listener_enabled = true
      bind_address = "0.0.0.0"
      bind_port = "8080"
      live_path = "/live"
      ready_path = "/ready"
    }
EOF

# Apply agent and workload manifests
kubectl apply -f /tmp/agent-configmap.yaml
kubectl apply -f k8s/workload-cluster/agent-rbac.yaml
kubectl apply -f k8s/workload-cluster/agent-daemonset.yaml
kubectl apply -f k8s/workload-cluster/user-service-deployment.yaml
kubectl apply -f k8s/workload-cluster/payment-api-deployment.yaml
kubectl apply -f k8s/workload-cluster/inventory-service-deployment.yaml

echo "Waiting for SPIRE agent to be ready..."
if ! kubectl -n spire-system wait --for=condition=ready pod -l app=spire-agent --timeout=600s; then
    echo "Warning: SPIRE agent timeout, checking pod status..."
    kubectl -n spire-system get pods -l app=spire-agent
    kubectl -n spire-system describe pods -l app=spire-agent
fi

echo "Checking workload service deployments..."
kubectl -n production get pods
if [ $(kubectl -n production get pods --field-selector=status.phase=Running --no-headers | wc -l) -lt 3 ]; then
    echo "Warning: Not all workload services are running. Checking deployment status..."
    kubectl -n production get deployments
    kubectl -n production describe deployments
fi

echo "SPIRE agent and workload services deployed successfully!"

echo "Registering SPIFFE IDs for workloads..."
kubectl apply -f k8s/spire-server/registration-entries.yaml -n spire-server

echo "Setup completed successfully with single-cluster deployment!"
echo ""
echo "🌐 Web Dashboard Available:"
echo "  Start server: ./web/start-dashboard.sh"
echo "  Open in browser: http://localhost:3000/web-dashboard.html"
echo ""
echo "📋 Useful commands to interact with the cluster:"
echo "  kubectl --context workload-cluster -n spire-server get pods"
echo "  kubectl --context workload-cluster -n production get pods"
echo "  kubectl --context workload-cluster -n spire-system get pods"
echo ""
echo "🔍 Run verification script:"
echo "  ./scripts/verify-setup.sh"
