# Dynamic PVC with Automatic Allocation

## 🎯 Overview

Dynamic PVC provisioning allows Kubernetes to automatically create Persistent Volumes (PVs) when Persistent Volume Claims (PVCs) are requested, without requiring manual PV creation. This is essential for scalable MinIO deployments.

## 📚 Key Concepts

### Dynamic Provisioning
- **Automatic PV Creation**: PVs are created automatically when PVCs are requested
- **Storage Classes**: Define how storage should be provisioned
- **Provisioners**: Components that create the actual storage
- **Volume Binding Modes**: Control when PVs are created and bound

### Binding Modes
- **Immediate**: PV created immediately when PVC is created
- **WaitForFirstConsumer**: PV created when a Pod uses the PVC (recommended)

## 🔧 Method 1: Local Path Provisioner (Single Node)

### Step 1: Install Local Path Provisioner

```bash
# Install the local-path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Verify installation
kubectl get pods -n local-path-storage
kubectl get storageclass
```

### Step 2: Configure Dynamic Storage Class

```yaml
# dynamic-local-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dynamic-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
parameters:
  # Optional: specify node path
  nodePath: "/data/dynamic-storage"
```

### Step 3: Configure Provisioner Path

```yaml
# local-path-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/data/dynamic-storage", "/data2/dynamic-storage"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    # Create directory with proper permissions
    mkdir -m 0755 -p "$VOL_DIR"
    # Set ownership for MinIO (user 1000)
    chown 1000:1000 "$VOL_DIR" 2>/dev/null || true
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"
  helperPod.yaml: |-
    apiVersion: v1
    kind: Pod
    metadata:
      name: helper-pod
    spec:
      containers:
      - name: helper-pod
        image: busybox
        imagePullPolicy: IfNotPresent
```

### Step 4: Apply Configuration

```bash
# Apply the storage class
kubectl apply -f dynamic-local-storage.yaml

# Update the provisioner configuration
kubectl apply -f local-path-config.yaml

# Restart provisioner to pick up new config
kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
```

## 🔧 Method 2: NFS Dynamic Provisioner (Multi-Node)

### Step 1: Install NFS Subdir External Provisioner

```bash
# Add Helm repository
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Install NFS provisioner
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.100 \
  --set nfs.path=/data/nfs-storage \
  --set storageClass.defaultClass=true \
  --set storageClass.name=nfs-dynamic
```

### Step 2: Manual NFS Provisioner Setup (Alternative)

```yaml
# nfs-provisioner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
      - name: nfs-client-provisioner
        image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
        volumeMounts:
        - name: nfs-client-root
          mountPath: /persistentvolumes
        env:
        - name: PROVISIONER_NAME
          value: k8s-sigs.io/nfs-subdir-external-provisioner
        - name: NFS_SERVER
          value: 192.168.1.100  # Your NFS server IP
        - name: NFS_PATH
          value: /data/nfs-storage  # NFS export path
      volumes:
      - name: nfs-client-root
        nfs:
          server: 192.168.1.100
          path: /data/nfs-storage
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

## 🔧 Method 3: Cloud Provider Dynamic Provisioning

### AWS EBS Dynamic Provisioning

```yaml
# aws-ebs-dynamic.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-ebs-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
```

### Google Cloud Persistent Disk

```yaml
# gcp-pd-dynamic.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-pd-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: pd.csi.storage.gke.io
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: pd-ssd
  replication-type: regional-pd
```

### Azure Disk Dynamic Provisioning

```yaml
# azure-disk-dynamic.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: disk.csi.azure.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  skuName: Premium_LRS
  kind: Managed
```

## 🔧 Method 4: Advanced Dynamic Provisioning with Node Affinity

### Step 1: Create Node-Specific Storage Classes

```yaml
# node-specific-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd-node-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
parameters:
  nodePath: "/data/ssd-storage"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hdd-node-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
parameters:
  nodePath: "/data/hdd-storage"
```

### Step 2: Configure Multiple Path Provisioner

```yaml
# multi-path-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "ssd-node-1",
          "paths": ["/data/ssd-storage"]
        },
        {
          "node": "ssd-node-2", 
          "paths": ["/data/ssd-storage"]
        },
        {
          "node": "hdd-node-1",
          "paths": ["/data/hdd-storage"]
        },
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/data/dynamic-storage"]
        }
      ]
    }
```

## 🚀 MinIO with Dynamic PVC Allocation

### Step 1: MinIO Tenant with Dynamic Storage

```yaml
# minio-dynamic-pvc.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-dynamic
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  credsSecret:
    name: minio-creds-secret
  pools:
  - servers: 4
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
            storage: 10Gi  # Will be dynamically provisioned
        storageClassName: dynamic-local-storage  # Use dynamic storage class
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
      limits:
        memory: "8Gi"
        cpu: "4000m"
  mountPath: /export
  requestAutoCert: false
```

### Step 2: Automatic Scaling with Dynamic PVCs

```yaml
# minio-auto-scaling.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-auto-scale
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  credsSecret:
    name: minio-creds-secret
  pools:
  - servers: 2  # Start with 2 servers
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
            storage: 20Gi
        storageClassName: dynamic-local-storage
  # Additional pool for scaling
  - servers: 0  # Start with 0, scale up as needed
    name: pool-1
    volumesPerServer: 4
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
        storageClassName: dynamic-local-storage
```

## 📊 Testing Dynamic PVC Allocation

### Step 1: Test Basic Dynamic Provisioning

```bash
# Create test PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-dynamic-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: dynamic-local-storage
EOF

# Check PVC status (should be Pending with WaitForFirstConsumer)
kubectl get pvc test-dynamic-pvc

