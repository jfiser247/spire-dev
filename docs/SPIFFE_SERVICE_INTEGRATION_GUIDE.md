# SPIFFE Service Integration Guide

## 🎯 **For Service Owners: Integrating SPIFFE Identity into Your Applications**

This guide provides everything service owners need to know about integrating SPIFFE (Secure Production Identity Framework For Everyone) into their applications to obtain and use SPIFFE IDs for secure service-to-service communication.

---

## 📋 **Table of Contents**

1. [Understanding SPIFFE](#understanding-spiffe)
2. [Prerequisites](#prerequisites)
3. [Service Registration Process](#service-registration-process)
4. [Implementation Guide](#implementation-guide)
5. [Code Examples](#code-examples)
6. [Verification & Testing](#verification--testing)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)
9. [Support & Resources](#support--resources)

---

## 🔍 **Understanding SPIFFE**

### What is SPIFFE?
SPIFFE provides a secure identity framework for services in dynamic and heterogeneous environments. It eliminates the need for application-level authentication configurations and secrets.

### Key Benefits
- **Automatic Identity Management**: No more hardcoded secrets or certificates
- **Zero Trust Security**: Cryptographic identity verification for all services
- **Dynamic Environments**: Works seamlessly with containers, VMs, and cloud platforms
- **Industry Standard**: CNCF graduated project with broad ecosystem support

### Core Concepts
- **SPIFFE ID**: Unique identity URI (e.g., `spiffe://example.org/workload/user-service`)
- **SVID**: SPIFFE Verifiable Identity Document (X.509 certificate or JWT token)
- **Workload API**: API for retrieving SVIDs and trust bundles
- **SPIRE**: Production-ready implementation of SPIFFE

---

## ✅ **Prerequisites**

Before integrating SPIFFE into your service, ensure you have:

### Infrastructure Requirements
- ✅ **SPIRE Server**: Deployed and operational
- ✅ **SPIRE Agent**: Running on nodes where your service will deploy
- ✅ **Kubernetes/Container Platform**: If deploying in containerized environment
- ✅ **Network Access**: Service can reach SPIRE Agent's Workload API

### Development Requirements
- ✅ **SPIFFE Library**: Available for your programming language
- ✅ **Build Pipeline**: Ability to update your service's deployment configuration
- ✅ **Testing Environment**: Access to test SPIFFE integration before production

### Access Requirements
- ✅ **Registration Permissions**: Ability to register your service with SPIRE
- ✅ **Deployment Configuration**: Access to update Kubernetes manifests or deployment configs

---

## 📝 **Service Registration Process**

### Step 1: Plan Your SPIFFE ID Structure

Your SPIFFE ID should follow a consistent naming convention:

```
spiffe://<trust-domain>/<workload-type>/<service-name>
```

**Examples:**
- `spiffe://example.org/workload/user-service` - User management and authentication
- `spiffe://example.org/workload/payment-api` - Payment processing service
- `spiffe://example.org/workload/inventory-service` - Inventory management system

### Step 2: Determine Your Selectors

Selectors identify your workload to SPIRE. Common Kubernetes selectors:

```yaml
# Kubernetes namespace and service account
k8s:ns:production
k8s:sa:user-service

# Pod labels
k8s:pod-label:app:user-service
k8s:pod-label:version:v1.2.0

# Container image
k8s:container-image:my-company/user-service:latest
```

### Step 3: Create Registration Entry

Submit a registration request to your SPIRE administrator with:

```yaml
# Registration Request Template for User Service
service_name: "user-service"
spiffe_id: "spiffe://example.org/workload/user-service"
parent_id: "spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster"
selectors:
  - "k8s:ns:production"
  - "k8s:sa:user-service"
  - "k8s:pod-label:app:user-service"
  - "k8s:pod-label:service:user-management"
ttl: 1800  # 30 minutes (adjust based on your needs)
```

**Registration Command:**
```bash
# SPIRE administrator will run:
kubectl --context spire-server-cluster -n spire exec spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/user-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:production \
  -selector k8s:sa:user-service \
  -selector k8s:pod-label:app:user-service \
  -selector k8s:pod-label:service:user-management \
  -ttl 1800
```

---

## 🛠️ **Implementation Guide**

### Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Your Service  │    │   SPIRE Agent   │    │  SPIRE Server   │
│                 │    │                 │    │                 │
│ 1. Request SVID │───►│ 2. Validate     │───►│ 3. Issue SVID   │
│ 4. Receive SVID │◄───│    Workload     │◄───│    Certificate │
│ 5. Use for mTLS │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Integration Steps

#### 1. **Add SPIFFE Library Dependency**

Choose the appropriate library for your language:

| Language | Library | Package |
|----------|---------|---------|
| Go | go-spiffe | `github.com/spiffe/go-spiffe/v2` |
| Java | java-spiffe | `io.spiffe:spiffe-lib` |
| Python | py-spiffe | `pyspiffe` |
| Node.js | node-spiffe | `node-spiffe` |
| Rust | spiffe-rust | `spiffe` |
| C++ | cpp-spiffe | Build from source |

#### 2. **Update Deployment Configuration**

**Kubernetes Deployment Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        version: v1.2.0
        service: user-management
    spec:
      serviceAccountName: user-service  # Important: Matches selector
      containers:
      - name: user-service
        image: my-company/user-service:v1.2.0
        ports:
        - containerPort: 8080
        env:
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-service
  namespace: production
```

#### 3. **Initialize SPIFFE in Your Application**

The core pattern for all languages:

1. **Connect to Workload API**
2. **Fetch SVID and Trust Bundle**
3. **Configure TLS/mTLS**
4. **Handle SVID Rotation**

---

## 💻 **Code Examples**

### Go Implementation

```go
package main

import (
    "context"
    "crypto/tls"
    "fmt"
    "log"
    "net/http"
    "time"

    "github.com/spiffe/go-spiffe/v2/spiffeid"
    "github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Create a SPIFFE Workload API client
    source, err := workloadapi.NewX509Source(ctx)
    if err != nil {
        log.Fatalf("Unable to create X509Source: %v", err)
    }
    defer source.Close()

    // Create TLS configuration
    tlsConfig := tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeAny())
    
    // Create HTTPS server with mTLS
    server := &http.Server{
        Addr:      ":8443",
        TLSConfig: tlsConfig,
    }

    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/api/data", dataHandler(source))

    log.Println("Server starting on :8443 with SPIFFE mTLS")
    log.Fatal(server.ListenAndServeTLS("", ""))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, `{"status": "healthy", "timestamp": "%s"}`, time.Now().Format(time.RFC3339))
}

func dataHandler(source *workloadapi.X509Source) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Get current SVID
        svid, err := source.GetX509SVID()
        if err != nil {
            http.Error(w, "Failed to get SVID", http.StatusInternalServerError)
            return
        }

        w.Header().Set("Content-Type", "application/json")
        fmt.Fprintf(w, `{
            "spiffe_id": "%s",
            "serial_number": "%s",
            "not_after": "%s"
        }`, 
            svid.ID.String(), 
            svid.Certificates[0].SerialNumber.String(),
            svid.Certificates[0].NotAfter.Format(time.RFC3339))
    }
}
```

### Java Implementation

```java
package com.example.service;

import io.spiffe.exception.SocketEndpointAddressException;
import io.spiffe.workloadapi.DefaultWorkloadApiClient;
import io.spiffe.workloadapi.WorkloadApiClient;
import io.spiffe.workloadapi.X509Source;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.net.ssl.SSLContext;
import java.security.cert.X509Certificate;
import java.util.Map;

@SpringBootApplication
public class MyServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyServiceApplication.class, args);
    }
}

