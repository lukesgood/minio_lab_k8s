# Updated Lab Based on Official MinIO Operator Repository

## 🎯 Overview

This update aligns the workshop with the official MinIO Operator repository at https://github.com/minio/operator, ensuring we use the latest official methods, examples, and best practices.

## 📋 Key Changes from Official Repository

### 1. Installation Method (Updated)

#### Official Method (Current)
```bash
# Use the official kustomize installation
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -

# Or use the latest release
kubectl kustomize github.com/minio/operator | kubectl apply -f -
```

#### Alternative: Using kubectl apply directly
```bash
# Direct installation from GitHub releases
kubectl apply -k github.com/minio/operator/resources
```

### 2. Tenant Creation (Official Examples)

#### Using Official Tenant Examples
```bash
# Clone the official repository for examples
git clone https://github.com/minio/operator.git
cd operator/examples

# Use official tenant examples
kubectl apply -f examples/tenant.yaml
```

#### Official Tenant Configuration
```yaml
# Based on official examples/tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: tenant-lite
  namespace: tenant-lite
spec:
  image: quay.io/minio/minio:RELEASE.2024-10-02T17-50-41Z
  configuration:
    name: tenant-lite-secret
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 4
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
  mountPath: /export
  subPath: /data
  requestAutoCert: false
```

### 3. Official Console Configuration

#### Console Setup (From Official Examples)
```yaml
# Official console configuration
spec:
  console:
    image: quay.io/minio/console:v1.6.0
    replicas: 1
    name: tenant-lite-secret
```

### 4. Security Configuration (Official Best Practices)

#### TLS Configuration
```yaml
# Official TLS setup
spec:
  requestAutoCert: true
  certConfig:
    commonName: "*.tenant-lite.svc.cluster.local"
    organizationName: ["system:nodes"]
    dnsNames:
    - "tenant-lite-console"
    - "tenant-lite-hl"
    - "*.tenant-lite-hl.tenant-lite.svc.cluster.local"
```

## 🔧 Updated Module Structure

### Module 1: Environment Setup (Updated)
```bash
# Check official requirements
kubectl version --client
kubectl cluster-info

# Verify minimum Kubernetes version (1.21+)
KUBE_VERSION=$(kubectl version --short --client | grep "Client Version" | cut -d' ' -f3 | cut -d'v' -f2)
echo "Kubernetes version: $KUBE_VERSION"
```

### Module 2: Operator Installation (Official Method)
```bash
# Step 1: Install using official kustomize method
kubectl kustomize github.com/minio/operator | kubectl apply -f -

# Step 2: Verify installation
kubectl get pods -n minio-operator

# Step 3: Check operator version
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Module 3: Tenant Deployment (Official Examples)
```bash
# Step 1: Create namespace
kubectl create namespace tenant-lite

# Step 2: Create credentials secret (official format)
kubectl create secret generic tenant-lite-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=\"minio\"
export MINIO_ROOT_PASSWORD=\"minio123\"" \
  -n tenant-lite

# Step 3: Apply official tenant configuration
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/examples/tenant.yaml
```

## 📊 Official Repository Structure

### Key Directories from Official Repo
```
minio/operator/
├── cmd/                    # Operator binaries
├── docs/                   # Official documentation
├── examples/               # Official examples
│   ├── tenant.yaml         # Basic tenant example
│   ├── tenant-lite.yaml    # Lightweight tenant
│   └── kustomization/      # Kustomize examples
├── helm/                   # Official Helm charts
├── pkg/                    # Operator packages
└── resources/              # Kubernetes resources
```

### Official Examples to Use
```bash
# Basic tenant
examples/tenant.yaml

# Lightweight tenant
examples/tenant-lite.yaml

# With external storage
examples/tenant-external-storage.yaml

# With KES (encryption)
examples/tenant-kes.yaml
```

## 🚀 Updated Workshop Flow

### Phase 1: Official Installation
```bash
# 1. Install operator using official method
kubectl kustomize github.com/minio/operator | kubectl apply -f -

# 2. Wait for operator readiness
kubectl wait --for=condition=available deployment/minio-operator -n minio-operator --timeout=300s

