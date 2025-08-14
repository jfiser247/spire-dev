---
layout: page
title: Quick Start Workload Integration
permalink: /quick-start-workload-integration/
---

Get your first workload talking with SPIFFE identities on your local development machine! This guide walks you through adding a new workload to your local SPIRE setup step-by-step.

## What You'll Learn

- How to prepare a workload for SPIFFE integration
- How to register the workload with your local SPIRE server
- How to verify everything is working
- How to use SPIFFE identities in your code

## Prerequisites

✅ **Before you start, make sure you have:**
- Completed the [Fresh Install Setup]({{ "/fresh-install-guide/" | relative_url }})
- A working SPIRE environment (run `kubectl get pods -n spire-server` to verify)
- Basic familiarity with Kubernetes and Docker

## Overview: What We'll Build

We'll create a simple "Hello World" service that:
1. 🔐 **Gets a SPIFFE identity** from your local SPIRE setup
2. 🤝 **Communicates securely** with other services using mTLS
3. 📊 **Reports its identity** via a health endpoint

**Time Required:** 10-15 minutes

## Step 1: Create Your Workload

### 1.1 Create the Project Structure
```bash
# Create your workload directory
mkdir -p examples/my-first-workload
cd examples/my-first-workload

# Create basic structure
mkdir -p cmd k8s
```

### 1.2 Create a Simple Go Service
Create `cmd/main.go`:

```go
package main

import (
    "context"
    "crypto/tls"
    "fmt"
    "log"
    "net/http"
    "os"
    "path"

    "github.com/spiffe/go-spiffe/v2/spiffeid"
    "github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func main() {
    // Create a context for the SPIFFE Workload API
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Create a new Workload API client
    socketPath := os.Getenv("SPIFFE_ENDPOINT_SOCKET")
    if socketPath == "" {
        socketPath = "/run/spire/sockets/agent.sock"
    }

    // Create an HTTP server with SPIFFE-based TLS
    source, err := workloadapi.NewX509Source(ctx, workloadapi.WithClientOptions(workloadapi.WithAddr(socketPath)))
    if err != nil {
        log.Fatalf("Unable to create X509 source: %v", err)
    }
    defer source.Close()

    // Set up routes
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        // Get the current SPIFFE ID
        svid, err := source.GetX509SVID()
        if err != nil {
            http.Error(w, fmt.Sprintf("Unable to get SVID: %v", err), http.StatusInternalServerError)
            return
        }

        w.Header().Set("Content-Type", "application/json")
        fmt.Fprintf(w, `{
  "message": "Hello from SPIFFE-enabled workload!",
  "spiffe_id": "%s",
  "service": "my-first-workload",
  "status": "healthy"
}`, svid.ID)
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintf(w, "OK")
    })

    // Configure TLS
    tlsConfig := tlsconfig.HTTPServerConfig(source, tlsconfig.AuthorizeAny())
    server := &http.Server{
        Addr:      ":8080",
        TLSConfig: tlsConfig,
    }

    log.Println("🚀 Starting SPIFFE-enabled service on :8080")
    log.Fatal(server.ListenAndServeTLS("", ""))
}
```

### 1.3 Create Go Module Files
Create `go.mod`:
```go
module my-first-workload

go 1.20

require (
    github.com/spiffe/go-spiffe/v2 v2.1.6
)
```

Create `go.sum` (will be populated when you build):
```
# This file will be populated when you run go mod tidy
```

### 1.4 Create Dockerfile
Create `Dockerfile`:
```dockerfile
FROM golang:1.20-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY cmd/ ./cmd/
RUN CGO_ENABLED=0 GOOS=linux go build -o my-first-workload ./cmd

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/my-first-workload .

EXPOSE 8080
CMD ["./my-first-workload"]
```

## Step 2: Create Kubernetes Deployment

### 2.1 Create Deployment Manifest
Create `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-first-workload
  namespace: spire-workload
  labels:
    app: my-first-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-first-workload
  template:
    metadata:
      labels:
        app: my-first-workload
    spec:
      serviceAccountName: my-first-workload
      containers:
      - name: my-first-workload
        image: my-first-workload:latest
        imagePullPolicy: Never  # Use locally built image
        ports:
        - containerPort: 8080
        env:
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: DirectoryOrCreate
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-first-workload
  namespace: spire-workload
---
apiVersion: v1
kind: Service
metadata:
  name: my-first-workload
  namespace: spire-workload
spec:
  selector:
    app: my-first-workload
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
```

## Step 3: Build and Deploy

### 3.1 Build Your Docker Image
```bash
# Build the image in minikube context
eval $(minikube docker-env)
docker build -t my-first-workload:latest .
```

### 3.2 Deploy to Kubernetes
```bash
# Apply the deployment
kubectl apply -f k8s/deployment.yaml

# Check if the pod started
kubectl get pods -n spire-workload -l app=my-first-workload
```