@Configuration
class SpiffeConfig {
    
    @Bean
    public X509Source x509Source() throws SocketEndpointAddressException {
        WorkloadApiClient client = DefaultWorkloadApiClient.newClient();
        return X509Source.newSource(client);
    }
    
    @Bean
    public SSLContext sslContext(X509Source x509Source) {
        return x509Source.getSSLContext();
    }
}

@RestController
class ApiController {
    
    private final X509Source x509Source;
    
    public ApiController(X509Source x509Source) {
        this.x509Source = x509Source;
    }
    
    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "status", "healthy",
            "timestamp", System.currentTimeMillis()
        );
    }
    
    @GetMapping("/api/identity")
    public Map<String, Object> getIdentity() {
        try {
            X509Certificate cert = x509Source.getX509SVID().getChain()[0];
            return Map.of(
                "spiffe_id", x509Source.getX509SVID().getSpiffeId().toString(),
                "serial_number", cert.getSerialNumber().toString(),
                "not_after", cert.getNotAfter().toString()
            );
        } catch (Exception e) {
            return Map.of("error", "Failed to get SVID: " + e.getMessage());
        }
    }
}
```

### Python Implementation

```python
import asyncio
import json
import ssl
from datetime import datetime
from aiohttp import web, ClientSession
from pyspiffe import workloadapi
from pyspiffe.spiffe_id import SpiffeId

