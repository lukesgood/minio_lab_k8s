# Module 1: Environment Setup & Validation

## 🎯 Learning Objectives

By the end of this module, you will:
- Understand Kubernetes storage concepts (PV, PVC, StorageClass)
- Validate your cluster is ready for MinIO deployment
- Configure dynamic storage provisioning
- Understand the WaitForFirstConsumer binding mode

## 📚 Key Concepts

### Dynamic Storage Provisioning
Dynamic provisioning automatically creates Persistent Volumes (PVs) when a Persistent Volume Claim (PVC) is created. This eliminates the need to pre-provision storage.

### WaitForFirstConsumer
This binding mode delays PV creation until a Pod actually uses the PVC. This ensures the PV is created in the same zone as the Pod.

## 🔧 Prerequisites Validation

First, let's validate your environment:

```bash
# Run the prerequisites check
../../scripts/check-prerequisites.sh
```

## 📋 Step-by-Step Instructions

### Step 1: Examine Current Storage Configuration

```bash
# Check existing storage classes
kubectl get storageclass

# Look for default storage class (should have "default" annotation)
kubectl get storageclass -o wide
```

**Expected Output:**
```
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  1d
```

### Step 2: Understand Storage Class Configuration

```bash
# Examine the default storage class in detail
kubectl describe storageclass local-path
```

**Key Points to Note:**
- `VolumeBindingMode: WaitForFirstConsumer` - PV creation is delayed
- `Provisioner` - The component that creates PVs
- `ReclaimPolicy` - What happens to PV when PVC is deleted

### Step 3: Test Dynamic Provisioning

Let's create a test PVC to understand the provisioning process:

```bash
# Create a test namespace
kubectl create namespace storage-test

# Create a test PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

### Step 4: Observe PVC Behavior

```bash
# Check PVC status - should be Pending
kubectl get pvc -n storage-test

# Describe the PVC to understand why it's pending
kubectl describe pvc test-pvc -n storage-test
```

**Expected Behavior:**
- PVC status: `Pending`
- Reason: `WaitForFirstConsumer`
- This is NORMAL behavior!

### Step 5: Create a Pod to Trigger Provisioning

```bash
# Create a pod that uses the PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: storage-test
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
EOF
```

### Step 6: Watch Dynamic Provisioning in Action

```bash
# Watch PVC status change from Pending to Bound
kubectl get pvc -n storage-test -w
# Press Ctrl+C after you see it become Bound

# Check that a PV was automatically created
kubectl get pv

# Examine the created PV
kubectl describe pv $(kubectl get pv -o jsonpath='{.items[0].metadata.name}')
```

### Step 7: Verify Storage Location

```bash
# Find where the data is actually stored
kubectl get pv -o jsonpath='{.items[0].spec.local.path}'

# If using local-path provisioner, check the node
kubectl describe pod test-pod -n storage-test | grep Node:
```

### Step 8: Test Data Persistence

```bash
# Write data to the mounted volume
kubectl exec -n storage-test test-pod -- sh -c "echo 'Hello MinIO Workshop' > /data/test.txt"

# Verify the data was written
kubectl exec -n storage-test test-pod -- cat /data/test.txt

# Check the actual file on the node (if accessible)
# Note: This step depends on your cluster setup
```

### Step 9: Clean Up Test Resources

```bash
# Delete test resources
kubectl delete pod test-pod -n storage-test
kubectl delete pvc test-pvc -n storage-test
kubectl delete namespace storage-test

# Verify PV is cleaned up (due to Delete reclaim policy)
kubectl get pv
```

## 🔍 Understanding the Results

### What We Learned

1. **PVC Pending State**: When using `WaitForFirstConsumer`, PVCs remain pending until a Pod uses them
2. **Automatic PV Creation**: The provisioner automatically creates PVs when needed
3. **Storage Location**: Data is stored in actual directories on cluster nodes
4. **Cleanup Behavior**: PVs are automatically deleted when PVCs are removed (Delete policy)

### Why This Matters for MinIO

MinIO uses StatefulSets, which create PVCs automatically. Understanding this process helps you:
- Troubleshoot storage issues
- Monitor provisioning progress
- Understand data persistence
- Plan storage capacity

## ✅ Validation Checklist

Before proceeding to Module 2, ensure:

- [ ] Default storage class is configured
- [ ] Dynamic provisioning works correctly
- [ ] PVC goes from Pending → Bound when Pod is created
- [ ] PV is automatically created and cleaned up
- [ ] You understand WaitForFirstConsumer behavior

## 🚨 Common Issues & Solutions

### Issue: No Default Storage Class
```bash
# Install local-path provisioner (for single-node clusters)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Set as default
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Issue: PVC Stuck in Pending
- Check if default storage class exists
- Verify provisioner is running
- Check node resources and taints

### Issue: Pod Cannot Schedule
```bash
# Remove control-plane taint (single-node clusters)
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## 📖 Additional Reading

- [Kubernetes Storage Concepts](https://kubernetes.io/docs/concepts/storage/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## ➡️ Next Steps

Once you've completed this module and validated your environment:

```bash
cd ../02-operator-installation
cat README.md
```

---

**🎉 Congratulations!** You now understand Kubernetes storage fundamentals and have a working dynamic provisioning setup. This foundation is crucial for the MinIO deployment in the next module.
