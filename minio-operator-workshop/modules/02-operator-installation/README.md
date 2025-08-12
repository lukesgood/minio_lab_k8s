# Module 2: MinIO Operator Installation

## 🎯 Learning Objectives

By the end of this module, you will:
- Install MinIO Operator using the official GitHub repository method
- Understand the official installation process and best practices
- Verify operator functionality using official methods
- Use the latest official operator version and configurations

## 📚 Key Concepts

### Official MinIO Operator Repository
The official MinIO Operator is maintained at https://github.com/minio/operator and provides the most up-to-date installation methods and examples.

### Kustomize Installation Method
The official recommended method uses `kubectl kustomize` to install directly from the GitHub repository, ensuring you get the latest stable version.

## 📋 Step-by-Step Instructions

### Step 1: Verify Prerequisites

```bash
# Ensure you completed Module 1
kubectl cluster-info

# Check Kubernetes version (minimum 1.21+)
kubectl version --short --client

# Verify you have cluster-admin permissions
kubectl auth can-i create clusterroles
kubectl auth can-i create customresourcedefinitions
```

### Step 2: Install MinIO Operator

```bash
# Install using the official kustomize method (latest stable)
kubectl kustomize github.com/minio/operator | kubectl apply -f -

# Alternative: Install specific version
kubectl kustomize github.com/minio/operator\?ref=v6.0.4 | kubectl apply -f -
```

**What This Command Does:**
- Downloads the latest operator manifests from the official GitHub repository
- Applies all necessary resources (CRDs, RBAC, Deployment) using kustomize
- Creates the `minio-operator` namespace
- Installs the operator with official configurations

### Step 3: Verify Installation Progress

```bash
# Check that the operator namespace was created
kubectl get namespace minio-operator

# Watch operator pod startup
kubectl get pods -n minio-operator -w
# Press Ctrl+C once pods are Running
```

**Expected Output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
minio-operator-69fd675557-xyz123  1/1     Running   0          30s
minio-operator-69fd675557-abc456  1/1     Running   0          30s
```

### Step 4: Examine Installed Components

```bash
# Check Custom Resource Definitions (official CRDs)
kubectl get crd | grep minio

# Examine the Tenant CRD (most important)
kubectl describe crd tenants.minio.min.io

# Check operator version and image
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Key CRDs Installed:**
- `tenants.minio.min.io` - MinIO instances
- `policysets.minio.min.io` - IAM policies  
- `miniojobs.job.min.io` - Job management

### Step 5: Verify Operator Functionality

```bash
# Check operator logs for official startup messages
kubectl logs -n minio-operator deployment/minio-operator

# Verify operator is watching for Tenant resources
kubectl get tenants --all-namespaces
```

**Expected Log Output:**
```
Starting MinIO Operator
Watching for Tenant resources...
Operator ready
```

### Step 6: Test with Tenant Example

```bash
# Create a test namespace for our tenant
kubectl create namespace tenant-lite

# Download official tenant example
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml

# Examine the official tenant configuration
cat tenant-lite.yaml

# Test tenant resource validation (dry-run)
kubectl apply -f tenant-lite.yaml --dry-run=client
```

**Expected Output:**
```
tenant.minio.min.io/tenant-lite created (dry run)
```

### Step 7: Verify Repository Integration

```bash
# Check operator deployment details
kubectl describe deployment minio-operator -n minio-operator

# Verify official image is being used
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show official MinIO operator image like:
# quay.io/minio/operator:v6.0.4
```

## 🔍 Understanding the Installation

### What Was Installed

1. **Operator Deployment**: The main controller from official repository
2. **Official CRDs**: Latest custom resource definitions
3. **Official RBAC**: Service accounts, roles, and bindings
4. **Webhooks**: Validation and mutation webhooks from official repo

### Official Operator Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   kubectl       │    │   GitHub        │    │   MinIO         │
│   kustomize     │───▶│   minio/operator│───▶│   Operator      │
│                 │    │   repository    │    │   Controller    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
                                               ┌─────────────────┐
                                               │   Creates       │
                                               │   StatefulSet   │
                                               │   Services      │
                                               │   Secrets       │
                                               └─────────────────┘
```

### Official vs Custom Installation

| Aspect | Official Method | Custom Method |
|--------|----------------|---------------|
| **Source** | GitHub minio/operator | Custom YAML files |
| **Updates** | Always latest stable | Manual updates needed |
| **Support** | Official community support | Limited support |
| **Compatibility** | Guaranteed compatibility | May have issues |
| **Security** | Official security patches | Manual security updates |

## ✅ Validation Checklist

Before proceeding to Module 3, ensure:

- [ ] MinIO Operator pods are Running in minio-operator namespace
- [ ] Official CRDs are installed and accessible
- [ ] Operator logs show no errors and official startup messages
- [ ] Official tenant example validates successfully
- [ ] Operator is using official image from quay.io/minio/operator

## 🚨 Common Issues & Solutions

### Issue: Kustomize Command Fails

```bash
# Check kubectl version (needs 1.21+)
kubectl version --short

# Verify internet connectivity to GitHub
curl -I https://github.com/minio/operator

# Try with specific version if latest fails
kubectl kustomize github.com/minio/operator\?ref=v6.0.4 | kubectl apply -f -
```

### Issue: Operator Pods Not Starting

```bash
# Check node resources and taints
kubectl describe nodes

# For single-node clusters, remove control-plane taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# Check operator logs for specific errors
kubectl logs -n minio-operator deployment/minio-operator
```

### Issue: CRDs Not Found

```bash
# Verify CRDs were installed
kubectl get crd | grep minio

# If missing, reinstall operator
kubectl delete namespace minio-operator
kubectl kustomize github.com/minio/operator | kubectl apply -f -
```

## 🔧 Advanced Configuration

### Using Official Helm Charts

```bash
# Add official MinIO Helm repository
helm repo add minio-operator https://operator.min.io

# Install using official Helm chart
helm install minio-operator minio-operator/operator \
  --namespace minio-operator \
  --create-namespace
```

### Official Operator Configuration

```bash
# Download official operator configuration
curl -O https://raw.githubusercontent.com/minio/operator/master/resources/base/operator.yaml

# Customize if needed, then apply
kubectl apply -f operator.yaml
```

## 📖 Official Resources

- [MinIO Operator GitHub](https://github.com/minio/operator)
- [Official Documentation](https://min.io/docs/minio/kubernetes/upstream/)
- [Official Examples](https://github.com/minio/operator/tree/master/examples)
- [Release Notes](https://github.com/minio/operator/releases)

## ➡️ Next Steps

Now that the official operator is installed and ready:

```bash
cd ../03-tenant-deployment
cat README.md
```

---

**🎉 Excellent!** You've successfully installed the MinIO Operator using the official method from the GitHub repository. The operator is now ready to manage MinIO instances (called Tenants) using the latest official configurations and best practices.
