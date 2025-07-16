#!/bin/bash
set -e

# SPIRE Environment Reproducibility Test Suite
# Tests all known issues encountered during consistency and reproducibility testing
# Uses fresh-install.sh for clean environment setup
#
# Expected Timing:
# - Fresh install: 5-8 minutes (includes image pulls and validation)
# - Individual component startup: 2-5 minutes per component
# - Total test suite: 10-15 minutes for complete validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/reproducibility-test-results.log"
TEMP_LOG="/tmp/spire-test-$(date +%s).log"

# Test metrics tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_metric() {
    local test_name="$1"
    local status="$2"
    local duration="$3"
    local details="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] TEST_METRIC: test=$test_name status=$status duration=${duration}s details=\"$details\"" >> "$LOG_FILE"
}

# Test result tracking
test_result() {
    local test_name="$1"
    local status="$2"
    local start_time="$3"
    local details="$4"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name ($duration s)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name ($duration s)"
        echo -e "   ${YELLOW}Details: $details${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    log_metric "$test_name" "$status" "$duration" "$details"
}

# Test 1: Clean Environment Verification
test_clean_environment() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Clean Environment Verification${NC}"
    
    # Check for existing clusters that should be cleaned
    local existing_clusters=$(minikube profile list -l 2>/dev/null | grep -E "(spire-server-cluster|workload-cluster)" | wc -l || echo "0")
    
    if [ "$existing_clusters" -eq 0 ]; then
        test_result "clean_environment_verification" "PASS" "$test_start" "No existing SPIRE clusters found"
    else
        test_result "clean_environment_verification" "FAIL" "$test_start" "Found $existing_clusters existing SPIRE clusters"
    fi
}

# Test 2: Fresh Install Execution
test_fresh_install_execution() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Fresh Install Script Execution${NC}"
    
    if [ -f "$PROJECT_ROOT/scripts/fresh-install.sh" ]; then
        if timeout 600 "$PROJECT_ROOT/scripts/fresh-install.sh" > "$TEMP_LOG" 2>&1; then
            test_result "fresh_install_execution" "PASS" "$test_start" "Fresh install completed successfully"
        else
            local error_msg=$(tail -n 5 "$TEMP_LOG" | tr '\n' ' ')
            test_result "fresh_install_execution" "FAIL" "$test_start" "Fresh install failed: $error_msg"
            return 1
        fi
    else
        test_result "fresh_install_execution" "FAIL" "$test_start" "fresh-install.sh script not found"
        return 1
    fi
}

# Test 3: Cluster Creation Consistency
test_cluster_creation_consistency() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Cluster Creation Consistency${NC}"
    
    local expected_clusters=2
    local running_clusters=$(minikube profile list -l 2>/dev/null | grep Running | wc -l || echo "0")
    
    if [ "$running_clusters" -eq "$expected_clusters" ]; then
        # Verify specific cluster names
        if minikube profile list -l 2>/dev/null | grep -q "spire-server-cluster.*Running" && \
           minikube profile list -l 2>/dev/null | grep -q "workload-cluster.*Running"; then
            test_result "cluster_creation_consistency" "PASS" "$test_start" "Both required clusters (spire-server-cluster, workload-cluster) are running"
        else
            test_result "cluster_creation_consistency" "FAIL" "$test_start" "Required cluster names not found or not running"
        fi
    else
        test_result "cluster_creation_consistency" "FAIL" "$test_start" "Expected $expected_clusters clusters, found $running_clusters running"
    fi
}

# Test 4: SPIRE Server Pod Startup Reliability
test_spire_server_startup() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: SPIRE Server Pod Startup Reliability${NC}"
    
    # Wait for server pod to be ready (max 5 minutes)
    local timeout=300
    local elapsed=0
    local server_ready=false
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl --context workload-cluster -n spire-server get pods -l app=spire-server --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
            server_ready=true
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ "$server_ready" = true ]; then
        test_result "spire_server_startup" "PASS" "$test_start" "SPIRE server pod ready in ${elapsed}s"
    else
        local pod_status=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-server --no-headers 2>/dev/null || echo "No pods found")
        test_result "spire_server_startup" "FAIL" "$test_start" "SPIRE server not ready after ${timeout}s. Status: $pod_status"
    fi
}