class SpiffeService:
    def __init__(self):
        self.x509_source = None
    
    async def initialize(self):
        """Initialize SPIFFE X509 source"""
        self.x509_source = await workloadapi.fetch_x509_svid_async()
        
    async def get_ssl_context(self):
        """Create SSL context with SPIFFE certificates"""
        if not self.x509_source:
            await self.initialize()
            
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(
            certfile=None,  # Will use in-memory certificates
            keyfile=None
        )
        return ssl_context
    
    async def health_handler(self, request):
        """Health check endpoint"""
        return web.json_response({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    async def identity_handler(self, request):
        """Return current SPIFFE identity"""
        try:
            if not self.x509_source:
                await self.initialize()
                
            svid = self.x509_source.svid
            cert = svid.cert
            
            return web.json_response({
                "spiffe_id": str(svid.spiffe_id),
                "serial_number": str(cert.serial_number),
                "not_after": cert.not_valid_after.isoformat()
            })
        except Exception as e:
            return web.json_response(
                {"error": f"Failed to get SVID: {str(e)}"}, 
                status=500
            )

async def create_app():
    """Create and configure the web application"""
    service = SpiffeService()
    await service.initialize()
    
    app = web.Application()
    app.router.add_get('/health', service.health_handler)
    app.router.add_get('/api/identity', service.identity_handler)
    
    return app

if __name__ == '__main__':
    app = asyncio.run(create_app())
    web.run_app(app, host='0.0.0.0', port=8080, ssl_context=None)
```

### Node.js Implementation

```javascript
const express = require('express');
const spiffe = require('node-spiffe');
const https = require('https');

class SpiffeService {
    constructor() {
        this.x509Source = null;
        this.app = express();
        this.setupRoutes();
    }

    async initialize() {
        try {
            // Initialize SPIFFE Workload API client
            this.x509Source = await spiffe.WorkloadApi.newX509Source();
            console.log('SPIFFE X509 source initialized successfully');
        } catch (error) {
            console.error('Failed to initialize SPIFFE:', error);
            throw error;
        }
    }

    setupRoutes() {
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString()
            });
        });

        this.app.get('/api/identity', async (req, res) => {
            try {
                if (!this.x509Source) {
                    return res.status(500).json({ error: 'SPIFFE not initialized' });
                }

                const svid = await this.x509Source.getX509SVID();
                const cert = svid.certificates[0];

                res.json({
                    spiffe_id: svid.spiffeId.toString(),
                    serial_number: cert.serialNumber,
                    not_after: cert.validTo
                });
            } catch (error) {
                res.status(500).json({ 
                    error: `Failed to get SVID: ${error.message}` 
                });
            }
        });
    }

    async startServer() {
        await this.initialize();

        // Create HTTPS server with SPIFFE mTLS
        const tlsOptions = {
            key: this.x509Source.getPrivateKey(),
            cert: this.x509Source.getCertificates(),
            ca: this.x509Source.getTrustBundle(),
            requestCert: true,
            rejectUnauthorized: false // Handle authorization in application logic
        };

        const server = https.createServer(tlsOptions, this.app);
        
        server.listen(8443, () => {
            console.log('Server running on https://localhost:8443 with SPIFFE mTLS');
        });

        // Handle SVID rotation
        this.x509Source.onSVIDUpdate(() => {
            console.log('SVID updated, refreshing server certificates');
            // In production, you'd update the server's TLS configuration here
        });
    }
}

