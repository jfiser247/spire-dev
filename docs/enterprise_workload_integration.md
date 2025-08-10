# Enterprise Workload Integration Guide

This guide provides comprehensive instructions for integrating workloads with SPIRE in enterprise environments, including role separation, approval workflows, and production best practices.

## Enterprise Roles and Responsibilities

### Workload Owners
- **Application developers** who need SPIFFE identities for their services
- **DevOps engineers** responsible for application deployment and configuration
- **Service owners** who manage specific microservices or applications

### SPIRE Administrators
- **Platform engineers** who manage SPIRE infrastructure
- **Security engineers** who define identity policies and registration approval processes
- **Site reliability engineers** who monitor and maintain SPIRE deployments

## Prerequisites

### For Workload Owners
- Kubernetes cluster access with appropriate RBAC permissions
- Understanding of your application's deployment requirements
- Knowledge of your service's security and networking requirements

### For SPIRE Administrators  
- Full administrative access to SPIRE Server
- Kubernetes cluster administrative privileges
- Understanding of organizational identity and security policies

## Workload Owner Workflow

### Step 1: Prepare Integration Request

**Document your requirements:**
- **Service Name**: Unique identifier for your service
- **Namespace**: Kubernetes namespace where your service runs
- **ServiceAccount**: Kubernetes ServiceAccount your service uses
- **Selectors**: Labels, annotations, or other identifying characteristics
- **DNS Names**: Any DNS SANs needed for your service
- **TTL Requirements**: Certificate lifetime requirements (if different from defaults)
- **Business Justification**: Why your service needs SPIFFE identity

### Step 2: Prepare Your Workload Configuration

Add SPIRE integration to your Kubernetes manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        service: payment-processing
        version: v2.1.0
        team: payments
    spec:
      serviceAccountName: payment-service
      containers:
      - name: payment-service
        image: mycompany/payment-service:v2.1.0
        env:
        # SPIFFE Workload API endpoint
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        # Optional: Custom trust domain
        - name: SPIFFE_TRUST_DOMAIN
          value: "production.mycompany.com"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
        # Security context for production
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
      # Production-grade resource limits
      resources:
        requests:
          memory: "256Mi"
          cpu: "250m"
        limits:
          memory: "512Mi"
          cpu: "500m"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
    team: payments
---
# Optional: Service for external access
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
spec:
  selector:
    app: payment-service
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
```

### Step 3: Integrate SPIFFE SDK

**Choose appropriate SDK for your language:**

#### Go Integration
```go
package main

import (
    "context"
    "crypto/tls"
    "crypto/x509"
    "fmt"
    "log"
    "net/http"
    "time"

    "github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func main() {
    ctx := context.Background()

    // Create X509Source for automatic certificate rotation
    source, err := workloadapi.NewX509Source(ctx)
    if err != nil {
        log.Fatalf("Unable to create X509Source: %v", err)
    }
    defer source.Close()

    // Configure TLS for client connections
    tlsConfig := tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeAny())
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: tlsConfig,
        },
        Timeout: 30 * time.Second,
    }

    // Configure TLS for server
    serverTLSConfig := tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeAny())
    server := &http.Server{
        Addr:      ":8080",
        TLSConfig: serverTLSConfig,
        Handler:   http.HandlerFunc(handleRequest),
    }

    // Start server with mTLS
    log.Println("Starting server with SPIFFE mTLS...")
    log.Fatal(server.ListenAndServeTLS("", ""))
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
    // Extract peer SPIFFE ID
    if r.TLS != nil && len(r.TLS.PeerCertificates) > 0 {
        cert := r.TLS.PeerCertificates[0]
        for _, uri := range cert.URIs {
            if uri.Scheme == "spiffe" {
                fmt.Fprintf(w, "Hello from SPIFFE ID: %s\n", uri.String())
                return
            }
        }
    }
    fmt.Fprint(w, "Hello from SPIFFE service\n")
}
```

#### Python Integration
```python
import asyncio
import ssl
from pyspiffe import WorkloadApiClient, TlsConnection
from pyspiffe.spiffe_tls_connection import SpiffeTlsConnection