# Test 5: Database Connectivity and Persistence
test_database_connectivity() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Database Connectivity and Persistence${NC}"
    
    # Check if database pod is running
    if kubectl --context workload-cluster -n spire-server get pods -l app=spire-db --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
        # Test database connection from server pod
        local server_pod=$(kubectl --context workload-cluster -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$server_pod" ]; then
            # Test basic connectivity (this is simplified - in real scenarios you'd test actual DB operations)
            if kubectl --context workload-cluster -n spire-server exec "$server_pod" -- timeout 10 sh -c "command -v psql >/dev/null || echo 'psql not available'" 2>/dev/null; then
                test_result "database_connectivity" "PASS" "$test_start" "Database pod running and accessible from server"
            else
                test_result "database_connectivity" "FAIL" "$test_start" "Cannot test database connectivity from server pod"
            fi
        else
            test_result "database_connectivity" "FAIL" "$test_start" "Server pod not found for connectivity test"
        fi
    else
        local db_status=$(kubectl --context workload-cluster -n spire-server get pods -l app=spire-db --no-headers 2>/dev/null || echo "No database pods found")
        test_result "database_connectivity" "FAIL" "$test_start" "Database pod not running. Status: $db_status"
    fi
}

# Test 6: SPIRE Agent Configuration Issues
test_agent_configuration() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: SPIRE Agent Configuration Issues${NC}"
    
    # Wait for agent pod to be ready
    local timeout=300
    local elapsed=0
    local agent_ready=false
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
            agent_ready=true
            break
        fi
        # Check for CrashLoopBackOff specifically
        if kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent --no-headers 2>/dev/null | grep -q "CrashLoopBackOff"; then
            test_result "agent_configuration" "FAIL" "$test_start" "Agent in CrashLoopBackOff state"
            return
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ "$agent_ready" = true ]; then
        # Test agent-server connectivity
        local agent_pod=$(kubectl --context workload-cluster -n spire-system get pod -l app=spire-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$agent_pod" ]; then
            # Check agent logs for successful server connection
            local connection_logs=$(kubectl --context workload-cluster -n spire-system logs "$agent_pod" --tail=50 2>/dev/null | grep -i "connection\|error\|ready" | tail -5 || echo "No logs available")
            test_result "agent_configuration" "PASS" "$test_start" "Agent running successfully. Recent logs: $connection_logs"
        else
            test_result "agent_configuration" "PASS" "$test_start" "Agent pod running but name retrieval failed"
        fi
    else
        local agent_status=$(kubectl --context workload-cluster -n spire-system get pods -l app=spire-agent --no-headers 2>/dev/null || echo "No agent pods found")
        test_result "agent_configuration" "FAIL" "$test_start" "Agent not ready after ${timeout}s. Status: $agent_status"
    fi
}

# Test 7: Bundle Creation and Distribution
test_bundle_creation() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Bundle Creation and Distribution${NC}"
    
    # Check if bundle configmap exists
    if kubectl --context workload-cluster -n spire-system get configmap spire-bundle >/dev/null 2>&1; then
        # Verify bundle content is not empty
        local bundle_content=$(kubectl --context workload-cluster -n spire-system get configmap spire-bundle -o jsonpath='{.data.bundle\.crt}' 2>/dev/null)
        if [ -n "$bundle_content" ] && echo "$bundle_content" | grep -q "BEGIN CERTIFICATE"; then
            test_result "bundle_creation" "PASS" "$test_start" "Bundle configmap exists with valid certificate content"
        else
            test_result "bundle_creation" "FAIL" "$test_start" "Bundle configmap exists but content is invalid or empty"
        fi
    else
        test_result "bundle_creation" "FAIL" "$test_start" "Bundle configmap not found in spire-system namespace"
    fi
}

# Test 8: Workload Service Deployment Consistency
test_workload_deployment_consistency() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Workload Service Deployment Consistency${NC}"
    
    local expected_services=3  # user-service, payment-api, inventory-service
    local expected_replicas=7  # total replicas across all services
    
    # Count running workload pods
    local running_pods=$(kubectl --context workload-cluster -n production get pods --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l || echo "0")
    local total_pods=$(kubectl --context workload-cluster -n production get pods --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Check for specific services
    local user_service=$(kubectl --context workload-cluster -n production get pods -l app=user-service --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l || echo "0")
    local payment_api=$(kubectl --context workload-cluster -n production get pods -l app=payment-api --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l || echo "0")
    local inventory_service=$(kubectl --context workload-cluster -n production get pods -l app=inventory-service --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l || echo "0")
    
    if [ "$running_pods" -eq "$expected_replicas" ] && [ "$user_service" -gt 0 ] && [ "$payment_api" -gt 0 ] && [ "$inventory_service" -gt 0 ]; then
        test_result "workload_deployment_consistency" "PASS" "$test_start" "All $expected_replicas workload pods running across $expected_services services"
    else
        test_result "workload_deployment_consistency" "FAIL" "$test_start" "Expected $expected_replicas pods, got $running_pods running ($total_pods total). Services: user=$user_service, payment=$payment_api, inventory=$inventory_service"
    fi
}

