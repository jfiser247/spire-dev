#!/bin/bash

# SPIRE Environment Teardown Script
# Completely cleans up the local SPIRE development environment
# Use this when you're done testing for the day or need a clean slate

set -e

echo "🧹 SPIRE Environment Teardown"
echo "=============================="
echo ""
echo "This will completely remove:"
echo "  🗑️  All Minikube clusters (workload-cluster)"
echo "  🗑️  All running servers (dashboard, docs)"
echo "  🗑️  All container images and volumes"
echo "  🗑️  All temporary files and caches"
echo ""

# Confirmation prompt
read -p "⚠️  Are you sure you want to tear down the entire environment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Teardown cancelled"
    exit 0
fi

echo ""
echo "🚀 Starting complete environment teardown..."
echo ""

# Step 1: Stop all running servers
echo "📊 Stopping running servers..."
echo "================================"

# Stop MkDocs server
if pgrep -f "mkdocs serve" >/dev/null 2>&1; then
    echo "🛑 Stopping MkDocs documentation server..."
    pkill -f "mkdocs serve" 2>/dev/null || true
    echo "✅ MkDocs server stopped"
else
    echo "ℹ️  No MkDocs server running"
fi

# Stop dashboard server
if pgrep -f "node.*server.js" >/dev/null 2>&1; then
    echo "🛑 Stopping dashboard server..."
    pkill -f "node.*server.js" 2>/dev/null || true
    echo "✅ Dashboard server stopped"
else
    echo "ℹ️  No dashboard server running"
fi

# Stop any other Node.js processes related to the project
if pgrep -f "node.*3000" >/dev/null 2>&1; then
    echo "🛑 Stopping other Node.js processes on port 3000..."
    pkill -f "node.*3000" 2>/dev/null || true
    echo "✅ Port 3000 processes stopped"
fi

# Check and free ports
echo ""
echo "🔍 Checking and freeing ports..."
if lsof -i :3000 >/dev/null 2>&1; then
    echo "⚠️  Port 3000 still in use, attempting to free..."
    lsof -ti :3000 | xargs kill -9 2>/dev/null || true
fi

if lsof -i :8000 >/dev/null 2>&1; then
    echo "⚠️  Port 8000 still in use, attempting to free..."
    lsof -ti :8000 | xargs kill -9 2>/dev/null || true
fi

echo "✅ Server cleanup completed"
echo ""

# Step 2: Delete Minikube clusters
echo "🏗️  Removing Minikube clusters..."
echo "=================================="

# Get list of all minikube profiles
PROFILES=$(minikube profile list -o json 2>/dev/null | jq -r '.valid[].Name' 2>/dev/null || echo "")

if [ -n "$PROFILES" ]; then
    for profile in $PROFILES; do
        echo "🗑️  Deleting Minikube profile: $profile"
        minikube delete --profile="$profile" 2>/dev/null || {
            echo "⚠️  Warning: Could not delete profile $profile"
        }
    done
    echo "✅ All Minikube clusters removed"
else
    echo "ℹ️  No Minikube profiles found"
fi

echo ""

# Step 3: Clean Docker resources
echo "🐳 Cleaning Docker resources..."
echo "==============================="

# Stop all containers
if docker ps -q | wc -l | grep -v "^0$" >/dev/null; then
    echo "🛑 Stopping all running containers..."
    docker stop $(docker ps -q) 2>/dev/null || true
fi

# Remove SPIRE-related containers
echo "🗑️  Removing SPIRE-related containers..."
docker ps -a --filter "name=spire" --format "table {{.Names}}" | tail -n +2 | xargs -r docker rm -f 2>/dev/null || true
docker ps -a --filter "name=k8s_spire" --format "table {{.Names}}" | tail -n +2 | xargs -r docker rm -f 2>/dev/null || true

# Remove SPIRE-related images
echo "🗑️  Removing SPIRE-related images..."
docker images --filter "reference=*spire*" --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | xargs -r docker rmi -f 2>/dev/null || true
docker images --filter "reference=spiffe/*" --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | xargs -r docker rmi -f 2>/dev/null || true

# Remove dangling images and volumes
echo "🗑️  Removing dangling Docker resources..."
docker image prune -f >/dev/null 2>&1 || true
docker volume prune -f >/dev/null 2>&1 || true
docker network prune -f >/dev/null 2>&1 || true

# Optional: Full Docker system prune (commented out by default)
# Uncomment the next line for aggressive cleanup (removes ALL unused Docker resources)
# docker system prune -a -f --volumes >/dev/null 2>&1 || true

echo "✅ Docker cleanup completed"
echo ""