class PaymentService:
    def __init__(self):
        self.client = WorkloadApiClient()
        
    async def start_server(self):
        """Start server with SPIFFE mTLS"""
        # Get SPIFFE credentials
        x509_context = self.client.fetch_x509_context()
        
        # Configure SSL context with SPIFFE certificates
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(
            certfile=x509_context.default_svid.cert_chain(),
            keyfile=x509_context.default_svid.private_key()
        )
        ssl_context.verify_mode = ssl.CERT_REQUIRED
        ssl_context.check_hostname = False
        
        print(f"Server starting with SPIFFE ID: {x509_context.default_svid.spiffe_id}")
        
        # Start your application server here
        # Example with aiohttp, FastAPI, etc.
        
    async def make_authenticated_request(self, target_spiffe_id: str, url: str):
        """Make mTLS request to another SPIFFE service"""
        try:
            conn = SpiffeTlsConnection.create_client_connection(
                target_spiffe_id=target_spiffe_id,
                timeout=30
            )
            
            # Use connection for HTTP requests
            response = await conn.request("GET", url)
            return response
            
        except Exception as e:
            print(f"Request failed: {e}")
            return None
    
    def shutdown(self):
        """Cleanup resources"""
        self.client.close()

# Usage
async def main():
    service = PaymentService()
    try:
        await service.start_server()
    finally:
        service.shutdown()

if __name__ == "__main__":
    asyncio.run(main())
```

#### Java Integration
```java
package com.mycompany.payment;

import io.spiffe.workloadapi.DefaultWorkloadApiClient;
import io.spiffe.workloadapi.WorkloadApiClient;
import io.spiffe.svid.x509.X509Svid;
import io.spiffe.svid.x509.X509Context;

import javax.net.ssl.SSLContext;
import javax.net.ssl.KeyManager;
import javax.net.ssl.TrustManager;
import java.security.SecureRandom;

@Service
public class PaymentService {
    
    private WorkloadApiClient workloadApiClient;
    private X509Context x509Context;
    
    @PostConstruct
    public void initialize() {
        try {
            // Initialize SPIFFE Workload API client
            workloadApiClient = DefaultWorkloadApiClient.newClient();
            
            // Fetch X.509 context (certificates and trust bundle)
            x509Context = workloadApiClient.fetchX509Context();
            
            // Log SPIFFE ID
            X509Svid svid = x509Context.getDefaultSvid();
            log.info("Service initialized with SPIFFE ID: {}", svid.getSpiffeId());
            
        } catch (Exception e) {
            log.error("Failed to initialize SPIFFE client", e);
            throw new RuntimeException("SPIFFE initialization failed", e);
        }
    }
    
    public SSLContext createMTLSContext() throws Exception {
        // Create SSL context with SPIFFE certificates
        KeyManager[] keyManagers = x509Context.getKeyManager();
        TrustManager[] trustManagers = x509Context.getTrustManager();
        
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(keyManagers, trustManagers, new SecureRandom());
        
        return sslContext;
    }
    
