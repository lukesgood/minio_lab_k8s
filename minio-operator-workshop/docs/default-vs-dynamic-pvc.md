# Default vs Dynamic PVC Behavior

## 🤔 Your Question: "Is it default behavior?"

**Short Answer**: Dynamic PVC provisioning is **NOT default behavior** in most Kubernetes clusters. It requires specific setup and configuration.

## 📋 What's Default vs What Requires Setup

### ❌ NOT Default (Requires Setup)

#### Dynamic PVC Provisioning
```bash
# These require manual installation:
- Local Path Provisioner
- NFS Dynamic Provisioner  
- Cloud Provider CSI Drivers (in some cases)
- Custom Storage Classes
```

#### Default Storage Classes
```bash
# Most clusters don't have a default storage class
kubectl get storageclass
# Often shows: No resources found

# You need to create and set one as default
```

### ✅ Default Behavior (Built-in)

#### Static PVC Binding
```bash
# This works by default if PVs exist:
1. Create PV manually
2. Create PVC 
3. Kubernetes binds them automatically
```

#### Cloud Provider Defaults
```bash
# Some managed clusters have defaults:
- EKS: May have EBS CSI driver pre-installed
- GKE: Has GCE Persistent Disk by default
- AKS: Has Azure Disk CSI driver
```

## 🔍 Let's Check Your Current Setup

### Step 1: Check Default Storage Class

```bash
# Check if you have a default storage class
kubectl get storageclass

# Look for "(default)" annotation
kubectl get storageclass -o wide

# Check which one is marked as default
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

**Expected Results:**

#### If You See This (Common):
```bash
No resources found in default namespace.
# OR
NAME         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path   rancher.io/local-path   Delete          WaitForFirstConsumer
# (no "default" annotation)
```
**Meaning**: No dynamic provisioning by default ❌

#### If You See This (Configured):
```bash
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```
**Meaning**: Dynamic provisioning is configured ✅

### Step 2: Check Provisioner Status

```bash
# Check if local-path provisioner is installed
kubectl get pods -n local-path-storage

# Check if NFS provisioner is running
kubectl get pods | grep nfs

# Check for cloud provider CSI drivers
kubectl get pods -n kube-system | grep -E "(ebs|gce|azure)"
```

## 📊 Default Behavior by Environment

### Bare Metal Kubernetes
```bash
Default Storage: ❌ None
Dynamic Provisioning: ❌ Not configured
Manual Setup Required: ✅ Yes

# You need to install:
- Storage provisioner (local-path, NFS, etc.)
- Storage classes
- Set default storage class
```

### Minikube
```bash
Default Storage: ✅ hostpath (basic)
Dynamic Provisioning: ⚠️ Limited (hostpath only)
Production Ready: ❌ No

# Default storage class:
NAME                 PROVISIONER                RECLAIMPOLICY
standard (default)   k8s.io/minikube-hostpath   Delete
```

### Kind (Kubernetes in Docker)
```bash
Default Storage: ❌ None by default
Dynamic Provisioning: ❌ Not configured
Manual Setup Required: ✅ Yes

# Need to install local-path provisioner manually
```

### K3s
```bash
Default Storage: ✅ local-path (pre-installed)
Dynamic Provisioning: ✅ Works out of box
Production Ready: ⚠️ Single node only

# Comes with local-path provisioner pre-installed
```

### Cloud Managed Clusters

#### EKS (Amazon)
```bash
Default Storage: ⚠️ Depends on version
Dynamic Provisioning: ✅ EBS CSI driver available
Setup Required: ⚠️ May need CSI driver installation

# Check if EBS CSI driver is installed:
kubectl get pods -n kube-system | grep ebs-csi
```

#### GKE (Google)
```bash
Default Storage: ✅ GCE Persistent Disk
Dynamic Provisioning: ✅ Works by default
Setup Required: ❌ No

# Default storage class:
NAME                 PROVISIONER             
standard (default)   pd.csi.storage.gke.io
```

#### AKS (Azure)
```bash
Default Storage: ✅ Azure Disk
Dynamic Provisioning: ✅ Works by default  
Setup Required: ❌ No

# Default storage classes:
NAME                PROVISIONER
default (default)   disk.csi.azure.com
managed-premium     disk.csi.azure.com
```

## 🔧 What MinIO Operator Expects

### MinIO Operator Behavior
```yaml
# When you create a MinIO Tenant:
apiVersion: minio.min.io/v2
kind: Tenant
spec:
  pools:
  - volumeClaimTemplate:
      spec:
        storageClassName: ""  # Uses default storage class
        # OR
        storageClassName: "specific-class"  # Uses specific class