// Start the service
const service = new SpiffeService();
service.startServer().catch(console.error);
```

---

## ✅ **Verification & Testing**

### Step 1: Verify Registration

Check that your service is registered in SPIRE:

```bash
# Connect to SPIRE server
SERVER_POD=$(kubectl --context spire-server-cluster -n spire get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}')

# List all entries and find yours
kubectl --context spire-server-cluster -n spire exec $SERVER_POD -- \
  /opt/spire/bin/spire-server entry show

# Look for your SPIFFE ID in the output:
# Entry ID         : <entry-id>
# SPIFFE ID        : spiffe://example.org/workload/user-service
# Parent ID        : spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster
# Revision         : 0
# TTL              : 1800
# Selector         : k8s:ns:production
# Selector         : k8s:sa:user-service
```

### Step 2: Test SVID Retrieval

Create a test container to verify your service can get SVIDs:

```bash
# Deploy test pod with same selectors
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: spiffe-test-user-service
  namespace: production
  labels:
    app: user-service
spec:
  serviceAccountName: user-service
  containers:
  - name: spiffe-helper
    image: spiffe/spiffe-helper:latest
    command: ["sh", "-c", "while true; do sleep 30; done"]
    env:
    - name: SPIFFE_ENDPOINT_SOCKET
      value: "unix:///run/spire/sockets/agent.sock"
    volumeMounts:
    - name: spire-agent-socket
      mountPath: /run/spire/sockets
      readOnly: true
  volumes:
  - name: spire-agent-socket
    hostPath:
      path: /run/spire/sockets
      type: Directory
EOF

# Test SVID retrieval
kubectl exec -it spiffe-test-user-service -- \
  /opt/spiffe-helper/spiffe-helper api fetch x509
```

**Expected Output:**
```
SVID 0:
  SPIFFE ID: spiffe://example.org/workload/user-service
  Hint: internal
  TTL: 1795
  Trust Domain: example.org
```

### Step 3: Service Health Check

Test your service endpoints:

```bash
# Port forward to your service
kubectl port-forward -n production deployment/user-service 8080:8080

# Test health endpoint
curl http://localhost:8080/health

# Test identity endpoint
curl http://localhost:8080/api/identity
```

**Expected Response:**
```json
{
  "spiffe_id": "spiffe://example.org/workload/user-service",
  "serial_number": "123456789",
  "not_after": "2024-01-01T12:30:00Z"
}
```

### Step 4: mTLS Verification

Test mutual TLS between services:

```bash
# Create client certificate from SVID
kubectl exec spiffe-test-user-service -- \
  /opt/spiffe-helper/spiffe-helper api fetch x509 \
  -write /tmp/

# Test mTLS connection
kubectl exec spiffe-test-user-service -- \
  curl --cert /tmp/svid.crt --key /tmp/key.pem \
       --cacert /tmp/bundle.crt \
       https://user-service.production.svc.cluster.local:8443/api/identity
```

### Step 5: Monitor SPIRE Logs

Check SPIRE agent logs for your workload:

```bash
# Find agent pod
AGENT_POD=$(kubectl --context workload-cluster -n spire get pod -l app=spire-agent -o jsonpath='{.items[0].metadata.name}')

