# SPIRE Security Policy Requirements

## Overview

SPIRE deployments have specific Kubernetes security policy requirements due to their need for privileged operations and hostPath volumes for agent-workload communication. This document outlines the required namespace security policies for successful SPIRE deployment.

## Namespace Security Policy Mapping

### Required Security Policies by Component

| Namespace | Component | Security Policy | Justification |
|-----------|-----------|----------------|---------------|
| `spire-server` | SPIRE Server, MySQL Database | **privileged** | Server requires persistent storage access and administrative operations |
| `spire-system` | SPIRE Agent | **privileged** | Agent requires hostPath volumes for Unix socket communication |
| `spire-workload` | Application Workloads | **privileged** | Workloads need access to SPIRE agent socket via hostPath volume |

### Security Policy Configuration

#### Privileged Policy (Required for SPIRE Components)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: spire-server  # or spire-system, spire-workload
  labels:
    name: spire-server
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

#### Why Not Restricted/Baseline?
Attempting to use `restricted` or `baseline` security policies will result in deployment failures:

```bash
# Error with restricted policy:
Error creating: pods "payment-api-56b57ccf95-xyz" is forbidden: 
violates PodSecurity "restricted:latest": restricted volume types 
(volume "spire-agent-socket" uses restricted volume type "hostPath")
```

## SPIRE-Specific Security Requirements

### 1. HostPath Volume Requirements

SPIRE agents communicate with workloads through Unix domain sockets mounted via hostPath volumes:

```yaml
# Required in workload deployments
volumes:
- name: spire-agent-socket
  hostPath:
    path: /run/spire/sockets
    type: Directory
```

**Security Implication**: HostPath volumes are considered privileged access and require `privileged` security policy.

### 2. Service Account Requirements

Each SPIRE component requires specific service accounts with appropriate RBAC permissions:

- **SPIRE Server**: Cluster-level access for node attestation
- **SPIRE Agent**: Node-level access for workload discovery  
- **Workload Services**: Namespace-level access for identity operations

### 3. Container Security Contexts

While namespaces require privileged policy, individual containers can still maintain security best practices:

```yaml
# Recommended container security context
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 1001
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

## Deployment Validation

### Pre-Deployment Checks

Before deploying SPIRE, verify namespace security policies:

```bash
# Check current namespace security policy
kubectl get namespace spire-workload -o yaml | grep pod-security

# Expected output:
pod-security.kubernetes.io/enforce: privileged
pod-security.kubernetes.io/audit: privileged  
pod-security.kubernetes.io/warn: privileged
```

### Common Deployment Issues

#### Issue 1: Restricted Policy on Workload Namespace
**Symptom**: 
```
deployment.apps/payment-api 0/3 0 0
ReplicaFailure: FailedCreate
```

**Solution**: Update namespace security policy to privileged

#### Issue 2: Service Account Not Found
**Symptom**:
```
Error creating: serviceaccount "payment-api" not found
```

**Solution**: Ensure namespace allows pod creation (privileged policy) before service accounts can be used

### Validation Script

```bash
#!/bin/bash
# validate-spire-security.sh

NAMESPACES=("spire-server" "spire-system" "spire-workload")

for ns in "${NAMESPACES[@]}"; do
    echo "Checking namespace: $ns"
    policy=$(kubectl get namespace $ns -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
    
    if [ "$policy" = "privileged" ]; then
        echo "✅ $ns: privileged (correct)"
    else
        echo "❌ $ns: $policy (should be privileged)"
        echo "   Fix with: kubectl label namespace $ns pod-security.kubernetes.io/enforce=privileged --overwrite"
    fi
    echo
done
```

## Security Considerations

### Risk Assessment

| Risk | Mitigation Strategy |
|------|-------------------|
| HostPath volume access | Limit to specific socket directories only (`/run/spire/sockets`) |
| Privileged namespace | Use network policies to isolate SPIRE traffic |
| Service account privileges | Follow principle of least privilege in RBAC configuration |
| Container escape | Use container security contexts with seccomp/AppArmor |

### Network Security

Even with privileged security policies, implement network-level controls:

```yaml
# Example network policy for SPIRE isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: spire-network-policy
  namespace: spire-system
spec:
  podSelector:
    matchLabels:
      app: spire-agent
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: spire-workload
```

## Production Recommendations

### 1. Separate SPIRE Infrastructure
- Deploy SPIRE components in dedicated namespaces
- Use separate node pools for SPIRE infrastructure when possible
- Implement resource quotas and limits

### 2. Monitoring and Auditing
- Enable audit logging for privileged namespace operations
- Monitor hostPath volume access patterns
- Track service account usage and permissions

### 3. Upgrade Considerations
- Test security policy changes in staging environments
- Validate SPIRE functionality after Kubernetes upgrades
- Monitor for new security policy features that might affect SPIRE

## Troubleshooting Guide

### Common Commands

```bash
# Check pod security violations
kubectl get events --field-selector reason=FailedCreate

# Describe failed deployments
kubectl describe deployment -n spire-workload payment-api

# Check namespace labels
kubectl get namespaces --show-labels | grep spire

# Validate workload pod creation
kubectl get pods -n spire-workload -w
```

### Quick Fixes

```bash
# Fix restricted namespace policy
kubectl label namespace spire-workload \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  --overwrite

# Restart failed deployments after policy fix
kubectl rollout restart deployment -n spire-workload --all
```

---

**Note**: These security policy requirements are specific to SPIFFE/SPIRE's architecture and communication patterns. While they require privileged access, the actual security risk is mitigated through SPIRE's identity verification and cryptographic attestation mechanisms.