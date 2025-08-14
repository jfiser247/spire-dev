# Quick Start: Local Workload Integration

Get your first workload talking with SPIFFE identities on your local development machine! This guide walks you through adding a new workload to your local SPIRE setup step-by-step.

## What You'll Learn

- How to prepare a workload for SPIFFE integration
- How to register the workload with your local SPIRE server
- How to verify everything is working
- How to use SPIFFE identities in your code

## Prerequisites

✅ **Fresh install completed**: Run `./scripts/fresh-install.sh` first  
✅ **Local SPIRE running**: SPIRE Server and Agent pods should be healthy  
✅ **kubectl working**: You can run `kubectl get pods`

## Step 1: Prepare Your Workload

First, let's set up your workload to communicate with SPIRE. Add this configuration to your Kubernetes deployment:

```yaml
# Add to your deployment spec
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-test-service
  namespace: spire-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-test-service
  template:
    metadata:
      labels:
        app: my-test-service
        service: web-api
    spec:
      serviceAccountName: my-test-service
      containers:
      - name: my-test-service
        image: your-app:latest
        env:
        # This tells your app where to find the SPIRE agent socket
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
      volumes:
      # Mount the SPIRE agent socket into your container
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
---
# Create a ServiceAccount for your workload
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-test-service
  namespace: spire-workload
```

## Step 2: Install SPIFFE SDK in Your App

Choose your language and add the SPIFFE library:

**Go:**
```bash
go get github.com/spiffe/go-spiffe/v2
```

**Python:**
```bash
pip install pyspiffe
```

**Java:**
```xml
<dependency>
    <groupId>io.spiffe</groupId>
    <artifactId>java-spiffe-core</artifactId>
    <version>0.8.4</version>
</dependency>
```

## Step 3: Register Your Workload with SPIRE

Now register your workload so SPIRE knows about it. Use the handy registration script:

```bash
# Register your test service
./scripts/register-workload.sh \
  --name my-test-service \
  --service-account my-test-service \
  --workload-ns production \
  --service-type web-api

# That's it! The script handles all the SPIRE server communication for you
```

### Option B: Manual Registration (For Learning)

Want to see what's happening under the hood? You can register manually:

```bash
# Connect to your local SPIRE server
kubectl exec -n spire-server -it deployment/spire-server -- /bin/sh

# Create the registration entry
/opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/my-test-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:spire-workload \
  -selector k8s:sa:my-test-service \
  -selector k8s:pod-label:app:my-test-service \
  -ttl 1800

# Check that it worked
/opt/spire/bin/spire-server entry show
```

## Step 4: Deploy and Test

Deploy your workload and see if it can get SPIFFE identities:

```bash
# Deploy your workload
kubectl apply -f your-workload.yaml

# Check that pods are running
kubectl get pods -n spire-workload -l app=my-test-service

# Look at the logs to see if SPIFFE is working
kubectl logs -n spire-workload -l app=my-test-service

# Test SPIRE agent socket access
kubectl exec -n spire-workload -it deployment/my-test-service -- \
  ls -la /run/spire/sockets/
```

## Step 5: Use SPIFFE in Your Code

Here's how to actually use SPIFFE identities in your application:

## Common Issues and Solutions

### Issue: "No SPIRE agent socket found"
**Solution:** Check that SPIRE agent is running on the node and volume mount is correct.

### Issue: "Registration entry not found"
**Solution:** Verify the registration entry exists and selectors match pod labels exactly.

### Issue: "Permission denied accessing socket"
**Solution:** Check pod security context and ensure proper user/group settings.

### Go Example - Get Your SPIFFE Identity
```go
package main

import (
    "context"
    "fmt"
    "log"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func main() {
    ctx := context.Background()
    
    // Connect to SPIRE agent
    source, err := workloadapi.NewX509Source(ctx)
    if err != nil {
        log.Fatalf("Unable to create X509Source: %v", err)
    }
    defer source.Close()

    // Get your SPIFFE identity
    svid, err := source.GetX509SVID()
    if err != nil {
        log.Fatalf("Unable to fetch SVID: %v", err)
    }

    // Print your identity!
    fmt.Printf("🎉 My SPIFFE ID: %s\n", svid.ID)
    fmt.Printf("Certificate expires: %s\n", svid.Certificates[0].NotAfter)
}
```

### Python Example - Get Your SPIFFE Identity
```python
from pyspiffe import WorkloadApiClient

def main():
    try:
        # Connect to SPIRE agent
        client = WorkloadApiClient()
        
        # Get your SPIFFE identity
        svid = client.fetch_x509_svid()
        
        # Print your identity!
        print(f"🎉 My SPIFFE ID: {svid.spiffe_id}")
        print(f"Certificate expires: {svid.leaf_certificate.not_valid_after}")
        
    finally:
        client.close()

if __name__ == "__main__":
    main()
```

## Common Issues and Quick Fixes

### 🚨 "No SPIRE agent socket found"
**Quick Fix:** Check that your volume mount is correct and SPIRE agent is running:
```bash
kubectl get pods -n spire-system  # Should show spire-agent pods
```

### 🚨 "Registration entry not found"  
**Quick Fix:** Verify your workload is registered:
```bash
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show
```

### 🚨 "Permission denied accessing socket"
**Quick Fix:** Make sure your container can access the socket:
```bash
kubectl exec -n spire-workload -it deployment/my-test-service -- \
  ls -la /run/spire/sockets/
```

## What's Next?

🎯 **Now that you have SPIFFE working:**

1. **Try service-to-service mTLS** - Use your SPIFFE identity to secure communication between services
2. **Experiment with policies** - Create different registration entries with different selectors
3. **Monitor certificate rotation** - Watch how SPIRE automatically rotates your certificates
4. **Explore federation** - Learn how to connect multiple SPIRE deployments

## Quick Commands Reference

```bash
# Check SPIRE health
kubectl get pods -n spire-server
kubectl get pods -n spire-system

# View all registered workloads
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show

# Register a new workload
./scripts/register-workload.sh --name my-app --service-account my-app --workload-ns production

# Check workload logs
kubectl logs -n spire-workload -l app=my-test-service

# Test socket access
kubectl exec -n spire-workload deployment/my-test-service -- ls -la /run/spire/sockets/
```

## Learn More

- **📖 Comprehensive Guide**: [Workload Integration Guide](workload_integration_guide.md)
- **🔧 Troubleshooting**: [Common Issues and Solutions](troubleshooting.md)  
- **🏗️ Architecture**: [How SPIRE Works](architecture_diagrams.md)
- **📚 SPIFFE Docs**: [Official SPIFFE Documentation](https://spiffe.io/docs/)