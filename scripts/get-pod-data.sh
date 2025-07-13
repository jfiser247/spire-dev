#!/bin/bash

# Script to fetch real pod data for the dashboard
# Returns JSON format that can be consumed by the web dashboard

echo "{"

# SPIRE Server pods
echo "  \"server\": ["
kubectl --context spire-server-cluster -n spire get pods -o json | jq -r '.items[] | select(.metadata.name | startswith("spire-server")) | {name: .metadata.name, status: .status.phase, ready: (.status.containerStatuses[0].ready // false), restarts: (.status.containerStatuses[0].restartCount // 0), node: .spec.nodeName, age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ],"

# Database pods
echo "  \"database\": ["
kubectl --context spire-server-cluster -n spire get pods -o json | jq -r '.items[] | select(.metadata.name | startswith("spire-db")) | {name: .metadata.name, status: .status.phase, ready: (.status.containerStatuses[0].ready // false), restarts: (.status.containerStatuses[0].restartCount // 0), node: .spec.nodeName, image: .spec.containers[0].image, age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ],"

# Database storage
echo "  \"storage\": ["
kubectl --context spire-server-cluster -n spire get pvc -o json | jq -r '.items[] | select(.metadata.name | startswith("postgres")) | {name: .metadata.name, status: .status.phase, capacity: .status.capacity.storage, accessModes: .spec.accessModes[0], storageClass: .spec.storageClassName, age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ],"

# Database service
echo "  \"dbService\": ["
kubectl --context spire-server-cluster -n spire get svc -o json | jq -r '.items[] | select(.metadata.name | startswith("spire-db")) | {name: .metadata.name, type: .spec.type, clusterIP: .spec.clusterIP, port: .spec.ports[0].port, targetPort: .spec.ports[0].targetPort, age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ],"

# SPIRE Agent pods
echo "  \"agents\": ["
kubectl --context workload-cluster -n spire get pods -o json | jq -r '.items[] | select(.metadata.name | startswith("spire-agent")) | {name: .metadata.name, node: .spec.nodeName, status: .status.phase, ready: (.status.containerStatuses[0].ready // false), age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ],"

# Workload service pods  
echo "  \"workloads\": ["
kubectl --context workload-cluster -n workload get pods -o json | jq -r '.items[] | {name: .metadata.name, serviceName: (.metadata.name | split("-")[0]), status: .status.phase, ready: (.status.containerStatuses[0].ready // false), restarts: (.status.containerStatuses[0].restartCount // 0), upToDate: 1, available: 1, age: .metadata.creationTimestamp} | @json' | sed 's/$/,/' | sed '$ s/,$//'
echo "  ]"

echo "}"