```

**What Happens:**
1. **If default storage class exists**: PVCs get provisioned automatically ✅
2. **If no default storage class**: PVCs stay in "Pending" state ❌
3. **If specified class doesn't exist**: PVCs fail ❌

## 🚨 Common Scenarios

### Scenario 1: Fresh Kubernetes Cluster
```bash
# What you'll see:
kubectl get storageclass
# No resources found

# MinIO Tenant deployment:
kubectl get pvc -n minio-tenant
# NAME     STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
# data-0   Pending   
# data-1   Pending
# data-2   Pending
# data-3   Pending

# Solution: Install a provisioner and set default storage class
```

### Scenario 2: Minikube (Has Default)
```bash
# What you'll see:
kubectl get storageclass
# NAME                 PROVISIONER                RECLAIMPOLICY
# standard (default)   k8s.io/minikube-hostpath   Delete

# MinIO Tenant deployment:
kubectl get pvc -n minio-tenant
# NAME     STATUS   VOLUME                     CAPACITY   STORAGECLASS
# data-0   Bound    pvc-abc123                 1Gi        standard
# data-1   Bound    pvc-def456                 1Gi        standard

# Works automatically! ✅
```

### Scenario 3: Cloud Provider (GKE)
```bash
# What you'll see:
kubectl get storageclass
# NAME                 PROVISIONER             RECLAIMPOLICY
# standard (default)   pd.csi.storage.gke.io   Delete
# premium              pd.csi.storage.gke.io   Delete

# MinIO works automatically with cloud storage ✅
```

## 🎯 Quick Check: Is Dynamic PVC Your Default?

Run this simple test:

```bash
# Test script to check dynamic PVC behavior
cat << 'EOF' > test-dynamic-default.sh
#!/bin/bash

echo "🔍 Testing Default Dynamic PVC Behavior"
echo "======================================="

# Check for default storage class
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

if [ -n "$DEFAULT_SC" ]; then
    echo "✅ Default storage class found: $DEFAULT_SC"
    
    # Test dynamic provisioning
    echo "Testing dynamic provisioning..."
    
    cat << TESTEOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-default-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
TESTEOF
    
    # Create pod to trigger provisioning
    cat << TESTEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-default-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '60']
    volumeMounts:
    - name: test-vol
      mountPath: /data
  volumes:
  - name: test-vol
    persistentVolumeClaim:
      claimName: test-default-pvc
TESTEOF
    
    echo "Waiting 30 seconds for provisioning..."
    sleep 30
    
    PVC_STATUS=$(kubectl get pvc test-default-pvc -o jsonpath='{.status.phase}')
    if [ "$PVC_STATUS" = "Bound" ]; then
        echo "✅ Dynamic PVC provisioning works by default!"
        echo "Your cluster supports automatic MinIO storage provisioning"
    else
        echo "❌ Dynamic PVC provisioning failed"
        echo "PVC Status: $PVC_STATUS"
        kubectl describe pvc test-default-pvc
    fi
    
    # Cleanup
    kubectl delete pod test-default-pod --ignore-not-found=true
    kubectl delete pvc test-default-pvc --ignore-not-found=true
    
else
    echo "❌ No default storage class found"
    echo "Dynamic PVC provisioning is NOT available by default"
    echo ""
    echo "Available storage classes:"
    kubectl get storageclass
    echo ""
    echo "You need to:"
    echo "1. Install a storage provisioner (local-path, NFS, etc.)"
    echo "2. Create a storage class"
    echo "3. Set it as default"
fi
EOF

chmod +x test-dynamic-default.sh
./test-dynamic-default.sh
```

## 💡 Summary

### Default Behavior Answer:
- **Most clusters**: Dynamic PVC is **NOT default** ❌
- **Some managed clouds**: May have it by default ✅
- **K3s**: Has local-path by default ✅
- **Minikube**: Has basic hostpath by default ✅

### For MinIO Production:
```bash
# You typically need to set up:
1. Install storage provisioner
2. Create appropriate storage class  
3. Set as default (optional)
4. Configure for MinIO requirements

# Use our setup script:
./scripts/setup-dynamic-pvc.sh
```

### Quick Answer for Your Environment:
```bash
# Run this to check your current setup:
kubectl get storageclass
kubectl get pvc -n minio-tenant 2>/dev/null || echo "No MinIO tenant deployed yet"

# If you see "No resources found" for storage classes,
# then dynamic PVC is NOT default behavior in your cluster
```

**🎯 Bottom Line**: Dynamic PVC provisioning usually requires setup, but once configured, it becomes the automatic behavior for new PVCs!