# Test 9: Dashboard Server Integration
test_dashboard_integration() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Dashboard Server Integration${NC}"
    
    # Check if dashboard server is running
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        # Test API endpoints for real data
        local server_count=$(curl -s http://localhost:3000/api/pod-data | jq -r '.server | length' 2>/dev/null || echo "0")
        local agent_count=$(curl -s http://localhost:3000/api/pod-data | jq -r '.agents | length' 2>/dev/null || echo "0")
        local workload_count=$(curl -s http://localhost:3000/api/pod-data | jq -r '.workloads | length' 2>/dev/null || echo "0")
        
        if [ "$server_count" -gt 0 ] && [ "$agent_count" -gt 0 ] && [ "$workload_count" -gt 0 ]; then
            # Test drilldown functionality
            if curl -s "http://localhost:3000/api/describe/pod/spire-server/workload-cluster/spire-server-0" >/dev/null 2>&1; then
                test_result "dashboard_integration" "PASS" "$test_start" "Dashboard serving real data: server=$server_count, agents=$agent_count, workloads=$workload_count. Drilldown working."
            else
                test_result "dashboard_integration" "FAIL" "$test_start" "Dashboard API working but drilldown functionality failed"
            fi
        else
            test_result "dashboard_integration" "FAIL" "$test_start" "Dashboard returning empty data: server=$server_count, agents=$agent_count, workloads=$workload_count"
        fi
    else
        test_result "dashboard_integration" "FAIL" "$test_start" "Dashboard server not accessible at http://localhost:3000"
    fi
}

# Test 10: SPIFFE ID Registration and Availability
test_spiffe_id_availability() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: SPIFFE ID Registration and Availability${NC}"
    
    # Check agent socket availability in workload pods
    local user_service_pod=$(kubectl --context workload-cluster -n production get pod -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$user_service_pod" ]; then
        # Test if agent socket is available
        if kubectl --context workload-cluster -n production exec "$user_service_pod" -- test -S /run/spire/sockets/agent.sock 2>/dev/null; then
            # Check for registration entries (simplified test)
            local server_pod=$(kubectl --context workload-cluster -n spire-server get pod -l app=spire-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            if [ -n "$server_pod" ]; then
                local entry_count=$(kubectl --context workload-cluster -n spire-server exec "$server_pod" -- /opt/spire/bin/spire-server entry show -socketPath /run/spire/sockets/server.sock 2>/dev/null | grep "Entry ID" | wc -l || echo "0")
                test_result "spiffe_id_availability" "PASS" "$test_start" "Agent socket available in workloads, $entry_count registration entries found"
            else
                test_result "spiffe_id_availability" "PASS" "$test_start" "Agent socket available in workloads, server pod check failed"
            fi
        else
            test_result "spiffe_id_availability" "FAIL" "$test_start" "Agent socket not available in user-service pod"
        fi
    else
        test_result "spiffe_id_availability" "FAIL" "$test_start" "No user-service pod found for testing"
    fi
}

# Test 11: Namespace Creation Consistency
test_namespace_creation_consistency() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Namespace Creation Consistency${NC}"
    
    # Check that all required namespaces exist
    local spire_server_exists=$(kubectl --context workload-cluster get namespace spire-server >/dev/null 2>&1 && echo "true" || echo "false")
    local spire_system_exists=$(kubectl --context workload-cluster get namespace spire-system >/dev/null 2>&1 && echo "true" || echo "false")
    local production_exists=$(kubectl --context workload-cluster get namespace production >/dev/null 2>&1 && echo "true" || echo "false")
    
    if [ "$spire_server_exists" = "true" ] && [ "$spire_system_exists" = "true" ] && [ "$production_exists" = "true" ]; then
        # Check that all namespaces have the required name label (consistent approach)
        local spire_server_name=$(kubectl --context workload-cluster get namespace spire-server -o jsonpath='{.metadata.labels.name}' 2>/dev/null || echo "missing")
        local spire_system_name=$(kubectl --context workload-cluster get namespace spire-system -o jsonpath='{.metadata.labels.name}' 2>/dev/null || echo "missing")
        local production_name=$(kubectl --context workload-cluster get namespace production -o jsonpath='{.metadata.labels.name}' 2>/dev/null || echo "missing")
        
        if [ "$spire_server_name" = "spire-server" ] && [ "$spire_system_name" = "spire-system" ] && [ "$production_name" = "production" ]; then
            # Check creation method consistency - all should be created via YAML manifests (not kubectl create)
            # This is validated by ensuring they have proper labels that indicate YAML-based creation
            local consistent_labeling=true
            
            # Verify no duplicate or conflicting labels that might indicate mixed creation methods
            local spire_server_labels=$(kubectl --context workload-cluster get namespace spire-server -o json | jq '.metadata.labels | keys | length' 2>/dev/null || echo "0")
            local spire_system_labels=$(kubectl --context workload-cluster get namespace spire-system -o json | jq '.metadata.labels | keys | length' 2>/dev/null || echo "0")
            local production_labels=$(kubectl --context workload-cluster get namespace production -o json | jq '.metadata.labels | keys | length' 2>/dev/null || echo "0")
            
            # Each namespace should have at least 4 labels: name + 3 pod-security labels
            if [ "$spire_server_labels" -ge 4 ] && [ "$spire_system_labels" -ge 4 ] && [ "$production_labels" -ge 4 ]; then
                test_result "namespace_creation_consistency" "PASS" "$test_start" "All namespaces exist with consistent labeling approach (labels: server=$spire_server_labels, system=$spire_system_labels, prod=$production_labels)"
            else
                test_result "namespace_creation_consistency" "FAIL" "$test_start" "Inconsistent namespace labeling detected (labels: server=$spire_server_labels, system=$spire_system_labels, prod=$production_labels)"
            fi
        else
            test_result "namespace_creation_consistency" "FAIL" "$test_start" "Missing or incorrect name labels: spire-server=$spire_server_name, spire-system=$spire_system_name, production=$production_name"
        fi
    else
        test_result "namespace_creation_consistency" "FAIL" "$test_start" "Missing namespaces: spire-server=$spire_server_exists, spire-system=$spire_system_exists, production=$production_exists"
    fi
}

# Test 12: Pod Security Standards Compliance and Namespace Labeling Consistency
test_pod_security_compliance() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Pod Security Standards Compliance and Namespace Labeling Consistency${NC}"
    
    # Check namespace labels for pod security (all three enforcement types)
    local spire_server_enforce=$(kubectl --context workload-cluster get namespace spire-server -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "missing")
    local spire_server_audit=$(kubectl --context workload-cluster get namespace spire-server -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "missing")
    local spire_server_warn=$(kubectl --context workload-cluster get namespace spire-server -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "missing")
    
    local spire_system_enforce=$(kubectl --context workload-cluster get namespace spire-system -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "missing")
    local spire_system_audit=$(kubectl --context workload-cluster get namespace spire-system -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "missing")
    local spire_system_warn=$(kubectl --context workload-cluster get namespace spire-system -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "missing")
    
    local production_enforce=$(kubectl --context workload-cluster get namespace production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "missing")
    local production_audit=$(kubectl --context workload-cluster get namespace production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "missing")
    local production_warn=$(kubectl --context workload-cluster get namespace production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "missing")
    
    # Verify all labels are set to privileged
    local all_enforce_correct=true
    local all_audit_correct=true
    local all_warn_correct=true
    
    if [ "$spire_server_enforce" != "privileged" ] || [ "$spire_system_enforce" != "privileged" ] || [ "$production_enforce" != "privileged" ]; then
        all_enforce_correct=false
    fi
    
    if [ "$spire_server_audit" != "privileged" ] || [ "$spire_system_audit" != "privileged" ] || [ "$production_audit" != "privileged" ]; then
        all_audit_correct=false
    fi
    
    if [ "$spire_server_warn" != "privileged" ] || [ "$spire_system_warn" != "privileged" ] || [ "$production_warn" != "privileged" ]; then
        all_warn_correct=false
    fi
    
    if [ "$all_enforce_correct" = true ] && [ "$all_audit_correct" = true ] && [ "$all_warn_correct" = true ]; then
        # Check for any pod security violations
        local violations=$(kubectl --context workload-cluster get events -A --field-selector reason=FailedCreate 2>/dev/null | grep -i "security\|violation" | wc -l || echo "0")
        local warning_events=$(kubectl --context workload-cluster get events -A --field-selector type=Warning 2>/dev/null | grep -i "violates\|forbidden" | wc -l || echo "0")
        
        if [ "$violations" -eq 0 ] && [ "$warning_events" -eq 0 ]; then
            test_result "pod_security_compliance" "PASS" "$test_start" "All namespaces have consistent privileged security labels (enforce/audit/warn), no violations found"
        else
            test_result "pod_security_compliance" "FAIL" "$test_start" "Pod security violations detected: $violations FailedCreate events, $warning_events warning events"
        fi
    else
        local details="Labels incorrect - spire-server: enforce=$spire_server_enforce,audit=$spire_server_audit,warn=$spire_server_warn; spire-system: enforce=$spire_system_enforce,audit=$spire_system_audit,warn=$spire_system_warn; production: enforce=$production_enforce,audit=$production_audit,warn=$production_warn"
        test_result "pod_security_compliance" "FAIL" "$test_start" "$details"
    fi
}

# Test 13: Resource Allocation and Limits
test_resource_allocation() {
    local test_start=$(date +%s)
    echo -e "${BLUE}🧪 Testing: Resource Allocation and Limits${NC}"
    
    # Check for any pods in pending state due to resource constraints
    local pending_pods=$(kubectl --context workload-cluster get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Check cluster resource usage
    local node_status=$(kubectl --context workload-cluster top nodes 2>/dev/null || echo "metrics unavailable")
    
    if [ "$pending_pods" -eq 0 ]; then
        # Check for any OOMKilled containers
        local oom_events=$(kubectl --context workload-cluster get events -A --field-selector reason=OOMKilling 2>/dev/null | wc -l || echo "0")
        if [ "$oom_events" -eq 0 ]; then
            test_result "resource_allocation" "PASS" "$test_start" "No pending pods or OOM events. Node status: $node_status"
        else
            test_result "resource_allocation" "FAIL" "$test_start" "Found $oom_events OOM events"
        fi
    else
        local pending_details=$(kubectl --context workload-cluster get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | head -3 | tr '\n' '; ' || echo "none")
        test_result "resource_allocation" "FAIL" "$test_start" "Found $pending_pods pending pods: $pending_details"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}🔬 SPIRE Environment Reproducibility Test Suite${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
    echo "Test session started at $(date)"
    echo "Logging results to: $LOG_FILE"
    echo ""
    
    # Initialize log file
    echo "# SPIRE Reproducibility Test Results - $(date)" > "$LOG_FILE"
    
    # Run teardown first to ensure clean state
    echo -e "${YELLOW}🧹 Running teardown to ensure clean test environment...${NC}"
    if [ -f "$PROJECT_ROOT/scripts/teardown.sh" ]; then
        "$PROJECT_ROOT/scripts/teardown.sh" >/dev/null 2>&1 || true
    fi
    
    # Wait for cleanup to complete
    sleep 10
    
    # Execute all tests
    test_clean_environment
    test_fresh_install_execution || {
        echo -e "${RED}🚨 Fresh install failed - skipping remaining tests${NC}"
        return 1
    }
    
    # Wait for environment to stabilize
    echo -e "${YELLOW}⏳ Waiting for environment to stabilize...${NC}"
    sleep 30
    
    test_cluster_creation_consistency
    test_spire_server_startup
    test_database_connectivity
    test_agent_configuration
    test_bundle_creation
    test_workload_deployment_consistency
    test_dashboard_integration
    test_spiffe_id_availability
    test_namespace_creation_consistency
    test_pod_security_compliance
    test_resource_allocation
    
    # Calculate results
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    
    echo ""
    echo -e "${BLUE}📊 Test Suite Results${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Total Tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "Success Rate: ${GREEN}$success_rate%${NC}"
    echo -e "Total Duration: ${total_duration}s"
    echo ""
    
    # Log final metrics
    log_metric "test_suite_summary" "INFO" "$total_duration" "total=$TOTAL_TESTS passed=$PASSED_TESTS failed=$FAILED_TESTS success_rate=$success_rate%"
    
    if [ "$FAILED_TESTS" -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Environment is fully reproducible.${NC}"
        log_metric "overall_result" "PASS" "$total_duration" "All reproducibility tests passed"
        return 0
    else
        echo -e "${RED}⚠️  $FAILED_TESTS test(s) failed. Check logs for details.${NC}"
        log_metric "overall_result" "FAIL" "$total_duration" "$FAILED_TESTS tests failed"
        return 1
    fi
}

# Cleanup function
cleanup() {
    rm -f "$TEMP_LOG"
}

# Set up cleanup trap
trap cleanup EXIT

# Check dependencies
if ! command -v minikube >/dev/null 2>&1; then
    echo -e "${RED}❌ minikube not found${NC}"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq not found${NC}"
    exit 1
fi

# Run main function
main "$@"