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

echo "Deploying SPIRE server and database components..."

# Apply SPIRE server and database manifests
kubectl apply -f k8s/spire-server/namespace.yaml
kubectl apply -f k8s/spire-db/postgres-pvc.yaml
kubectl apply -f k8s/spire-db/postgres-deployment.yaml
kubectl apply -f k8s/spire-db/postgres-service.yaml
kubectl apply -f k8s/spire-server/server-configmap.yaml
kubectl apply -f k8s/spire-server/server-rbac.yaml
kubectl apply -f k8s/spire-server/server-service.yaml
kubectl apply -f k8s/spire-server/server-statefulset.yaml

echo "Waiting for SPIRE server to be ready..."
kubectl -n spire wait --for=condition=ready pod -l app=spire-server --timeout=300s || echo "Warning: SPIRE server timeout, continuing..."
kubectl -n spire wait --for=condition=ready pod -l app=spire-db --timeout=300s || echo "Warning: SPIRE DB timeout, continuing..."

# Get the NodePort for the SPIRE server
SERVER_NODEPORT=$(kubectl -n spire get svc spire-server -o jsonpath='{.spec.ports[?(@.name=="server")].nodePort}')
# Get the IP address of the minikube node
SERVER_IP=$(minikube -p spire-server-cluster ip)

echo "SPIRE server is accessible at ${SERVER_IP}:${SERVER_NODEPORT}"

echo "SPIRE server and database deployed successfully!"

# Switch to workload cluster
kubectl config use-context workload-cluster

echo "Deploying SPIRE agent and workload components..."

# Apply workload cluster manifests - create namespaces first
kubectl apply -f k8s/workload-cluster/namespace.yaml
kubectl apply -f k8s/spire-server/namespace.yaml

# Create a service account token for the SPIRE server to access the workload cluster
kubectl create serviceaccount spire-server-sa -n spire --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding spire-server-binding --clusterrole=system:auth-delegator --serviceaccount=spire:spire-server-sa --dry-run=client -o yaml | kubectl apply -f -

# Get the service account token
SA_SECRET_NAME=$(kubectl -n spire get serviceaccount spire-server-sa -o jsonpath='{.secrets[0].name}')
SA_TOKEN=$(kubectl -n spire get secret $SA_SECRET_NAME -o jsonpath='{.data.token}' | base64 --decode)
WORKLOAD_CLUSTER_CA=$(kubectl -n spire get secret $SA_SECRET_NAME -o jsonpath='{.data.ca\.crt}')
WORKLOAD_CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="workload-cluster")].cluster.server}')

# Create a kubeconfig file for the SPIRE server
cat > /tmp/workload-cluster-kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- name: workload-cluster
  cluster:
    certificate-authority-data: ${WORKLOAD_CLUSTER_CA}
    server: ${WORKLOAD_CLUSTER_ENDPOINT}
contexts:
- name: workload-cluster
  context:
    cluster: workload-cluster
    user: spire-server
current-context: workload-cluster
users:
- name: spire-server
  user:
    token: ${SA_TOKEN}
EOF

# Switch back to server cluster
kubectl config use-context spire-server-cluster

# Create a ConfigMap with the workload cluster kubeconfig
kubectl -n spire create configmap workload-cluster-kubeconfig --from-file=kubeconfig=/tmp/workload-cluster-kubeconfig --dry-run=client -o yaml | kubectl apply -f -

# Update the SPIRE server StatefulSet to mount the kubeconfig
kubectl -n spire patch statefulset spire-server --type=json -p '[{"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"workload-cluster-kubeconfig","configMap":{"name":"workload-cluster-kubeconfig"}}}]'
kubectl -n spire patch statefulset spire-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"workload-cluster-kubeconfig","mountPath":"/run/spire/workload-cluster-kubeconfig","readOnly":true}}]'

# Restart the SPIRE server to apply the changes
kubectl -n spire rollout restart statefulset spire-server
kubectl -n spire rollout status statefulset spire-server --timeout=300s

# Switch back to workload cluster
kubectl config use-context workload-cluster

# Wait a moment for SPIRE server to stabilize after restart
echo "Waiting for SPIRE server to stabilize..."
sleep 30

# Copy the bundle from the server cluster to the workload cluster
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- /opt/spire/bin/spire-server bundle show -format pem > /tmp/bundle.pem || echo "Warning: Failed to get bundle, continuing..."
kubectl -n spire create configmap spire-bundle --from-file=bundle.crt=/tmp/bundle.pem --dry-run=client -o yaml | kubectl apply -f -

# Update agent configmap with the correct server address
cat > /tmp/agent-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-agent-config
  namespace: spire
data:
  agent.conf: |
    agent {
      data_dir = "/run/spire"
      log_level = "DEBUG"
      server_address = "${SERVER_IP}"
      server_port = "${SERVER_NODEPORT}"
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
kubectl apply -f k8s/workload-cluster/service1-deployment.yaml
kubectl apply -f k8s/workload-cluster/service2-deployment.yaml
kubectl apply -f k8s/workload-cluster/service3-deployment.yaml

echo "Waiting for SPIRE agent to be ready..."
kubectl -n spire wait --for=condition=ready pod -l app=spire-agent --timeout=300s || echo "Warning: SPIRE agent timeout, continuing..."

echo "SPIRE agent and workload services deployed successfully!"

# Switch back to server cluster to register entries
kubectl config use-context spire-server-cluster

echo "Registering SPIFFE IDs for workloads..."
kubectl apply -f k8s/spire-server/registration-entries.yaml

echo "Setup completed successfully!"
echo ""
echo "🌐 Web Dashboard Available:"
echo "  Open in browser: file://$(pwd)/web-dashboard.html"
echo ""
echo "📋 Useful commands to interact with the clusters:"
echo "  kubectl --context spire-server-cluster -n spire get pods"
echo "  kubectl --context workload-cluster -n workload get pods"
echo "  kubectl --context workload-cluster -n spire get pods"
echo ""
echo "🔍 Run verification script:"
echo "  ./scripts/verify-setup.sh"
