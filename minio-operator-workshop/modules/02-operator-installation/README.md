# Module 2: MinIO Operator Installation

## 🎯 Learning Objectives

By the end of this module, you will:
- Understand the Kubernetes Operator pattern
- Install MinIO Operator using the official method
- Verify operator functionality and readiness
- Understand Custom Resource Definitions (CRDs)

## 📚 Key Concepts

### Kubernetes Operator Pattern
An Operator is a method of packaging, deploying, and managing a Kubernetes application. It extends Kubernetes with custom resources and controllers that understand how to manage complex applications.

### MinIO Operator Benefits
- **Automated Management**: Handles deployment, scaling, and updates
- **Kubernetes Native**: Uses CRDs and standard Kubernetes APIs
- **Production Ready**: Includes monitoring, security, and operational features

## 🔧 Installation Methods

We'll use the official GitHub-based installation method, which is the recommended approach.

## 📋 Step-by-Step Instructions

### Step 1: Verify Prerequisites

```bash
# Ensure you completed Module 1
kubectl get storageclass

# Check cluster connectivity
kubectl cluster-info
```

### Step 2: Install MinIO Operator

```bash
# Install using the official kustomize method
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
```

**What This Command Does:**
- Downloads the latest stable operator manifests from GitHub
- Applies all necessary resources (CRDs, RBAC, Deployment)
- Creates the `minio-operator` namespace

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
# Check Custom Resource Definitions
kubectl get crd | grep minio

# Examine the Tenant CRD (most important)
kubectl describe crd tenants.minio.min.io
```

**Key CRDs Installed:**
- `tenants.minio.min.io` - MinIO instances
- `policysets.minio.min.io` - IAM policies
- `miniojobs.job.min.io` - Job management

### Step 5: Verify Operator Functionality

```bash
# Check operator logs
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

### Step 6: Examine Operator Configuration

```bash
# Check operator deployment details
kubectl describe deployment minio-operator -n minio-operator

# Check operator service account and RBAC
kubectl describe serviceaccount minio-operator -n minio-operator
kubectl describe clusterrole minio-operator-role
```

### Step 7: Test Operator Readiness

```bash
# Create a test namespace for our tenant
kubectl create namespace minio-tenant

# Verify we can create tenant resources (dry-run)
cat << EOF | kubectl apply --dry-run=client -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: test-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 1
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
  requestAutoCert: false
EOF
```

**Expected Output:**
```
tenant.minio.min.io/test-tenant created (dry run)
```

## 🔍 Understanding the Installation

### What Was Installed

1. **Operator Deployment**: The main controller that manages MinIO instances
2. **CRDs**: Custom resource definitions for MinIO-specific resources
3. **RBAC**: Service accounts, roles, and bindings for proper permissions
4. **Webhooks**: Validation and mutation webhooks for resource management

### Operator Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   kubectl       │    │   API Server    │    │   MinIO         │
│   apply tenant  │───▶│   validates     │───▶│   Operator      │
│                 │    │   via webhook   │    │   Controller    │
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

## ✅ Validation Checklist

Before proceeding to Module 3, ensure:

- [ ] MinIO Operator pods are Running
- [ ] CRDs are installed and accessible
- [ ] Operator logs show no errors
- [ ] Test tenant resource validates successfully
- [ ] `minio-tenant` namespace is created

## 🚨 Common Issues & Solutions

### Issue: Operator Pods Pending
```bash
# Check node resources and taints
kubectl describe nodes

# For single-node clusters, remove control-plane taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

### Issue: CRDs Not Found
```bash
# Reinstall operator
kubectl delete namespace minio-operator
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
```

### Issue: Permission Errors
```bash
# Check if you have cluster-admin permissions
kubectl auth can-i create clusterroles
kubectl auth can-i create customresourcedefinitions
```

### Issue: Network Policies Blocking Installation
```bash
# Check for network policies that might block operator communication
kubectl get networkpolicies --all-namespaces
```

## 🔧 Advanced Configuration (Optional)

### Custom Operator Configuration

If you need to customize the operator (not required for this workshop):

```bash
# Download and customize the manifests
curl -O https://raw.githubusercontent.com/minio/operator/v7.1.1/resources/base/operator.yaml

# Edit the file as needed, then apply
kubectl apply -f operator.yaml
```

### Operator Resource Limits

```bash
# Check current resource usage
kubectl top pods -n minio-operator

# View resource requests/limits
kubectl describe deployment minio-operator -n minio-operator | grep -A 10 "Limits\|Requests"
```

## 📖 Additional Reading

- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [MinIO Operator Documentation](https://github.com/minio/operator)
- [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## ➡️ Next Steps

Now that the operator is installed and ready:

```bash
cd ../03-tenant-deployment
cat README.md
```

---

**🎉 Excellent!** You've successfully installed the MinIO Operator. The operator is now ready to manage MinIO instances (called Tenants) in your cluster. In the next module, we'll deploy our first MinIO Tenant and watch the operator create all the necessary resources automatically.