# 3. Verify CRDs are installed
kubectl get crd tenants.minio.min.io
```

### Phase 2: Official Tenant Deployment
```bash
# 1. Use official tenant example
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml

# 2. Customize for workshop
sed -i 's/tenant-lite/minio-workshop/g' tenant-lite.yaml

# 3. Deploy tenant
kubectl apply -f tenant-lite.yaml
```

### Phase 3: Official Console Access
```bash
# 1. Port forward using official service names
kubectl port-forward svc/tenant-lite-console -n tenant-lite 9090:9090

# 2. Access console
echo "Console: http://localhost:9090"
echo "Username: minio"
echo "Password: minio123"
```

## 🔧 Updated Scripts Based on Official Repo

### Installation Script (Official Method)
```bash
#!/bin/bash
# install-official-operator.sh

echo "Installing MinIO Operator (Official Method)"
echo "=========================================="

# Install using official kustomize
kubectl kustomize github.com/minio/operator | kubectl apply -f -

# Wait for operator
kubectl wait --for=condition=available deployment/minio-operator -n minio-operator --timeout=300s

echo "✅ MinIO Operator installed successfully"
kubectl get pods -n minio-operator
```

### Tenant Creation Script (Official Examples)
```bash
#!/bin/bash
# create-official-tenant.sh

TENANT_NAME=${1:-"workshop-tenant"}
NAMESPACE=${1:-"workshop-tenant"}

echo "Creating MinIO Tenant: $TENANT_NAME"
echo "=================================="

# Create namespace
kubectl create namespace $NAMESPACE

# Create secret (official format)
kubectl create secret generic ${TENANT_NAME}-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=\"admin\"
export MINIO_ROOT_PASSWORD=\"password123\"" \
  -n $NAMESPACE

# Download and customize official tenant example
curl -s https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml | \
sed "s/tenant-lite/$TENANT_NAME/g" | \
sed "s/namespace: tenant-lite/namespace: $NAMESPACE/g" | \
kubectl apply -f -

echo "✅ Tenant $TENANT_NAME created successfully"
```

## 📋 Official Documentation References

### Key Official Resources
- **Main Repository**: https://github.com/minio/operator
- **Official Documentation**: https://min.io/docs/minio/kubernetes/upstream/
- **Examples Directory**: https://github.com/minio/operator/tree/master/examples
- **Helm Charts**: https://github.com/minio/operator/tree/master/helm
- **Release Notes**: https://github.com/minio/operator/releases

### Official Installation Methods
1. **Kustomize** (Recommended): `kubectl kustomize github.com/minio/operator`
2. **Helm**: Using official Helm charts
3. **Direct Apply**: `kubectl apply -k github.com/minio/operator/resources`

## 🎯 Updated Learning Objectives

### Module Updates Based on Official Repo
1. **Use official installation methods** exclusively
2. **Follow official examples** for tenant creation
3. **Implement official security practices**
4. **Use official image repositories** (quay.io/minio/*)
5. **Follow official naming conventions**

### Official Best Practices Integration
- Use official image tags and repositories
- Follow official security configurations
- Implement official monitoring setups
- Use official troubleshooting guides

## 🔄 Migration Guide

### From Current Lab to Official-Based Lab
```bash
# 1. Update installation method
# Old: Custom YAML files
# New: kubectl kustomize github.com/minio/operator

# 2. Update tenant examples
# Old: Custom tenant configurations
# New: Official examples from GitHub

# 3. Update image references
# Old: minio/minio:RELEASE.2025-04-08T15-41-24Z
# New: quay.io/minio/minio:RELEASE.2024-10-02T17-50-41Z

# 4. Update console configuration
# Old: Custom console setup
# New: Official console examples
```

## 💡 Benefits of Official Repository Alignment

### Advantages
- ✅ **Always up-to-date** with latest official practices
- ✅ **Community support** for official methods
- ✅ **Better compatibility** with future releases
- ✅ **Official documentation** alignment
- ✅ **Security best practices** from MinIO team

### Workshop Improvements
- More reliable installation process
- Better long-term maintenance
- Easier troubleshooting with official support
- Access to latest features and fixes

---

**🎯 Next Steps**: Update all workshop modules to use official repository methods, examples, and best practices.