    @PreDestroy
    public void cleanup() {
        if (workloadApiClient != null) {
            try {
                workloadApiClient.close();
            } catch (Exception e) {
                log.error("Error closing SPIFFE client", e);
            }
        }
    }
}
```

### Step 4: Submit Integration Request

**Create a formal request to SPIRE administrators including:**

1. **Service Documentation**
   - Service architecture diagram
   - Dependencies and communication patterns
   - Security requirements and compliance needs

2. **Technical Specifications**
   - Complete Kubernetes manifests
   - SPIFFE integration code samples
   - Testing and validation procedures

3. **Operational Requirements**
   - Deployment schedule and rollout plan
   - Monitoring and alerting requirements
   - Incident response procedures

## SPIRE Administrator Workflow

### Step 1: Review Integration Request

**Security Review Checklist:**
- [ ] Service follows principle of least privilege
- [ ] Appropriate selectors for workload identification
- [ ] Reasonable certificate TTL requirements
- [ ] Proper network segmentation and access controls
- [ ] Compliance with organizational security policies

**Technical Review Checklist:**
- [ ] Kubernetes manifests follow best practices
- [ ] SPIFFE SDK integration is correct
- [ ] Resource limits and security contexts are appropriate
- [ ] Service mesh integration (if applicable) is configured

### Step 2: Create Registration Entry

#### Option A: Using Registration Automation (Recommended)

```bash
# Enterprise registration with approval workflow
./scripts/enterprise-register-workload.sh \
  --name payment-service \
  --service-account payment-service \
  --workload-ns production \
  --service-type payment-processing \
  --team payments \
  --dns-names payment-service.production.svc.cluster.local \
  --ttl 3600 \
  --labels "version:v2.1.0,team:payments,environment:production" \
  --approver "alice@company.com" \
  --ticket "JIRA-12345"
```

#### Option B: Manual CLI Registration

```bash
# Connect to SPIRE server
kubectl exec -n spire-server -it deployment/spire-server -- /bin/sh

# Create registration entry with comprehensive selectors
/opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://production.mycompany.com/payment-service \
  -parentID spiffe://production.mycompany.com/spire/agent/k8s_psat/production-cluster \
  -selector k8s:ns:production \
  -selector k8s:sa:payment-service \
  -selector k8s:pod-label:app:payment-service \
  -selector k8s:pod-label:team:payments \
  -selector k8s:pod-label:version:v2.1.0 \
  -dnsName payment-service.production.svc.cluster.local \
  -ttl 3600

# Verify registration
/opt/spire/bin/spire-server entry show -spiffeID spiffe://production.mycompany.com/payment-service
```

#### Option C: GitOps Integration

```yaml
# spire-registrations/payment-service.yaml
apiVersion: spire.spiffe.io/v1alpha1
kind: SpiffeID
metadata:
  name: payment-service
  namespace: spire-server
spec:
  spiffeId: "spiffe://production.mycompany.com/payment-service"
  parentId: "spiffe://production.mycompany.com/spire/agent/k8s_psat/production-cluster"
  selectors:
    - "k8s:ns:production"
    - "k8s:sa:payment-service"
    - "k8s:pod-label:app:payment-service"
    - "k8s:pod-label:team:payments"
    - "k8s:pod-label:version:v2.1.0"
  dnsNames:
    - "payment-service.production.svc.cluster.local"
  ttl: 3600
  downstream: true
```

### Step 3: Implement Monitoring and Alerting

```yaml
# Prometheus monitoring for SPIFFE certificates
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spiffe-certificate-monitor
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-service
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Step 4: Configure Policy Enforcement

```bash
# Example: Configure federation policies
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server bundle set \
  -id spiffe://downstream.partner.com \
  -format spiffe \
  -path /tmp/downstream-bundle.json

# Configure trust domain policies
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-server-policies
  namespace: spire-server
data:
  federation-policy.json: |
    {
      "trust_domains": {
        "production.mycompany.com": {
          "federates_with": ["staging.mycompany.com", "partner.external.com"],
          "policies": {
            "certificate_lifetime_max": 3600,
            "allow_wildcard_dns": false
          }
        }
      }
    }
EOF
```

## Verification and Testing

### Automated Testing Pipeline