# Create pod to trigger provisioning
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-dynamic-pod
  namespace: default
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
      claimName: test-dynamic-pvc
EOF

# Watch PVC become Bound and PV get created automatically
kubectl get pvc test-dynamic-pvc -w
kubectl get pv
```

### Step 2: Test Multiple PVC Creation

```bash
# Create multiple PVCs simultaneously
for i in {1..5}; do
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: multi-pvc-${i}
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: dynamic-local-storage
EOF
done

# Create pods to use all PVCs
for i in {1..5}; do
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod-${i}
  namespace: default
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
      claimName: multi-pvc-${i}
EOF
done

# Watch all PVCs get bound
kubectl get pvc | grep multi-pvc
kubectl get pv
```

## 🔧 Advanced Configuration Options

### Step 1: Storage Class with Custom Parameters

```yaml
# advanced-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: advanced-dynamic-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain  # Keep data when PVC is deleted
allowVolumeExpansion: true
parameters:
  # Custom parameters for the provisioner
  nodePath: "/data/advanced-storage"
  # Add custom labels to created PVs
  pvLabels: "tier=premium,backup=enabled"
mountOptions:
  - noatime
  - nodiratime
```

### Step 2: Topology-Aware Provisioning

```yaml
# topology-aware-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topology-aware-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: kubernetes.io/hostname
    values:
    - worker-node-1
    - worker-node-2
  - key: topology.kubernetes.io/zone
    values:
    - zone-a
    - zone-b
```

## 📊 Monitoring Dynamic Provisioning

### Step 1: Create Monitoring Script

```bash
# Create provisioning monitor
cat << 'EOF' > monitor-dynamic-provisioning.sh
#!/bin/bash

echo "Dynamic PVC Provisioning Monitor"
echo "==============================="
echo "Timestamp: $(date)"
echo ""

echo "Storage Classes:"
kubectl get storageclass -o wide

echo ""
echo "PVC Status:"
kubectl get pvc --all-namespaces -o wide

echo ""
echo "PV Status:"
kubectl get pv -o wide

echo ""
echo "Provisioner Status:"
kubectl get pods -n local-path-storage

echo ""
echo "Recent Events:"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -E "(ProvisioningSucceeded|ProvisioningFailed|VolumeBinding)" | tail -10

echo ""
echo "Storage Usage:"
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name
EOF

chmod +x monitor-dynamic-provisioning.sh
```

### Step 2: Automated Monitoring with Alerts

```bash
# Create alerting script
cat << 'EOF' > alert-provisioning-failures.sh
#!/bin/bash

# Check for failed provisioning
failed_pvcs=$(kubectl get pvc --all-namespaces -o json | jq -r '.items[] | select(.status.phase == "Pending") | select(.metadata.creationTimestamp | fromdateiso8601 < (now - 300)) | "\(.metadata.namespace)/\(.metadata.name)"')

if [ -n "$failed_pvcs" ]; then
    echo "ALERT: PVCs stuck in Pending state for more than 5 minutes:"
    echo "$failed_pvcs"
    
    # Send alert (customize for your alerting system)
    # curl -X POST "https://hooks.slack.com/..." -d "{'text':'PVC provisioning failures detected'}"
fi

# Check provisioner health
if ! kubectl get pods -n local-path-storage | grep -q "Running"; then
    echo "ALERT: Local path provisioner not running!"
fi
EOF

chmod +x alert-provisioning-failures.sh

# Add to crontab for regular monitoring
# crontab -e
# */5 * * * * /path/to/alert-provisioning-failures.sh
```

## 🚨 Troubleshooting Dynamic Provisioning

### Common Issues and Solutions

#### Issue: PVCs Stuck in Pending

```bash
# Check storage class exists
kubectl get storageclass

# Check provisioner is running
kubectl get pods -n local-path-storage

# Check provisioner logs
kubectl logs -n local-path-storage deployment/local-path-provisioner

# Check events
kubectl describe pvc <pvc-name>
```

#### Issue: PV Creation Fails

```bash
# Check node storage capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check disk space on nodes
kubectl debug node/<node-name> -it --image=busybox -- df -h

# Check permissions on storage paths
kubectl debug node/<node-name> -it --image=busybox -- ls -la /data/
```

#### Issue: Performance Problems

```bash
# Check I/O performance
kubectl debug node/<node-name> -it --image=busybox -- dd if=/dev/zero of=/data/test bs=1M count=100

# Check for storage class parameters
kubectl describe storageclass <storage-class-name>

# Monitor resource usage
kubectl top nodes
kubectl top pods -n local-path-storage
```

## 🎯 Best Practices

### Storage Class Design
- **Use WaitForFirstConsumer** for better pod placement
- **Set appropriate reclaim policies** (Retain for production data)
- **Enable volume expansion** for future growth
- **Use meaningful names** and labels

### Provisioner Configuration
- **Monitor provisioner health** regularly
- **Set up proper RBAC** permissions
- **Configure resource limits** for provisioner pods
- **Use multiple storage paths** for redundancy

### Capacity Planning
- **Monitor storage usage** trends
- **Set up alerts** for low disk space
- **Plan for growth** with expandable volumes
- **Consider backup strategies** for dynamic volumes

## 💡 Pro Tips

1. **Test provisioning** in development before production
2. **Use labels and annotations** for better organization
3. **Monitor provisioner logs** for early issue detection
4. **Implement backup strategies** for dynamically provisioned volumes
5. **Consider storage tiering** with multiple storage classes

---

**🎉 With dynamic PVC allocation, your MinIO deployments can scale automatically without manual storage management!**