# Watch logs for your service attestation
kubectl --context workload-cluster -n spire logs -f $AGENT_POD | grep "user-service"
```

**Look for logs like:**
```
time="2024-01-01T10:00:00Z" level=info msg="Attestation completed" spiffe_id="spiffe://example.org/workload/user-service"
time="2024-01-01T10:00:00Z" level=info msg="SVID updated" spiffe_id="spiffe://example.org/workload/user-service"
```

---

## 🔧 **Troubleshooting**

### Common Issues and Solutions

#### Issue: "no such registration entry"

**Symptoms:**
```
ERROR: could not get SVID: rpc error: code = PermissionDenied desc = no such registration entry
```

**Solutions:**
1. Verify registration entry exists
2. Check selectors match your deployment
3. Ensure service account name is correct
4. Verify namespace matches

**Debug Commands:**
```bash
# Check your pod's actual selectors
kubectl get pod <your-pod> -o yaml | grep -A 10 -B 10 -E "(serviceAccount|labels)"

# Compare with registered selectors
kubectl --context spire-server-cluster -n spire exec spire-server-0 -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/user-service
```

#### Issue: "connection refused" to Workload API

**Symptoms:**
```
ERROR: connection refused: dial unix /run/spire/sockets/agent.sock: connect: connection refused
```

**Solutions:**
1. Verify SPIRE agent is running
2. Check socket mount path
3. Ensure agent socket permissions

**Debug Commands:**
```bash
# Check agent status
kubectl --context workload-cluster -n spire get pods -l app=spire-agent

# Verify socket exists
kubectl exec <your-pod> -- ls -la /run/spire/sockets/

# Check agent logs
kubectl --context workload-cluster -n spire logs -l app=spire-agent
```

#### Issue: Certificate validation errors

**Symptoms:**
```
ERROR: x509: certificate signed by unknown authority
```

**Solutions:**
1. Ensure trust bundle is properly loaded
2. Verify certificate chain
3. Check CA rotation

**Debug Commands:**
```bash
# Fetch and examine certificates
kubectl exec spiffe-test-user-service -- \
  /opt/spiffe-helper/spiffe-helper api fetch x509 -write /tmp/

kubectl exec spiffe-test-user-service -- \
  openssl x509 -in /tmp/svid.crt -text -noout
```

#### Issue: SVID not rotating

**Symptoms:**
- Certificate expires
- Application fails to get new SVID

**Solutions:**
1. Check TTL configuration
2. Verify rotation handling in code
3. Monitor agent connectivity

**Debug Commands:**
```bash
# Check TTL settings
kubectl --context spire-server-cluster -n spire exec spire-server-0 -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/user-service

# Monitor rotation events
kubectl --context workload-cluster -n spire logs -f -l app=spire-agent | grep rotation
```

### Performance Issues

#### High CPU/Memory Usage

**Causes:**
- Frequent SVID fetching
- Large trust bundles
- Certificate validation overhead

**Solutions:**
```go
// Cache SVIDs appropriately
source, err := workloadapi.NewX509Source(
    ctx,
    workloadapi.WithClientOptions(workloadapi.WithAddr("unix:///run/spire/sockets/agent.sock")),
)

// Use efficient TLS configuration
tlsConfig := &tls.Config{
    GetClientCertificate: func(*tls.CertificateRequestInfo) (*tls.Certificate, error) {
        return source.GetX509SVID().Certificates, nil
    },
    GetConfigForClient: func(*tls.ClientHelloInfo) (*tls.Config, error) {
        return tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeAny()), nil
    },
}
```

### Debugging Tools

#### SPIFFE Helper Container

Deploy a debugging container:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spiffe-debug
  namespace: production
spec:
  serviceAccountName: user-service
  containers:
  - name: debug
    image: spiffe/spiffe-helper:latest
    command: ["sleep", "3600"]
    env:
    - name: SPIFFE_ENDPOINT_SOCKET
      value: "unix:///run/spire/sockets/agent.sock"
    volumeMounts:
    - name: spire-agent-socket
      mountPath: /run/spire/sockets
      readOnly: true
  volumes:
  - name: spire-agent-socket
    hostPath:
      path: /run/spire/sockets
```

#### Custom Debug Script

