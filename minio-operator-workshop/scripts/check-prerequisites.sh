#!/bin/bash

# MinIO Operator Workshop - Prerequisites Check Script
# This script validates that your environment is ready for the workshop

set -e

echo "🔍 MinIO Operator Workshop - Prerequisites Check"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "✅ $1 is installed"
        return 0
    else
        echo -e "❌ $1 is not installed"
        return 1
    fi
}

check_kubectl_connection() {
    if kubectl cluster-info &> /dev/null; then
        echo -e "✅ kubectl can connect to cluster"
        kubectl get nodes --no-headers | wc -l | xargs echo "   Nodes available:"
        return 0
    else
        echo -e "❌ kubectl cannot connect to cluster"
        return 1
    fi
}

check_storage_class() {
    if kubectl get storageclass &> /dev/null; then
        local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
        if [ -n "$default_sc" ]; then
            echo -e "✅ Default storage class found: $default_sc"
            return 0
        else
            echo -e "⚠️  No default storage class found"
            echo "   Available storage classes:"
            kubectl get storageclass --no-headers | awk '{print "   - " $1}'
            return 1
        fi
    else
        echo -e "❌ Cannot access storage classes"
        return 1
    fi
}

check_resources() {
    local nodes=$(kubectl get nodes --no-headers | wc -l)
    echo "📊 Resource Check:"
    echo "   Nodes: $nodes"
    
    # Check if we can create a test pod
    if kubectl auth can-i create pods &> /dev/null; then
        echo -e "✅ Can create pods"
    else
        echo -e "❌ Cannot create pods - check RBAC permissions"
        return 1
    fi
    
    return 0
}

# Main checks
echo ""
echo "1. Checking required commands..."
COMMANDS_OK=true
check_command "kubectl" || COMMANDS_OK=false
check_command "curl" || COMMANDS_OK=false

echo ""
echo "2. Checking Kubernetes connectivity..."
KUBECTL_OK=true
check_kubectl_connection || KUBECTL_OK=false

echo ""
echo "3. Checking storage configuration..."
STORAGE_OK=true
check_storage_class || STORAGE_OK=false

echo ""
echo "4. Checking permissions and resources..."
RESOURCES_OK=true
check_resources || RESOURCES_OK=false

# Summary
echo ""
echo "📋 Prerequisites Summary:"
echo "========================"

if [ "$COMMANDS_OK" = true ] && [ "$KUBECTL_OK" = true ] && [ "$STORAGE_OK" = true ] && [ "$RESOURCES_OK" = true ]; then
    echo -e "${GREEN}✅ All prerequisites met! You're ready to start the workshop.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. cd modules/01-environment-setup"
    echo "2. Follow the README.md instructions"
    exit 0
else
    echo -e "${RED}❌ Some prerequisites are not met.${NC}"
    echo ""
    echo "Issues to resolve:"
    [ "$COMMANDS_OK" = false ] && echo "- Install missing commands (kubectl, curl)"
    [ "$KUBECTL_OK" = false ] && echo "- Configure kubectl to connect to your cluster"
    [ "$STORAGE_OK" = false ] && echo "- Set up a default storage class"
    [ "$RESOURCES_OK" = false ] && echo "- Check RBAC permissions"
    echo ""
    echo "Refer to the setup guides in docs/ for help."
    exit 1
fi
