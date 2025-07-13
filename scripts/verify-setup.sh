#!/bin/bash
set -e

echo "Verifying SPIRE server setup..."
kubectl --context spire-server-cluster -n spire get pods
echo ""

echo "Verifying SPIRE agent setup..."
kubectl --context workload-cluster -n spire get pods
echo ""

echo "Verifying workload services..."
kubectl --context workload-cluster -n workload get pods
echo ""

echo "Checking SPIRE registration entries..."
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- /opt/spire/bin/spire-server entry show
echo ""

echo "Verifying SPIFFE ID for user-service..."
USER_SERVICE_POD=$(kubectl --context workload-cluster -n workload get pod -l app=user-service -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n workload exec $USER_SERVICE_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "Verifying SPIFFE ID for payment-api..."
PAYMENT_API_POD=$(kubectl --context workload-cluster -n workload get pod -l app=payment-api -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n workload exec $PAYMENT_API_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "Verifying SPIFFE ID for inventory-service..."
INVENTORY_SERVICE_POD=$(kubectl --context workload-cluster -n workload get pod -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')
kubectl --context workload-cluster -n workload exec $INVENTORY_SERVICE_POD -- /bin/sh -c "apt-get update && apt-get install -y curl jq && curl -s --unix-socket /run/spire/sockets/agent.sock -H \"Content-Type: application/json\" -X POST -d '{}' http://localhost/api/workload/v1/fetch_x509_svid | jq '.svids[0].spiffe_id'"
echo ""

echo "Verification completed!"