```bash
#!/bin/bash
# spiffe-debug.sh - Debug SPIFFE integration

echo "=== SPIFFE Debug Information ==="
echo "Pod: $(hostname)"
echo "Namespace: $(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
echo "Service Account: $(cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d'.' -f2 | base64 -d | jq -r .kubernetes.serviceaccount.name)"
echo

echo "=== Socket Check ==="
ls -la /run/spire/sockets/
echo

echo "=== SVID Fetch Test ==="
/opt/spiffe-helper/spiffe-helper api fetch x509 || echo "FAILED"
echo

echo "=== Trust Bundle ==="
/opt/spiffe-helper/spiffe-helper api fetch bundle || echo "FAILED"
```

---

## ⭐ **Best Practices**

### Security Best Practices

#### 1. **Principle of Least Privilege**
```yaml
# Use specific selectors
selectors:
  - "k8s:ns:production"           # Specific namespace
  - "k8s:sa:user-service"          # Specific service account
  - "k8s:pod-label:app:user-service" # Specific application
  # Avoid overly broad selectors like just "k8s:ns:production"
```

#### 2. **Appropriate TTL Values**
```bash
# Short TTL for high-security environments
-ttl 900   # 15 minutes

# Standard TTL for most services
-ttl 1800  # 30 minutes

# Longer TTL for batch/background services
-ttl 3600  # 1 hour
```

#### 3. **Secure Socket Access**
```yaml
# Ensure read-only socket mount
volumeMounts:
- name: spire-agent-socket
  mountPath: /run/spire/sockets
  readOnly: true  # Important: prevent socket tampering
```

### Performance Best Practices

#### 1. **Efficient SVID Caching**
```go
// Good: Reuse X509Source across requests
var globalSource *workloadapi.X509Source

func init() {
    var err error
    globalSource, err = workloadapi.NewX509Source(context.Background())
    if err != nil {
        log.Fatal(err)
    }
}

// Bad: Creating new source for each request
func badHandler(w http.ResponseWriter, r *http.Request) {
    source, _ := workloadapi.NewX509Source(context.Background()) // DON'T DO THIS
    defer source.Close()
}
```

#### 2. **Connection Pooling**
```go
// Configure HTTP client for SPIFFE mTLS
client := &http.Client{
    Transport: &http.Transport{
        TLSClientConfig: tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeAny()),
        MaxIdleConns:    100,
        MaxIdleConnsPerHost: 10,
    },
    Timeout: 30 * time.Second,
}
```

### Operational Best Practices

#### 1. **Health Checks**
```go
func spiffeHealthCheck() error {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    _, err := globalSource.GetX509SVID()
    return err
}
```

#### 2. **Monitoring & Alerting**
```yaml
# Add SPIFFE-specific metrics
prometheus:
  enabled: true
  metrics:
    - spiffe_svid_expiry_seconds
    - spiffe_workload_api_errors_total
    - spiffe_certificate_rotation_total
```

#### 3. **Graceful Degradation**
```go
func serviceHandler(w http.ResponseWriter, r *http.Request) {
    // Try SPIFFE mTLS first
    if svid, err := globalSource.GetX509SVID(); err == nil {
        // Use SPIFFE identity
        handleWithSpiffe(w, r, svid)
    } else {
        // Fallback for development/testing
        log.Warn("SPIFFE unavailable, using fallback auth")
        handleWithFallback(w, r)
    }
}
```

### Development Best Practices

#### 1. **Environment Configuration**
```yaml
# Use environment-specific SPIFFE IDs
development:
  spiffe_id: "spiffe://dev.example.org/workload/user-service"
staging:
  spiffe_id: "spiffe://staging.example.org/workload/user-service"
production:
  spiffe_id: "spiffe://example.org/workload/user-service"
```

#### 2. **Testing Strategy**
```go
// Unit tests with mock SPIFFE
func TestWithMockSpiffe(t *testing.T) {
    mockSource := &mockX509Source{
        svid: createTestSVID(),
    }
    // Test your service logic
}

// Integration tests with real SPIFFE
func TestWithRealSpiffe(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }
    // Test with actual SPIRE setup
}
```

#### 3. **Documentation**
```yaml
# Document your service's SPIFFE requirements
metadata:
  annotations:
    spiffe.io/spiffe-id: "spiffe://example.org/workload/user-service"
    spiffe.io/selectors: "k8s:ns:production,k8s:sa:user-service"
    spiffe.io/ttl: "1800"
    spiffe.io/description: "User management service requiring database access"
```