```bash
#!/bin/bash
# enterprise-spiffe-test.sh

set -e

SERVICE_NAME="payment-service"
NAMESPACE="production"
SPIFFE_ID="spiffe://production.mycompany.com/payment-service"

echo "🔍 Starting SPIFFE integration verification..."

# 1. Check registration exists
echo "Verifying SPIRE registration..."
kubectl exec -n spire-server deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show -spiffeID "$SPIFFE_ID" || {
    echo "❌ Registration not found"
    exit 1
}

# 2. Check workload deployment
echo "Verifying workload deployment..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/$SERVICE_NAME -n $NAMESPACE

# 3. Verify socket access
echo "Testing SPIRE agent socket access..."
kubectl exec -n $NAMESPACE deployment/$SERVICE_NAME -- \
  ls -la /run/spire/sockets/agent.sock || {
    echo "❌ SPIRE agent socket not accessible"
    exit 1
}

# 4. Test SVID retrieval
echo "Testing SVID retrieval..."
kubectl exec -n $NAMESPACE deployment/$SERVICE_NAME -- \
  timeout 10 /app/test-spiffe-client || {
    echo "❌ SVID retrieval failed"
    exit 1
}

# 5. Test inter-service communication
echo "Testing mTLS communication..."
kubectl exec -n $NAMESPACE deployment/$SERVICE_NAME -- \
  curl --max-time 10 -k https://other-service.production.svc.cluster.local:8443/health || {
    echo "❌ mTLS communication failed"
    exit 1
}

echo "✅ All SPIFFE integration tests passed!"
```

## Production Best Practices

### Certificate Management
- **TTL Selection**: Use appropriate certificate lifetimes (1-4 hours typical)
- **Rotation Monitoring**: Monitor certificate rotation and renewal
- **Emergency Procedures**: Have processes for certificate revocation and re-issuance

### Security Policies
- **Least Privilege**: Use minimal necessary selectors and permissions
- **Network Policies**: Implement Kubernetes NetworkPolicies for additional security
- **Audit Logging**: Enable comprehensive audit logging for all SPIRE operations

### Operational Excellence
- **Monitoring**: Implement comprehensive monitoring and alerting
- **Documentation**: Maintain up-to-date runbooks and procedures
- **Automation**: Use GitOps and automation for registration and policy management
- **Disaster Recovery**: Test backup and recovery procedures regularly

### Compliance and Governance
- **Access Control**: Implement proper RBAC for SPIRE administration
- **Change Management**: Use proper change management processes for SPIRE modifications
- **Compliance Reporting**: Generate regular compliance and security reports
- **Security Reviews**: Conduct regular security reviews and assessments

## Troubleshooting Common Enterprise Issues

### Registration Approval Delays
- **Issue**: Long approval times for workload registration
- **Solution**: Implement automated approval for pre-approved patterns

### Certificate Rotation Failures
- **Issue**: Applications fail during certificate rotation
- **Solution**: Implement proper SDK integration and graceful certificate handling

### Cross-Cluster Communication
- **Issue**: Services cannot communicate across federated clusters
- **Solution**: Verify federation configuration and trust bundle distribution

### Compliance and Audit Requirements
- **Issue**: Insufficient logging and audit trails
- **Solution**: Implement comprehensive logging, monitoring, and reporting

## Related Documentation

- **[Enterprise Architecture Diagrams](enterprise_architecture_diagram.md)** - Visual overview of enterprise SPIRE deployments
- **[Production Deployment Guide](enterprise_deployment_guide.md)** - Complete production deployment procedures
- **[Helm Deployment Guide](helm_deployment_guide.md)** - GitOps-ready Helm deployments
- **[CRD Requirements](enterprise_crd_requirements.md)** - Kubernetes operator patterns

## Support and Escalation

### Internal Support
1. **Documentation**: Check internal runbooks and procedures
2. **Platform Team**: Contact platform engineering team
3. **Security Team**: Escalate security-related issues to security team

### External Support
1. **SPIFFE Community**: Join SPIFFE Slack community
2. **Vendor Support**: Contact your SPIRE vendor for enterprise support
3. **Professional Services**: Engage professional services for complex implementations