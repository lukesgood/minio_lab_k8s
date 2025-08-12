# How to Change Persistent Volume (PV) Path from Default Settings

## 🎯 Overview

By default, many storage provisioners use predefined paths for storing data. This guide shows you how to customize these paths for better organization, performance, or compliance requirements.

## 📋 Common Default Paths by Provisioner

### Local Path Provisioner (Default)
- **Default Path**: `/opt/local-path-provisioner/`
- **Structure**: `/opt/local-path-provisioner/pvc-<uuid>_<namespace>_<pvc-name>`

### HostPath (Manual PVs)
- **Default Path**: Usually `/tmp` or `/var/lib/kubernetes`
- **Structure**: User-defined

### NFS
- **Default Path**: NFS server's exported directory
- **Structure**: Depends on NFS server configuration

## 🔧 Method 1: Change Local Path Provisioner Configuration

### Step 1: Check Current Configuration

```bash
# Check current local-path-provisioner configuration
kubectl get configmap local-path-config -n local-path-storage -o yaml

# Check current storage class
kubectl describe storageclass local-path
```

### Step 2: Create Custom Local Path Configuration

```bash
# Create custom configuration with new path
cat << EOF | kubectl apply -f -
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
          "paths": ["/data/local-path-provisioner", "/data2/local-path-provisioner"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "$VOL_DIR"
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
EOF

# Restart the local-path-provisioner to pick up new config
kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
```

### Step 3: Verify New Configuration

```bash
# Check if provisioner restarted successfully
kubectl get pods -n local-path-storage

# Test with a new PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-custom-path-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF

# Create a pod to trigger provisioning
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-custom-path-pod
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
      claimName: test-custom-path-pvc
EOF

# Check where the PV was created
kubectl get pv
kubectl describe pv $(kubectl get pv -o jsonpath='{.items[0].metadata.name}')

# Verify the actual path on the node
ls -la /data/local-path-provisioner/
```

## 🔧 Method 2: Create Custom Storage Class with Specific Paths

### Step 1: Create Node-Specific Storage Class

```bash
# Create storage class for specific node paths
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: false
parameters:
  nodePath: "/data/minio-storage"
EOF
```

### Step 2: Create Custom ConfigMap for New Storage Class

```bash
# Create specific configmap for MinIO storage
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: minio-local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/data/minio-storage"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    # Create directory with proper permissions for MinIO
    mkdir -m 0755 -p "$VOL_DIR"
    # Set ownership if needed (uncomment if running as non-root)
    # chown 1000:1000 "$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"
EOF
```

### Step 3: Deploy Custom Local Path Provisioner (Optional)

```bash
# Create a separate provisioner for MinIO with custom config
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio-local-path-provisioner
  namespace: local-path-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio-local-path-provisioner
  template:
    metadata:
      labels:
        app: minio-local-path-provisioner
    spec:
      serviceAccountName: local-path-provisioner-service-account
      containers:
      - name: local-path-provisioner
        image: rancher/local-path-provisioner:v0.0.24
        imagePullPolicy: IfNotPresent
        command:
        - local-path-provisioner
        - --debug
        - start
        - --config
        - /etc/config/config.json
        - --provisioner-name
        - rancher.io/minio-local-path
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config/
          readOnly: true
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
      volumes:
      - name: config-volume
        configMap:
          name: minio-local-path-config
EOF

# Update storage class to use new provisioner
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
provisioner: rancher.io/minio-local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF
```

## 🔧 Method 3: Manual PV Creation with Custom Paths

### Step 1: Create Manual PVs with Specific Paths

```bash
# Create multiple PVs with custom paths for MinIO
for i in {1..4}; do
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-${i}
  labels:
    type: local
    app: minio
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-manual-storage
  hostPath:
    path: /data/minio/drive-${i}
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
EOF
done
```

### Step 2: Create Storage Class for Manual PVs

```bash
# Create storage class that doesn't provision automatically
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-manual-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: false
EOF
```

## 🔧 Method 4: MinIO Tenant with Custom Storage Paths

### Step 1: Create MinIO Tenant with Custom Storage Class

```bash
# Create MinIO tenant using custom storage class
cat << EOF | kubectl apply -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-custom-storage
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  configuration:
    name: minio-creds-secret
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
            storage: 5Gi
        storageClassName: minio-local-storage  # Use custom storage class
  mountPath: /export
  requestAutoCert: false
  features:
    bucketDNS: false
    domains: {}
  users:
  - name: storage-user
EOF
```

## 📊 Verification and Monitoring

### Check PV Locations

```bash
# List all PVs and their paths
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,PATH:.spec.hostPath.path,STATUS:.status.phase

# Check actual directories on nodes
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | xargs -I {} sh -c 'echo "Node: {}"; kubectl debug node/{} -it --image=busybox -- ls -la /data/'

# For local access (if you have node access)
ls -la /data/minio-storage/
ls -la /data/local-path-provisioner/
```

### Monitor Storage Usage

```bash
# Check storage usage on custom paths
df -h /data/minio-storage/
df -h /data/local-path-provisioner/

# Check PVC usage
kubectl get pvc -A
kubectl describe pvc -n minio-tenant
```

## 🚨 Common Issues and Solutions

### Issue: Permission Denied

```bash
# Fix permissions on custom storage paths
sudo mkdir -p /data/minio-storage
sudo chmod 755 /data/minio-storage
sudo chown 1000:1000 /data/minio-storage  # MinIO user
```

### Issue: Path Not Found

```bash
# Ensure paths exist on all nodes
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | xargs -I {} kubectl debug node/{} -it --image=busybox -- mkdir -p /data/minio-storage
```

### Issue: Provisioner Not Using New Config

```bash
# Restart provisioner to pick up new configuration
kubectl rollout restart deployment/local-path-provisioner -n local-path-storage

# Check provisioner logs
kubectl logs -n local-path-storage deployment/local-path-provisioner
```

## 🎯 Best Practices

### 1. Path Organization
```bash
# Recommended directory structure
/data/
├── minio-storage/           # MinIO data
├── postgres-storage/        # Database data
├── redis-storage/          # Cache data
└── backup-storage/         # Backup data
```

### 2. Performance Considerations
- Use separate disks for different workloads
- Consider SSD for high-performance workloads
- Use local storage for better performance
- Avoid network storage for latency-sensitive applications

### 3. Security
```bash
# Set proper permissions
sudo mkdir -p /data/minio-storage
sudo chmod 750 /data/minio-storage
sudo chown 1000:1000 /data/minio-storage

# Use SELinux labels if applicable
sudo semanage fcontext -a -t container_file_t "/data/minio-storage(/.*)?"
sudo restorecon -R /data/minio-storage
```

### 4. Backup Considerations
```bash
# Create backup-friendly structure
/data/
├── minio-storage/
│   ├── pool-0/
│   └── backup/
└── snapshots/
```

## 📖 Additional Resources

- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [MinIO Storage Requirements](https://docs.min.io/minio/baremetal/installation/deploy-minio-single-node-single-drive.html)

---

**💡 Pro Tip**: Always test custom storage configurations in a development environment before applying to production. Monitor disk usage and performance after changing paths to ensure optimal operation.
