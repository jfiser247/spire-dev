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
kubectl -n spire wait --for=condition=ready pod -l app=spire-server --timeout=120s
kubectl -n spire wait --for=condition=ready pod -l app=spire-db --timeout=120s

echo "SPIRE server and database deployed successfully!"

# Switch to workload cluster
kubectl config use-context workload-cluster

echo "Deploying SPIRE agent and workload components..."

# Apply workload cluster manifests
kubectl apply -f k8s/workload-cluster/namespace.yaml
kubectl apply -f k8s/spire-server/namespace.yaml
kubectl create configmap -n spire spire-bundle

# Copy the bundle from the server cluster to the workload cluster
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- /opt/spire/bin/spire-server bundle show -format pem > /tmp/bundle.pem
kubectl -n spire create configmap spire-bundle --from-file=bundle.crt=/tmp/bundle.pem --dry-run=client -o yaml | kubectl apply -f -

# Apply agent and workload manifests
kubectl apply -f k8s/workload-cluster/agent-configmap.yaml
kubectl apply -f k8s/workload-cluster/agent-rbac.yaml
kubectl apply -f k8s/workload-cluster/agent-daemonset.yaml
kubectl apply -f k8s/workload-cluster/service1-deployment.yaml
kubectl apply -f k8s/workload-cluster/service2-deployment.yaml
kubectl apply -f k8s/workload-cluster/service3-deployment.yaml

echo "Waiting for SPIRE agent to be ready..."
kubectl -n spire wait --for=condition=ready pod -l app=spire-agent --timeout=120s

echo "SPIRE agent and workload services deployed successfully!"

# Switch back to server cluster to register entries
kubectl config use-context spire-server-cluster

echo "Registering SPIFFE IDs for workloads..."
kubectl apply -f k8s/spire-server/registration-entries.yaml

echo "Setup completed successfully!"
echo "You can now use the following commands to interact with the clusters:"
echo "  kubectl --context spire-server-cluster -n spire get pods"
echo "  kubectl --context workload-cluster -n workload get pods"
echo "  kubectl --context workload-cluster -n spire get pods"