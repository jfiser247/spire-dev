# Example SPIFFE Workload

This directory contains a complete working example of a Go application integrated with SPIFFE/SPIRE for secure service-to-service communication.

## Features

- **SPIFFE Identity Management**: Automatically fetches and manages SPIFFE SVIDs
- **Mutual TLS**: Supports both HTTP and HTTPS endpoints with mutual TLS authentication
- **Health Checks**: Kubernetes-compatible health check endpoints
- **Identity Information**: Exposes SPIFFE identity details via REST API
- **External Service Calls**: Demonstrates secure communication with other SPIFFE-enabled services
- **Production Ready**: Includes proper error handling, logging, and security contexts

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SPIRE Agent   │    │ Example Workload │    │ External Service│
│                 │◄──►│                  │◄──►│                 │
│ (Unix Socket)   │    │   (Go + SPIFFE)  │    │ (SPIFFE-enabled)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Quick Start

### 1. Build the Application

```bash
# Build Docker image
docker build -t example-workload:latest .

# Or build locally
go mod download
go build -o example-workload ./cmd/main.go
```

### 2. Deploy to Kubernetes

```bash
# Create namespace if it doesn't exist
kubectl create namespace workload

# Deploy the workload
kubectl apply -f k8s-deployment.yaml
```

### 3. Create SPIRE Registration Entry

```bash
# Connect to SPIRE server
kubectl exec -n spire-server -it deployment/spire-server -- /bin/sh

# Create registration entry
/opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/workload/example-workload \
  -parentID spiffe://example.org/spire/agent/k8s_psat/spire-server-cluster \
  -selector k8s:ns:workload \
  -selector k8s:sa:example-workload \
  -selector k8s:pod-label:app:example-workload \
  -selector k8s:pod-label:service:demonstration \
  -dnsName example-workload.workload.svc.cluster.local \
  -ttl 1800
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n workload -l app=example-workload

# Check logs
kubectl logs -n workload -l app=example-workload

# Port forward for testing
kubectl port-forward -n workload service/example-workload 8080:80
```

## API Endpoints

The workload exposes several endpoints for testing and monitoring:

### HTTP Endpoints (Port 8080)

- `GET /health` - Health check endpoint
- `GET /identity` - SPIFFE identity information
- `GET /secure` - Secure endpoint (works with both HTTP and HTTPS)
- `GET /call-external` - Call external SPIFFE service

### HTTPS Endpoints (Port 8443)

All HTTP endpoints are also available via HTTPS with mutual TLS authentication.

## Testing the Workload

### 1. Health Check

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "example-workload",
  "spiffe_id": "spiffe://example.org/workload/example-workload",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 2. Identity Information

```bash
curl http://localhost:8080/identity
```

Expected response:
```json
{
  "spiffe_id": "spiffe://example.org/workload/example-workload",
  "serial_number": "12345678901234567890",
  "not_before": "2024-01-15T10:00:00Z",
  "not_after": "2024-01-15T11:00:00Z",
  "dns_names": ["example-workload.workload.svc.cluster.local"]
}
```

### 3. Secure Endpoint

```bash
# HTTP call (shows unauthenticated)
curl http://localhost:8080/secure

# HTTPS with mutual TLS (requires SPIFFE client certificate)
curl --cert client.pem --key client-key.pem --cacert ca.pem https://localhost:8443/secure
```

### 4. External Service Call

```bash
curl "http://localhost:8080/call-external?target_url=https://other-service.workload.svc.cluster.local/secure&target_spiffe_id=spiffe://example.org/workload/other-service"
```

## Code Structure

```
example-workload/
├── cmd/
│   └── main.go                 # Main application with SPIFFE integration
├── k8s-deployment.yaml         # Kubernetes deployment manifests
├── Dockerfile                  # Multi-stage Docker build
├── go.mod                     # Go module dependencies
├── go.sum                     # Go module checksums
└── README.md                  # This file
```

## Key SPIFFE Integration Points

### 1. X509Source Creation

```go
source, err := workloadapi.NewX509Source(ctx)
if err != nil {
    return nil, fmt.Errorf("unable to create X509Source: %v", err)
}
```

### 2. SVID Retrieval

```go
svid, err := ws.source.GetX509SVID()
if err != nil {
    log.Printf("Error getting SVID: %v", err)
    return
}
```

### 3. Mutual TLS Configuration

```go
// Server-side mTLS
tlsConfig := tlsconfig.MTLSServerConfig(ws.source, ws.source, tlsconfig.AuthorizeAny())

// Client-side mTLS with specific target authorization
tlsConfig := tlsconfig.MTLSClientConfig(ws.source, ws.source, 
    tlsconfig.AuthorizeID(spiffeid.RequireFromString(targetSpiffeID)))
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SPIFFE_ENDPOINT_SOCKET` | `unix:///run/spire/sockets/agent.sock` | SPIRE agent socket path |
| `SERVICE_NAME` | `example-workload` | Service name for logging |
| `PORT` | `8080` | HTTP server port |

## Security Features

- **Non-root execution**: Runs as user ID 1000
- **Read-only filesystem**: Container filesystem is read-only
- **No privileged escalation**: Security context prevents privilege escalation
- **Dropped capabilities**: All Linux capabilities are dropped
- **Resource limits**: CPU and memory limits are enforced

## Troubleshooting

### Common Issues

1. **Cannot connect to SPIRE agent**
   - Verify SPIRE agent is running on the node
   - Check volume mount configuration
   - Ensure socket path is correct

2. **Registration entry not found**
   - Verify registration entry exists in SPIRE server
   - Check selectors match pod labels exactly
   - Ensure parentID is correct

3. **Mutual TLS authentication fails**
   - Verify both services have valid SVIDs
   - Check SPIFFE ID authorization logic
   - Ensure trust bundles are up to date

### Debug Commands

```bash
# Check pod logs
kubectl logs -n workload -l app=example-workload -f

# Describe pod for configuration issues
kubectl describe pod -n workload -l app=example-workload

# Check SPIRE registration
kubectl exec -n spire-server -it deployment/spire-server -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/workload/example-workload

# Test connectivity to SPIRE agent
kubectl exec -n workload -it deployment/example-workload -- \
  ls -la /run/spire/sockets/
```

## Production Considerations

1. **Image Security**: Use minimal base images and scan for vulnerabilities
2. **Resource Limits**: Set appropriate CPU and memory limits
3. **Health Checks**: Configure proper liveness and readiness probes
4. **Logging**: Implement structured logging for better observability
5. **Metrics**: Add Prometheus metrics for monitoring
6. **Secret Management**: Never hardcode sensitive information
7. **Certificate Rotation**: SPIRE handles automatic certificate rotation
8. **Network Policies**: Consider implementing Kubernetes network policies

## Next Steps

1. **Service Mesh Integration**: Integrate with Istio or other service meshes
2. **Monitoring**: Add Prometheus metrics and Grafana dashboards
3. **Tracing**: Implement distributed tracing with Jaeger or Zipkin
4. **Testing**: Add unit tests and integration tests
5. **CI/CD**: Set up automated build and deployment pipelines

## Related Documentation

- [SPIFFE/SPIRE Documentation](https://spiffe.io/docs/)
- [Go-SPIFFE Library](https://github.com/spiffe/go-spiffe)
- [Workload Integration Guide](../docs/workload_integration_guide.md)
- [SPIRE Server Configuration](../docs/spire-server-configuration.md)