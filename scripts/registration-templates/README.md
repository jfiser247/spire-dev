# SPIRE Registration Templates

This directory contains pre-built Kubernetes Job templates for registering common workload patterns with SPIRE Server. These templates provide a convenient way to register multiple services at once and can be customized for your specific use cases.

## Available Templates

### 1. Basic Workload Registration (`basic-workload-registration.yaml`)

Registers a simple HTTP service workload.

**Registers:**
- `basic-http-service` - A basic web API service

**Usage:**
```bash
kubectl apply -f basic-workload-registration.yaml
kubectl logs -n spire-server job/register-basic-workload
```

**SPIFFE ID:** `spiffe://example.org/workload/basic-http-service`

### 2. Multi-Service Registration (`multi-service-registration.yaml`)

Registers multiple enterprise services in a typical microservices architecture.

**Registers:**
- `api-gateway` - API gateway service (TTL: 3600s)
- `user-service` - User management service (TTL: 1800s)
- `payment-api` - Payment processing API (TTL: 900s)
- `notification-service` - Messaging service (TTL: 1800s)
- `analytics-service` - Analytics service (TTL: 3600s)
- `database-proxy` - Database proxy service (TTL: 7200s)

**Usage:**
```bash
kubectl apply -f multi-service-registration.yaml
kubectl logs -n spire-server job/register-multi-service
```

### 3. Database Service Registration (`database-service-registration.yaml`)

Registers services that interact with databases and caches.

**Registers:**
- `database-client-service` - Database client service
- `postgres-proxy` - PostgreSQL proxy for secure database connections
- `redis-client` - Redis cache client service

**Usage:**
```bash
kubectl apply -f database-service-registration.yaml
kubectl logs -n spire-server job/register-database-service
```

## How to Use Templates

### Step 1: Review and Customize

Before applying any template, review the registration details and customize as needed:

1. **Trust Domain**: Update `spiffe://example.org` to your trust domain
2. **Namespaces**: Adjust target namespaces (default: `workload`, `production`, `database`)
3. **Service Names**: Modify service names to match your applications
4. **Selectors**: Update pod labels and selectors
5. **TTL Values**: Adjust certificate TTL based on security requirements
6. **DNS Names**: Update DNS names to match your service naming

### Step 2: Apply the Template

```bash
# Apply the registration template
kubectl apply -f <template-name>.yaml

# Monitor the job
kubectl get jobs -n spire-server -l app=spire-registration

# Check logs
kubectl logs -n spire-server job/<job-name>
```

### Step 3: Verify Registration

```bash
# Connect to SPIRE server
kubectl exec -n spire-server -it deployment/spire-server -- /bin/sh

# List all registration entries
/opt/spire/bin/spire-server entry show

# Check specific entry
/opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/your-service
```

## Creating Custom Templates

### Template Structure

Each template consists of:
1. **ConfigMap** - Contains the registration script
2. **Job** - Executes the registration script using SPIRE server image

### Basic Template Format

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
    
    echo "Creating registration entry for your-service..."
    /opt/spire/bin/spire-server entry create \
      -spiffeID spiffe://your-trust-domain/workload/your-service \
      -parentID spiffe://your-trust-domain/spire/agent/k8s_psat/your-cluster \
      -selector k8s:ns:your-namespace \
      -selector k8s:sa:your-service-account \
      -selector k8s:pod-label:app:your-service \
      -ttl 1800
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
      restartPolicy: Never
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
  backoffLimit: 3
```

### Common Registration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-spiffeID` | Unique SPIFFE ID for the workload | `spiffe://example.org/workload/my-service` |
| `-parentID` | Parent SPIFFE ID (usually the agent) | `spiffe://example.org/spire/agent/k8s_psat/cluster` |
| `-selector` | Workload selector for identity assignment | `k8s:ns:production`, `k8s:sa:my-service` |
| `-ttl` | Certificate time-to-live in seconds | `1800` (30 minutes) |
| `-dnsName` | DNS subject alternative name | `my-service.production.svc.cluster.local` |

### Common Selectors

| Selector Type | Format | Example |
|---------------|---------|---------|
| Namespace | `k8s:ns:<namespace>` | `k8s:ns:production` |
| Service Account | `k8s:sa:<service-account>` | `k8s:sa:my-service` |
| Pod Label | `k8s:pod-label:<key>:<value>` | `k8s:pod-label:app:my-service` |
| Container Image | `k8s:container-image:<image>` | `k8s:container-image:my-app:v1.0` |
| Node Name | `k8s:node-name:<name>` | `k8s:node-name:worker-01` |

## Best Practices

### Security Considerations

1. **Least Privilege**: Use specific selectors to limit which pods can receive identities
2. **TTL Management**: Set appropriate TTL values based on workload sensitivity
3. **Namespace Isolation**: Use separate namespaces for different security zones
4. **Regular Rotation**: SPIRE automatically handles certificate rotation

### Operational Guidelines

1. **Naming Conventions**: Use consistent naming patterns for services and SPIFFE IDs
2. **Documentation**: Document the purpose and requirements for each registration
3. **Testing**: Test registrations in development environments first
4. **Monitoring**: Monitor registration job results and failures
5. **Cleanup**: Remove unused registration entries regularly

### TTL Recommendations

| Service Type | Recommended TTL | Reason |
|--------------|----------------|---------|
| High-Security (Payment, Auth) | 300-900s | Frequent rotation for security |
| Standard Services | 1800-3600s | Balance between security and performance |
| Infrastructure Services | 3600-7200s | Less frequent changes, stable workloads |
| Development/Testing | 300-1800s | Allow for rapid development cycles |

## Troubleshooting

### Job Failures

```bash
# Check job status
kubectl get jobs -n spire-server -l app=spire-registration

# Check job logs
kubectl logs -n spire-server job/<job-name>

# Describe job for more details
kubectl describe job -n spire-server <job-name>
```

### Common Issues

1. **SPIRE Server Not Ready**
   - Ensure SPIRE server is running and healthy
   - Check if persistent volume is mounted correctly

2. **Permission Errors**
   - Verify the job uses the correct ServiceAccount (`spire-server`)
   - Check RBAC permissions

3. **Duplicate Entries**
   - Registration will fail if SPIFFE ID already exists
   - Delete existing entry or use a different SPIFFE ID

4. **Invalid Selectors**
   - Ensure selectors match your workload pod labels exactly
   - Check namespace and service account names

### Verification Commands

```bash
# List all registration entries
kubectl exec -n spire-server -it deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show

# Check SPIRE server health
kubectl exec -n spire-server -it deployment/spire-server -- \
  /opt/spire/bin/spire-server healthcheck

# List SPIRE agents
kubectl exec -n spire-server -it deployment/spire-server -- \
  /opt/spire/bin/spire-server agent list
```

## Integration with CI/CD

### GitOps Integration

Include registration templates in your GitOps workflow:

```yaml
# .github/workflows/deploy.yaml
- name: Register SPIRE Workloads
  run: |
    kubectl apply -f k8s/spire-registration/
    kubectl wait --for=condition=complete --timeout=300s job/register-services -n spire-server
```

### Terraform Integration

Use Kubernetes provider to apply templates:

```hcl
resource "kubernetes_manifest" "spire_registration" {
  manifest = yamldecode(file("${path.module}/registration-templates/basic-workload-registration.yaml"))
}
```

## Related Documentation

- [Workload Integration Guide](../docs/workload_integration_guide.md)
- [SPIRE Server Configuration](../docs/spire-server-configuration.md)
- [Troubleshooting Guide](../docs/troubleshooting.md)
- [SPIFFE Documentation](https://spiffe.io/docs/)