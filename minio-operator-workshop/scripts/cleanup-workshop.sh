#!/bin/bash

# MinIO Operator Workshop - Cleanup Script
# This script provides options to clean up workshop resources

set -e

echo "🧹 MinIO Operator Workshop - Cleanup Options"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo "Select cleanup option:"
    echo "1) Clean up test data only (keep MinIO running)"
    echo "2) Remove MinIO Tenant (keep Operator)"
    echo "3) Complete cleanup (remove everything)"
    echo "4) Reset workshop (clean and prepare for restart)"
    echo "5) Show current resources"
    echo "6) Exit"
    echo ""
}

cleanup_test_data() {
    echo -e "${YELLOW}Cleaning up test data...${NC}"
    
    # Remove test buckets and data
    mc rm --recursive --force local/test-bucket/ 2>/dev/null || true
    mc rm --recursive --force local/advanced-features/ 2>/dev/null || true
    mc rm --recursive --force local/perf-test/ 2>/dev/null || true
    mc rm --recursive --force local/public-data/ 2>/dev/null || true
    mc rm --recursive --force local/private-data/ 2>/dev/null || true
    mc rm --recursive --force local/shared-data/ 2>/dev/null || true
    mc rm --recursive --force local/readonly-data/ 2>/dev/null || true
    
    # Remove buckets
    mc rb local/test-bucket/ 2>/dev/null || true
    mc rb local/advanced-features/ 2>/dev/null || true
    mc rb local/perf-test/ 2>/dev/null || true
    mc rb local/public-data/ 2>/dev/null || true
    mc rb local/private-data/ 2>/dev/null || true
    mc rb local/shared-data/ 2>/dev/null || true
    mc rb local/readonly-data/ 2>/dev/null || true
    
    # Remove test users
    mc admin user remove local readonly-user 2>/dev/null || true
    mc admin user remove local readwrite-user 2>/dev/null || true
    mc admin user remove local public-user 2>/dev/null || true
    mc admin user remove local conditional-user 2>/dev/null || true
    
    # Remove test policies
    mc admin policy remove local readonly-policy 2>/dev/null || true
    mc admin policy remove local readwrite-policy 2>/dev/null || true
    mc admin policy remove local public-read-policy 2>/dev/null || true
    mc admin policy remove local conditional-policy 2>/dev/null || true
    
    # Remove local test files
    rm -f *.txt *.dat *.json 2>/dev/null || true
    rm -rf batch-test batch-download local-data local-docs 2>/dev/null || true
    
    echo -e "${GREEN}✅ Test data cleanup completed${NC}"
}

remove_tenant() {
    echo -e "${YELLOW}Removing MinIO Tenant...${NC}"
    
    # First cleanup test data
    cleanup_test_data
    
    # Kill port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Remove mc aliases
    mc alias remove local 2>/dev/null || true
    mc alias remove readonly 2>/dev/null || true
    mc alias remove readwrite 2>/dev/null || true
    mc alias remove publicread 2>/dev/null || true
    mc alias remove conditional 2>/dev/null || true
    
    # Delete tenant
    kubectl delete tenant minio -n minio-tenant 2>/dev/null || true
    
    # Wait for tenant deletion
    echo "Waiting for tenant deletion..."
    kubectl wait --for=delete tenant/minio -n minio-tenant --timeout=300s 2>/dev/null || true
    
    # Delete namespace (this will clean up all remaining resources)
    kubectl delete namespace minio-tenant 2>/dev/null || true
    
    # Clean up PVs if they have Retain policy
    echo "Checking for retained PVs..."
    retained_pvs=$(kubectl get pv -o jsonpath='{.items[?(@.spec.persistentVolumeReclaimPolicy=="Retain")].metadata.name}' 2>/dev/null || true)
    if [ -n "$retained_pvs" ]; then
        echo "Found retained PVs: $retained_pvs"
        read -p "Delete retained PVs? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pv in $retained_pvs; do
                kubectl delete pv $pv 2>/dev/null || true
            done
        fi
    fi
    
    echo -e "${GREEN}✅ MinIO Tenant removal completed${NC}"
}

complete_cleanup() {
    echo -e "${RED}Performing complete cleanup...${NC}"
    
    # Remove tenant first
    remove_tenant
    
    # Remove operator
    kubectl delete namespace minio-operator 2>/dev/null || true
    
    # Remove CRDs (optional - be careful in shared clusters)
    read -p "Remove MinIO CRDs? This affects the entire cluster (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete crd tenants.minio.min.io 2>/dev/null || true
        kubectl delete crd policysets.minio.min.io 2>/dev/null || true
        kubectl delete crd miniojobs.job.min.io 2>/dev/null || true
    fi
    
    # Clean up any remaining resources
    kubectl delete clusterrole minio-operator-role 2>/dev/null || true
    kubectl delete clusterrolebinding minio-operator-binding 2>/dev/null || true
    
    echo -e "${GREEN}✅ Complete cleanup finished${NC}"
}

reset_workshop() {
    echo -e "${BLUE}Resetting workshop environment...${NC}"
    
    # Complete cleanup first
    complete_cleanup
    
    # Wait a moment for cleanup to complete
    sleep 5
    
    # Reinstall operator
    echo "Reinstalling MinIO Operator..."
    kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
    
    # Wait for operator to be ready
    echo "Waiting for operator to be ready..."
    kubectl wait --for=condition=available deployment/minio-operator -n minio-operator --timeout=300s
    
    # Create tenant namespace
    kubectl create namespace minio-tenant
    
    echo -e "${GREEN}✅ Workshop environment reset completed${NC}"
    echo "You can now start the workshop from Module 3 (Tenant Deployment)"
}

show_resources() {
    echo -e "${BLUE}Current Workshop Resources:${NC}"
    echo ""
    
    echo "Namespaces:"
    kubectl get namespace | grep -E "(minio-operator|minio-tenant)" || echo "  No MinIO namespaces found"
    
    echo ""
    echo "MinIO Operator:"
    kubectl get pods -n minio-operator 2>/dev/null || echo "  No operator pods found"
    
    echo ""
    echo "MinIO Tenant:"
    kubectl get tenant -n minio-tenant 2>/dev/null || echo "  No tenants found"
    kubectl get pods -n minio-tenant 2>/dev/null || echo "  No tenant pods found"
    
    echo ""
    echo "Persistent Volumes:"
    kubectl get pv | grep -E "(minio|local-path)" || echo "  No MinIO-related PVs found"
    
    echo ""
    echo "MinIO Client Aliases:"
    mc alias list 2>/dev/null | grep -E "(local|readonly|readwrite)" || echo "  No MinIO aliases configured"
    
    echo ""
    echo "Test Files:"
    ls -la *.txt *.dat *.json 2>/dev/null || echo "  No test files found"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            cleanup_test_data
            ;;
        2)
            echo -e "${YELLOW}This will remove the MinIO Tenant but keep the Operator.${NC}"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                remove_tenant
            fi
            ;;
        3)
            echo -e "${RED}This will remove ALL workshop resources including the Operator.${NC}"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                complete_cleanup
            fi
            ;;
        4)
            echo -e "${BLUE}This will clean everything and reinstall the Operator.${NC}"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                reset_workshop
            fi
            ;;
        5)
            show_resources
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1-6.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