# Step 4: Clean local files and caches
echo "📁 Cleaning local files and caches..."
echo "======================================"

# Remove temporary files
if [ -d "/tmp" ]; then
    echo "🗑️  Removing temporary SPIRE files..."
    find /tmp -name "*spire*" -type f -mtime +0 -delete 2>/dev/null || true
    find /tmp -name "*spiffe*" -type f -mtime +0 -delete 2>/dev/null || true
fi

# Clean kubectl cache
if [ -d "$HOME/.kube/cache" ]; then
    echo "🗑️  Cleaning kubectl cache..."
    rm -rf "$HOME/.kube/cache" 2>/dev/null || true
fi

# Clean minikube cache (optional - keeps downloaded images for faster next startup)
# Uncomment if you want to completely clean minikube cache
# if [ -d "$HOME/.minikube" ]; then
#     echo "🗑️  Cleaning minikube cache..."
#     rm -rf "$HOME/.minikube" 2>/dev/null || true
# fi

# Remove any leftover socket files
echo "🗑️  Removing leftover socket files..."
find /tmp -name "*.sock" -path "*spire*" -delete 2>/dev/null || true

# Clean npm/node modules cache if present in project
if [ -d "node_modules" ]; then
    echo "🗑️  Removing node_modules..."
    rm -rf node_modules 2>/dev/null || true
fi

if [ -f "package-lock.json" ]; then
    echo "🗑️  Removing package-lock.json..."
    rm -f package-lock.json 2>/dev/null || true
fi

echo "✅ File cleanup completed"
echo ""

# Step 5: Reset kubectl context
echo "⚙️  Resetting kubectl context..."
echo "================================="

# Remove SPIRE-related contexts
kubectl config get-contexts -o name 2>/dev/null | grep -E "(spire|workload)" | xargs -r kubectl config delete-context 2>/dev/null || true

# Reset to default context if available
if kubectl config get-contexts -o name 2>/dev/null | grep -q "docker-desktop"; then
    kubectl config use-context docker-desktop >/dev/null 2>&1 || true
    echo "✅ Reset to docker-desktop context"
elif kubectl config get-contexts -o name 2>/dev/null | grep -q "minikube"; then
    kubectl config use-context minikube >/dev/null 2>&1 || true
    echo "✅ Reset to minikube context"
else
    echo "ℹ️  No default context to reset to"
fi

echo ""

# Step 6: Verification
echo "🔍 Verifying cleanup..."
echo "======================="

# Check for running processes
SPIRE_PROCESSES=$(ps aux | grep -E "(spire|mkdocs|node.*server)" | grep -v grep | wc -l)
if [ "$SPIRE_PROCESSES" -gt 0 ]; then
    echo "⚠️  Warning: Some SPIRE-related processes may still be running"
    ps aux | grep -E "(spire|mkdocs|node.*server)" | grep -v grep
else
    echo "✅ No SPIRE-related processes running"
fi

# Check for open ports
if lsof -i :3000 >/dev/null 2>&1; then
    echo "⚠️  Warning: Port 3000 still in use"
else
    echo "✅ Port 3000 is free"
fi

if lsof -i :8000 >/dev/null 2>&1; then
    echo "⚠️  Warning: Port 8000 still in use"
else
    echo "✅ Port 8000 is free"
fi

# Check minikube status
MINIKUBE_STATUS=$(minikube profile list -o json 2>/dev/null | jq -r '.valid | length' 2>/dev/null || echo "0")
if [ "$MINIKUBE_STATUS" -eq 0 ]; then
    echo "✅ No Minikube clusters running"
else
    echo "⚠️  Warning: $MINIKUBE_STATUS Minikube cluster(s) still exist"
fi

echo ""

# Step 7: Summary and next steps
echo "🎉 Teardown Summary"
echo "=================="
echo "✅ All servers stopped (dashboard, docs)"
echo "✅ Minikube clusters removed"
echo "✅ Docker resources cleaned"
echo "✅ Temporary files removed"
echo "✅ kubectl contexts reset"
echo ""
echo "💾 What was preserved:"
echo "   📁 Project source code"
echo "   📁 Documentation files"
echo "   📁 Configuration files"
echo "   🐳 Base Docker images (for faster next startup)"
echo ""
echo "🚀 To restart your environment:"
echo "   ./scripts/fresh-install.sh"
echo ""
echo "🔧 To start individual components:"
echo "   ./scripts/start-docs-server.sh    # Documentation only"
echo "   node web/server.js                # Dashboard only"
echo ""
echo "🎯 Environment completely cleaned!"
echo "Ready for your next SPIRE adventure! 🚀"