# SPIRE Workload Integration Guide

This comprehensive guide provides step-by-step instructions for integrating new workloads with SPIRE Server, including both workload-side integration and server-side registration entry creation.

## Overview

Adding a new workload to SPIRE involves two main components:
1. **Workload Integration**: Configuring the workload to request and use SPIFFE identity
2. **Server Registration**: Creating registration entries in the SPIRE server database

This guide provides complete examples for both workload owners and SPIRE administrators.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Part 1: Workload Integration (For Workload Owners)](#part-1-workload-integration-for-workload-owners)
- [Part 2: Server-Side Registration (For SPIRE Administrators)](#part-2-server-side-registration-for-spire-administrators)
- [Complete Working Examples](#complete-working-examples)
- [Verification Steps](#verification-steps)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- SPIRE Server deployed and running
- SPIRE Agent deployed on nodes where workloads will run
- Kubernetes cluster with appropriate RBAC permissions
- Trust domain configured (e.g., `example.org`)

## Part 1: Workload Integration (For Workload Owners)

### Step 1: Configure Workload to Access SPIRE Agent Socket

Your workload needs to mount the SPIRE agent socket to request SVIDs:

```yaml
# Essential volume mount configuration
volumeMounts:
- name: spire-agent-socket
  mountPath: /run/spire/sockets
  readOnly: true

volumes:
- name: spire-agent-socket
  hostPath:
    path: /run/spire/sockets
    type: Directory
```

### Step 2: Set Environment Variables

Configure the SPIFFE endpoint:

```yaml
env:
- name: SPIFFE_ENDPOINT_SOCKET
  value: "unix:///run/spire/sockets/agent.sock"
```

### Step 3: Configure Pod Labels and Annotations

Add required labels that SPIRE will use for workload identification:

```yaml
metadata:
  labels:
    app: your-service-name
    service: your-service-type  # e.g., payment-processing
    version: v1.0.0
  annotations:
    # Optional: For CRD-free deployments
    spire.io/spiffe-id: "spiffe://example.org/workload/your-service"
```

### Step 4: Create ServiceAccount

Each workload needs its own ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: your-service-name
  namespace: workload
```

### Step 5: Implement SPIFFE Client Code

Here's an example in different languages:

#### Go Example

```go
package main

import (
    "context"
    "crypto/tls"
    "fmt"
    "log"
    
    "github.com/spiffe/go-spiffe/v2/spiffeid"
    "github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func main() {
    // Create a workload API client
    ctx := context.Background()
    source, err := workloadapi.NewX509Source(ctx)
    if err != nil {
        log.Fatalf("Unable to create X509Source: %v", err)
    }
    defer source.Close()

    // Get SVID
    svid, err := source.GetX509SVID()
    if err != nil {
        log.Fatalf("Unable to fetch SVID: %v", err)
    }

    fmt.Printf("SPIFFE ID: %s\n", svid.ID)

    // Create TLS config for mutual authentication
    tlsConfig := tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeAny())
    
    // Use tlsConfig for HTTPS requests
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: tlsConfig,
        },
    }
    
    // Your application logic here
}
```

#### Python Example

```python
import os
from pyspiffe import WorkloadApiClient
from pyspiffe.spiffe_id import SpiffeId

def main():
    # Create workload API client
    client = WorkloadApiClient()
    
    try:
        # Fetch X.509 SVID
        x509_svid = client.fetch_x509_svid()
        print(f"SPIFFE ID: {x509_svid.spiffe_id}")
        
        # Fetch X.509 bundles for trust domain validation
        x509_bundles = client.fetch_x509_bundles()
        
        # Use SVID for secure communication
        # Your application logic here
        
    except Exception as e:
        print(f"Error fetching SVID: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    main()
```

#### Java Example

```java
import io.spiffe.exception.SocketEndpointAddressException;
import io.spiffe.workloadapi.DefaultWorkloadApiClient;
import io.spiffe.workloadapi.WorkloadApiClient;
import io.spiffe.svid.x509.X509Svid;

public class SpiffeWorkload {
    public static void main(String[] args) {
        try {
            // Create workload API client
            WorkloadApiClient client = DefaultWorkloadApiClient.newClient();
            
            // Fetch X.509 SVID
            X509Svid svid = client.fetchX509Svid();
            System.out.println("SPIFFE ID: " + svid.getSpiffeId());
            
            // Use SVID for secure communication
            // Your application logic here
            
        } catch (Exception e) {
            System.err.println("Error fetching SVID: " + e.getMessage());
        }
    }
}
```

## Part 2: Server-Side Registration (For SPIRE Administrators)

### Method 1: Using spire-server CLI

#### Step 1: Access SPIRE Server

```bash
# Connect to SPIRE server pod
kubectl exec -n spire-server -it deployment/spire-server -- /bin/sh
```

#### Step 2: Create Registration Entry

```bash
# Basic registration entry
/opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/your-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:workload \
  -selector k8s:sa:your-service-name \
  -selector k8s:pod-label:app:your-service-name \
  -ttl 1800

# With DNS names for service mesh integration
/opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/your-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:workload \
  -selector k8s:sa:your-service-name \
  -selector k8s:pod-label:app:your-service-name \
  -dnsName your-service.workload.svc.cluster.local \
  -ttl 1800
```

#### Step 3: Verify Registration

```bash
# List all entries
/opt/spire/bin/spire-server entry show

# List specific entry
/opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/your-service
```

### Method 2: Using Kubernetes Job

Create a Kubernetes Job for automated registration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: register-your-service
  namespace: spire-server
data:
  register.sh: |
    #!/bin/bash
    set -e
    
    echo "Registering your-service workload..."
    
    /opt/spire/bin/spire-server entry create \
      -spiffeID spiffe://example.org/workload/your-service \
      -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
      -selector k8s:ns:workload \
      -selector k8s:sa:your-service-name \
      -selector k8s:pod-label:app:your-service-name \
      -ttl 1800
    
    echo "Registration completed successfully"
    
    # Verify registration
    /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/your-service
---
apiVersion: batch/v1
kind: Job
metadata:
  name: register-your-service
  namespace: spire-server
spec:
  template:
    spec:
      serviceAccountName: spire-server
      containers:
      - name: registrar
        image: ghcr.io/spiffe/spire-server:1.12.4
        command: ["/bin/sh"]
        args: ["/config/register.sh"]
        volumeMounts:
        - name: spire-config-volume
          mountPath: /run/spire/config
          readOnly: true
        - name: spire-data-volume
          mountPath: /run/spire/data
        - name: registration-script
          mountPath: /config
      volumes:
      - name: spire-config-volume
        configMap:
          name: spire-server
      - name: spire-data-volume
        persistentVolumeClaim:
          claimName: spire-server-data
      - name: registration-script
        configMap:
          name: register-your-service
          defaultMode: 0755
      restartPolicy: Never
  backoffLimit: 3
```

### Method 3: Using Helm Values

Add your workload to the Helm values file:

```yaml
# In values.yaml
registrationEntries:
  enabled: true
  entries:
    # Your new workload entry
    - spiffeId: "spiffe://example.org/workload/your-service"
      parentId: "spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster"
      selectors:
        - "k8s:ns:workload"
        - "k8s:sa:your-service-name"
        - "k8s:pod-label:app:your-service-name"
        - "k8s:pod-label:service:your-service-type"
      ttl: 1800
      dnsNames:
        - "your-service.workload.svc.cluster.local"
```

## Complete Working Examples

### Example 1: Simple HTTP Service

This example shows a complete integration for a simple HTTP service.

#### Workload Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-service
  namespace: workload
  labels:
    app: http-service
spec:
  replicas: 1  # For learning; use 2+ for production
  selector:
    matchLabels:
      app: http-service
  template:
    metadata:
      labels:
        app: http-service
        service: web-api
        version: v1.0.0
    spec:
      serviceAccountName: http-service
      containers:
      - name: http-service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        - name: SERVICE_NAME
          value: "http-service"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
        - name: service-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
      - name: service-config
        configMap:
          name: http-service-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: http-service
  namespace: workload
---
apiVersion: v1
kind: Service
metadata:
  name: http-service
  namespace: workload
  labels:
    app: http-service
spec:
  selector:
    app: http-service
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: http-service-config
  namespace: workload
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

#### Registration Entry

```bash
# Create registration entry for http-service
kubectl exec -n spire-server -it deployment/spire-server -- /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/http-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:workload \
  -selector k8s:sa:http-service \
  -selector k8s:pod-label:app:http-service \
  -selector k8s:pod-label:service:web-api \
  -dnsName http-service.workload.svc.cluster.local \
  -ttl 1800
```

### Example 2: Database Client Service

This example shows a service that connects to a database using SPIFFE identities.

#### Workload Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-client-service
  namespace: workload
  labels:
    app: db-client-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-client-service
  template:
    metadata:
      labels:
        app: db-client-service
        service: database-client
        tier: backend
    spec:
      serviceAccountName: db-client-service
      containers:
      - name: db-client
        image: mysql:8.0
        command:
        - /bin/bash
        - -c
        - |
          echo "Starting database client with SPIFFE integration"
          
          # Wait for SPIFFE socket
          while [ ! -S /run/spire/sockets/agent.sock ]; do
            echo "Waiting for SPIRE agent socket..."
            sleep 2
          done
          
          echo "SPIRE agent socket available"
          
          # Your database client application would start here
          # This is just a placeholder
          while true; do
            echo "$(date): Database client running with SPIFFE identity"
            sleep 30
          done
        env:
        - name: SPIFFE_ENDPOINT_SOCKET
          value: "unix:///run/spire/sockets/agent.sock"
        - name: SERVICE_NAME
          value: "db-client-service"
        - name: DATABASE_HOST
          value: "mysql.database.svc.cluster.local"
        - name: DATABASE_PORT
          value: "3306"
        - name: DATABASE_NAME
          value: "app_database"
        volumeMounts:
        - name: spire-agent-socket
          mountPath: /run/spire/sockets
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          runAsUser: 999
          runAsGroup: 999
          readOnlyRootFilesystem: false
          allowPrivilegeEscalation: false
      volumes:
      - name: spire-agent-socket
        hostPath:
          path: /run/spire/sockets
          type: Directory
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: db-client-service
  namespace: workload
```

#### Registration Entry

```bash
# Create registration entry for db-client-service
kubectl exec -n spire-server -it deployment/spire-server -- /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/db-client-service \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:workload \
  -selector k8s:sa:db-client-service \
  -selector k8s:pod-label:app:db-client-service \
  -selector k8s:pod-label:service:database-client \
  -selector k8s:pod-label:tier:backend \
  -ttl 3600
```

## Verification Steps

### 1. Verify Workload Deployment

```bash
# Check pod status
kubectl get pods -n workload -l app=your-service-name

# Check pod logs
kubectl logs -n workload -l app=your-service-name

# Check ServiceAccount
kubectl get serviceaccount -n workload your-service-name
```

### 2. Verify SPIRE Registration

```bash
# List all registration entries
kubectl exec -n spire-server -it deployment/spire-server -- /opt/spire/bin/spire-server entry show

# Check specific entry
kubectl exec -n spire-server -it deployment/spire-server -- /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://example.org/workload/your-service

# Check agent entries
kubectl exec -n spire-server -it deployment/spire-server -- /opt/spire/bin/spire-server agent list
```

### 3. Verify SVID Issuance

```bash
# Check if workload can fetch SVID
kubectl exec -n workload -it deployment/your-service -- \
  /bin/sh -c 'ls -la /run/spire/sockets/'

# Test SPIFFE endpoint (if spiffe-helper is available)
kubectl exec -n workload -it deployment/your-service -- \
  /usr/bin/spiffe-helper -config /opt/spiffe-helper.conf
```

### 4. Test Mutual Authentication

Create a test pod to verify mutual TLS:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spiffe-test
  namespace: workload
spec:
  serviceAccountName: your-service-name
  containers:
  - name: test
    image: curlimages/curl:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
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
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "No SPIRE agent socket found"

**Symptoms:**
- Workload cannot find `/run/spire/sockets/agent.sock`
- Error: `connection refused` or `no such file or directory`

**Solutions:**
- Verify SPIRE agent is running: `kubectl get pods -n spire-system -l app=spire-agent`
- Check volume mount configuration in workload pod
- Ensure hostPath is correct: `/run/spire/sockets`
- Verify node has SPIRE agent deployed (DaemonSet)

#### 2. "Registration entry not found"

**Symptoms:**
- Workload cannot obtain SVID
- Error: `no identity issued`

**Solutions:**
- Verify registration entry exists: `spire-server entry show`
- Check selectors match pod labels exactly
- Verify parentID matches agent SPIFFE ID
- Check TTL hasn't expired

#### 3. "Permission denied accessing socket"

**Symptoms:**
- Socket exists but workload cannot access it
- Permission errors in logs

**Solutions:**
- Check pod security context
- Verify user/group IDs
- Ensure socket permissions are correct
- Check SELinux/AppArmor policies

#### 4. "Invalid SPIFFE ID format"

**Symptoms:**
- Registration fails with format error

**Solutions:**
- Verify SPIFFE ID follows format: `spiffe://trust-domain/path`
- Ensure trust domain matches server configuration
- Check for invalid characters in path

#### 5. "Agent not attested"

**Symptoms:**
- Agent shows as not attested
- Workloads cannot get identities

**Solutions:**
- Check agent configuration matches server
- Verify node attestation is working
- Check agent logs for attestation errors
- Ensure proper RBAC permissions

### Debug Commands

```bash
# Check SPIRE server logs
kubectl logs -n spire-server deployment/spire-server

# Check SPIRE agent logs
kubectl logs -n spire-system daemonset/spire-agent

# Check workload logs
kubectl logs -n workload deployment/your-service

# Describe pod for configuration issues
kubectl describe pod -n workload -l app=your-service

# Check events
kubectl get events -n workload --sort-by='.lastTimestamp'
```

## Best Practices

### Security Considerations

1. **Principle of Least Privilege**: Only grant minimal required selectors
2. **TTL Management**: Use appropriate TTL values based on workload requirements
3. **Namespace Isolation**: Deploy workloads in dedicated namespaces
4. **ServiceAccount Separation**: Use unique ServiceAccounts per workload
5. **Regular Rotation**: Monitor and manage certificate rotation

### Performance Optimization

1. **Cache Configuration**: Configure appropriate cache sizes
2. **Batch Operations**: Register multiple entries in batches when possible
3. **Resource Limits**: Set appropriate resource limits for workloads
4. **Monitoring**: Implement monitoring for SVID renewal and usage

### Operational Guidelines

1. **Documentation**: Document all workload integrations and their purposes
2. **Naming Conventions**: Use consistent naming for services and SPIFFE IDs
3. **Automation**: Automate registration processes where possible
4. **Testing**: Test workload integration in development environments first
5. **Backup**: Regularly backup registration entries and configurations

## Conclusion

This guide provides comprehensive instructions for both workload owners and SPIRE administrators to successfully integrate new workloads with SPIRE. Follow the appropriate sections based on your role and use the provided examples as templates for your specific use cases.

For additional support or questions, refer to the SPIFFE/SPIRE official documentation or consult your organization's SPIRE administrators.