## Step 4: Register with SPIRE

### 4.1 Create Registration Entry
Now register your workload with SPIRE so it can get a SPIFFE identity:

```bash
# Register the workload with SPIRE server
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/my-first-workload \
  -parentID spiffe://example.org/spire/agent/k8s_psat/workload-cluster \
  -selector k8s:ns:spire-workload \
  -selector k8s:sa:my-first-workload \
  -selector k8s:pod-label:app:my-first-workload
```

### 4.2 Verify Registration
```bash
# Check that the registration was created
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://example.org/workload/my-first-workload
```

## Step 5: Test Your Workload

### 5.1 Check Pod Status
```bash
# Make sure your pod is running
kubectl get pods -n spire-workload -l app=my-first-workload

# Check the logs to see if it's getting its SPIFFE identity
kubectl logs -n spire-workload -l app=my-first-workload
```

### 5.2 Test the Service
```bash
# Port forward to test locally
kubectl port-forward -n spire-workload service/my-first-workload 8080:80 &

# Test the endpoint (note: this will fail with TLS since we're not using SPIFFE client)
# In a real scenario, you'd have another SPIFFE-enabled client
curl -k https://localhost:8080/

# Check health endpoint
curl -k https://localhost:8080/health

# Clean up port forward
pkill -f "kubectl port-forward.*my-first-workload"
```

### 5.3 View in Dashboard
Open your local dashboard at **http://localhost:3000** and check:
- Navigate to the **Workloads** tab
- You should see your `my-first-workload` service listed
- Click on the service name to see detailed SPIFFE information

## Step 6: Verify SPIFFE Integration

### 6.1 Check SPIFFE Identity
```bash
# Exec into your pod to verify SPIFFE identity
kubectl exec -n spire-workload -it deployment/my-first-workload -- sh

# Inside the pod, check the SPIFFE socket
ls -la /run/spire/sockets/

# You can also check if the workload API is accessible
# (This requires spire-agent tools in the container)
```

### 6.2 View SPIRE Agent Logs
```bash
# Check agent logs to see identity issuance
kubectl logs -n spire-system -l app=spire-agent | grep "my-first-workload"
```

## Troubleshooting

### 🚨 Pod Won't Start
**Check these common issues:**

```bash
# Check pod events
kubectl describe pod -n spire-workload -l app=my-first-workload

# Common fixes:
# 1. Image pull issues (make sure you built in minikube context)
eval $(minikube docker-env)
docker images | grep my-first-workload

# 2. Service account missing
kubectl get serviceaccount -n spire-workload my-first-workload
```

### 🚨 Can't Get SPIFFE Identity
**Check registration and selectors:**

```bash
# Verify registration exists
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show

# Check if pod labels match selectors
kubectl get pod -n spire-workload -l app=my-first-workload -o yaml | grep labels -A 5
```

### 🚨 TLS Connection Issues
**Check SPIFFE socket:**

```bash
# Verify agent socket is mounted
kubectl exec -n spire-workload deployment/my-first-workload -- ls -la /run/spire/sockets/

# Check agent is running
kubectl get pods -n spire-system -l app=spire-agent
```

## Next Steps

🎉 **Congratulations! You've successfully:**
- ✅ Created a SPIFFE-enabled workload
- ✅ Registered it with SPIRE
- ✅ Verified secure identity issuance

### What to Try Next:

1. **Service-to-Service Communication** - Create a second service that calls your first service using SPIFFE mTLS
2. **Understand the Architecture** - [Learn how SPIRE components work together]({{ "/architecture-diagrams/" | relative_url }})
3. **Explore Advanced Patterns** - Check out more complex examples in the `examples/` directory
4. **Production Patterns** - [Learn about enterprise deployments]({{ "/enterprise-deployment/" | relative_url }})

## Understanding What You Built

### SPIFFE Identity Components
Your workload now has:
- **SPIFFE ID**: `spiffe://example.org/workload/my-first-workload`
- **X.509 SVID**: Automatically rotated certificate for mTLS
- **JWT SVID**: Token for service-to-service authentication

### Security Benefits
- 🔒 **Automatic mTLS** - No manual certificate management
- 🔄 **Automatic rotation** - Certificates refresh automatically
- 🎯 **Identity-based access** - Services authenticate by identity, not network location
- 📍 **Workload attestation** - Cryptographic proof of workload identity

### Local Development Workflow
You can now:
- Rapidly test identity-based access patterns
- Experiment with zero-trust architecture
- Prototype SPIFFE integrations before production deployment

## Resources

- **[SPIFFE Go Library Documentation](https://pkg.go.dev/github.com/spiffe/go-spiffe/v2)**
- **[Workload Integration Guide]({{ "/workload-integration/" | relative_url }})** - More detailed integration patterns
- **[Troubleshooting Guide]({{ "/troubleshooting/" | relative_url }})** - Common issues and solutions