---

## 🆘 **Support & Resources**

### Internal Support

- **SPIRE Administration Team**: Contact via `#spire-support` Slack channel
- **Platform Engineering**: For infrastructure and deployment issues
- **Security Team**: For policy and compliance questions

### Getting Help

#### 1. **Registration Requests**
Submit registration requests via:
- **Jira Ticket**: Create issue in `PLATFORM` project
- **Slack**: Post in `#spire-registration` channel
- **Email**: platform-team@company.com

**Required Information:**
- Service name and description
- Desired SPIFFE ID
- Target namespace and environment
- Required selectors
- TTL requirements
- Contact information

#### 2. **Integration Support**
For development help:
- **Documentation**: Internal SPIFFE wiki
- **Code Reviews**: Tag `@spiffe-reviewers` in PRs
- **Office Hours**: Tuesdays 2-3 PM, `#spire-office-hours`

#### 3. **Incident Response**
For production issues:
- **Severity 1**: Page on-call via PagerDuty
- **Severity 2-3**: Create incident in `#incidents` channel
- **Normal Issues**: Create support ticket

### Useful Resources

#### Official Documentation
- [SPIFFE Specification](https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE.md)
- [SPIRE Documentation](https://spiffe.io/docs/latest/spire-about/)
- [Workload API Specification](https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE_Workload_API.md)

#### Code Examples & Libraries
- [Go SPIFFE Library](https://github.com/spiffe/go-spiffe)
- [Java SPIFFE Library](https://github.com/spiffe/java-spiffe)
- [Python SPIFFE Library](https://github.com/spiffe/py-spiffe)
- [Node.js SPIFFE Library](https://github.com/spiffe/node-spiffe)

#### Community Resources
- [SPIFFE Community](https://spiffe.io/community/)
- [SPIFFE Slack](https://spiffe.slack.com)
- [GitHub Discussions](https://github.com/spiffe/spiffe/discussions)

#### Internal Tools
- [SPIRE Dashboard](./web-dashboard.html) - Monitor your service's SPIFFE status
- [Policy Viewer](./web-dashboard.html) - Browse registration entries
- [Metrics Dashboard](./web-dashboard.html) - SPIFFE performance metrics

---

## 📝 **Quick Reference**

### Common Commands

```bash
# Check if your service is registered
kubectl --context spire-server-cluster -n spire exec spire-server-0 -- \
  /opt/spire/bin/spire-server entry show | grep "user-service"

# Test SVID retrieval
kubectl exec -it <your-pod> -- \
  curl --unix-socket /run/spire/sockets/agent.sock \
  http://localhost/v1/svids

# Monitor SPIRE agent logs
kubectl --context workload-cluster -n spire logs -f -l app=spire-agent

# Debug certificate expiry
kubectl exec <your-pod> -- \
  openssl s_client -connect localhost:8443 -servername user-service
```

### Environment Variables

```bash
# Standard SPIFFE environment variables
export SPIFFE_ENDPOINT_SOCKET="unix:///run/spire/sockets/agent.sock"
export SPIFFE_TRUST_DOMAIN="example.org"

# Optional: Custom socket path
export SPIFFE_ENDPOINT_SOCKET="unix:///custom/path/agent.sock"
```

### Troubleshooting Checklist

- [ ] Registration entry exists and matches selectors
- [ ] SPIRE agent is running and healthy
- [ ] Socket is mounted and accessible
- [ ] Service account matches selector
- [ ] Namespace matches selector
- [ ] Pod labels match selectors
- [ ] Network connectivity to agent
- [ ] Proper error handling in code
- [ ] SVID rotation is handled
- [ ] Certificates are not expired

---

**Need immediate help?** Contact the platform team at `#spire-support` or create a support ticket.

**Contributing to this guide?** Submit PRs to improve documentation for the entire engineering team.

---
*Last updated: January 2024*
*Version: 1.0*