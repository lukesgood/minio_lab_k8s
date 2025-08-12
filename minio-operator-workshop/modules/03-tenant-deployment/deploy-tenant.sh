#!/bin/bash

# MinIO Tenant Deployment Script
# This script automates the deployment of a MinIO tenant for the workshop

set -e

# Configuration
NAMESPACE="minio-workshop"
TENANT_NAME="minio-workshop"
SECRET_NAME="minio-workshop-secret"
MINIO_USER="admin"
MINIO_PASSWORD="workshop123"

echo "🚀 MinIO Tenant Deployment Script"
echo "=================================="
echo "Namespace: $NAMESPACE"
echo "Tenant: $TENANT_NAME"
echo "Username: $MINIO_USER"
echo "Password: $MINIO_PASSWORD"
echo ""

# Step 1: Check if operator is running
echo "📋 Step 1: Checking MinIO Operator status..."
if ! kubectl get deployment minio-operator -n minio-operator &>/dev/null; then
    echo "❌ MinIO Operator not found. Please run Module 2 first."
    exit 1
fi

if ! kubectl wait --for=condition=available deployment/minio-operator -n minio-operator --timeout=60s &>/dev/null; then
    echo "❌ MinIO Operator is not ready. Please check Module 2."
    exit 1
fi
echo "✅ MinIO Operator is running"

# Step 2: Create namespace
echo "📋 Step 2: Creating namespace..."
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "⚠️  Namespace $NAMESPACE already exists"
else
    kubectl create namespace $NAMESPACE
    echo "✅ Namespace $NAMESPACE created"
fi

# Step 3: Create credentials secret
echo "📋 Step 3: Creating credentials secret..."
if kubectl get secret $SECRET_NAME -n $NAMESPACE &>/dev/null; then
    echo "⚠️  Secret $SECRET_NAME already exists"
    kubectl delete secret $SECRET_NAME -n $NAMESPACE
fi

kubectl create secret generic $SECRET_NAME \
  --from-literal=config.env="export MINIO_ROOT_USER=\"$MINIO_USER\"
export MINIO_ROOT_PASSWORD=\"$MINIO_PASSWORD\"" \
  -n $NAMESPACE

echo "✅ Credentials secret created"

# Step 4: Create tenant configuration
echo "📋 Step 4: Creating tenant configuration..."
cat > /tmp/minio-workshop-tenant.yaml << EOF
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: $TENANT_NAME
  namespace: $NAMESPACE
spec:
  pools:
    - servers: 4
      name: pool-0
      volumesPerServer: 2
      volumeClaimTemplate:
        metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
      containerSecurityContext:
        runAsUser: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault
  configuration:
    name: $SECRET_NAME
  console:
    image: quay.io/minio/console:v1.6.0
    replicas: 1
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
EOF

# Step 5: Deploy tenant
echo "📋 Step 5: Deploying MinIO tenant..."
kubectl apply -f /tmp/minio-workshop-tenant.yaml
echo "✅ Tenant configuration applied"

# Step 6: Wait for tenant to be ready
echo "📋 Step 6: Waiting for tenant to be ready..."
echo "This may take 2-5 minutes..."

# Wait for tenant to exist
kubectl wait --for=condition=Complete --timeout=60s job/minio-workshop-pool-0-0 -n $NAMESPACE 2>/dev/null || true

# Wait for pods to be ready
echo "Waiting for MinIO pods to be ready..."
kubectl wait --for=condition=ready pod -l v1.min.io/tenant=$TENANT_NAME -n $NAMESPACE --timeout=300s

echo "✅ MinIO tenant is ready!"

# Step 7: Display status
echo ""
echo "📊 Deployment Status:"
echo "===================="
kubectl get tenant $TENANT_NAME -n $NAMESPACE
echo ""
kubectl get pods -n $NAMESPACE
echo ""
kubectl get pvc -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE

# Step 8: Setup access
echo ""
echo "🌐 Access Information:"
echo "====================="
echo "To access MinIO Console:"
echo "  kubectl port-forward svc/$TENANT_NAME-console -n $NAMESPACE 9090:9090"
echo "  Then open: http://localhost:9090"
echo ""
echo "To access MinIO API:"
echo "  kubectl port-forward svc/$TENANT_NAME-hl -n $NAMESPACE 9000:9000"
echo "  Then use: http://localhost:9000"
echo ""
echo "Credentials:"
echo "  Username: $MINIO_USER"
echo "  Password: $MINIO_PASSWORD"
echo ""

# Step 9: Offer to start port forwarding
read -p "🚀 Start port forwarding now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting port forwarding..."
    echo "Console will be available at: http://localhost:9090"
    echo "API will be available at: http://localhost:9000"
    echo "Press Ctrl+C to stop port forwarding"
    
    # Start port forwarding in background
    kubectl port-forward svc/$TENANT_NAME-console -n $NAMESPACE 9090:9090 &
    CONSOLE_PID=$!
    
    kubectl port-forward svc/$TENANT_NAME-hl -n $NAMESPACE 9000:9000 &
    API_PID=$!
    
    # Wait for user to stop
    echo "Port forwarding started. Press Enter to stop..."
    read
    
    # Clean up
    kill $CONSOLE_PID $API_PID 2>/dev/null || true
    echo "Port forwarding stopped."
fi

echo ""
echo "🎉 MinIO tenant deployment completed successfully!"
echo "You can now proceed to Module 4: Basic Operations & Client Setup"

# Clean up temp file
rm -f /tmp/minio-workshop-tenant.yaml
