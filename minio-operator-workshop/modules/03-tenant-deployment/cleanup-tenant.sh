#!/bin/bash

# MinIO Tenant Cleanup Script
# This script removes the MinIO tenant and all associated resources

set -e

# Configuration
NAMESPACE="minio-workshop"
TENANT_NAME="minio-workshop"

echo "🧹 MinIO Tenant Cleanup Script"
echo "==============================="
echo "This will DELETE the MinIO tenant and ALL DATA!"
echo "Namespace: $NAMESPACE"
echo "Tenant: $TENANT_NAME"
echo ""

# Confirmation
read -p "⚠️  Are you sure you want to delete the tenant and all data? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🗑️  Starting cleanup process..."

# Stop any port forwarding
echo "📋 Step 1: Stopping port forwarding processes..."
pkill -f "kubectl port-forward.*9090" 2>/dev/null || true
pkill -f "kubectl port-forward.*9000" 2>/dev/null || true
echo "✅ Port forwarding stopped"

# Delete tenant
echo "📋 Step 2: Deleting MinIO tenant..."
if kubectl get tenant $TENANT_NAME -n $NAMESPACE &>/dev/null; then
    kubectl delete tenant $TENANT_NAME -n $NAMESPACE
    echo "✅ Tenant deleted"
else
    echo "⚠️  Tenant not found"
fi

# Wait for pods to be deleted
echo "📋 Step 3: Waiting for pods to be deleted..."
kubectl wait --for=delete pod -l v1.min.io/tenant=$TENANT_NAME -n $NAMESPACE --timeout=120s 2>/dev/null || true
echo "✅ Pods deleted"

# Delete PVCs (if they don't auto-delete)
echo "📋 Step 4: Deleting persistent volume claims..."
if kubectl get pvc -n $NAMESPACE &>/dev/null; then
    kubectl delete pvc -n $NAMESPACE --all --timeout=60s
    echo "✅ PVCs deleted"
else
    echo "⚠️  No PVCs found"
fi

# Delete secrets
echo "📋 Step 5: Deleting secrets..."
if kubectl get secret minio-workshop-secret -n $NAMESPACE &>/dev/null; then
    kubectl delete secret minio-workshop-secret -n $NAMESPACE
    echo "✅ Secrets deleted"
else
    echo "⚠️  Secrets not found"
fi

# Delete namespace
echo "📋 Step 6: Deleting namespace..."
if kubectl get namespace $NAMESPACE &>/dev/null; then
    kubectl delete namespace $NAMESPACE --timeout=120s
    echo "✅ Namespace deleted"
else
    echo "⚠️  Namespace not found"
fi

echo ""
echo "🎉 Cleanup completed successfully!"
echo ""
echo "📋 Verification:"
echo "================"

# Verify cleanup
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "⚠️  Namespace still exists (may be terminating)"
    kubectl get namespace $NAMESPACE
else
    echo "✅ Namespace deleted"
fi

if kubectl get tenant $TENANT_NAME -n $NAMESPACE &>/dev/null 2>&1; then
    echo "⚠️  Tenant still exists"
else
    echo "✅ Tenant deleted"
fi

echo ""
echo "You can now re-run the deployment script to create a fresh tenant."
