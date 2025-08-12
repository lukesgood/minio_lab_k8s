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
EOF

# Restart the local-path-provisioner to pick up new config
kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
```

## 🔧 Method 2: Create Custom Storage Class

```bash
# Create storage class for specific node paths
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
parameters:
  nodePath: "/data/minio-storage"
EOF
```

## 🔧 Method 3: Manual PV Creation

```bash
# Create multiple PVs with custom paths for MinIO
for i in {1..4}; do
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-${i}
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
EOF
done
```

## 📊 Verification

```bash
# List all PVs and their paths
kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.hostPath.path,STATUS:.status.phase

# Check actual directories on nodes
ls -la /data/minio-storage/
```

## 🎯 Best Practices

1. **Path Organization**: Use `/data/minio-storage/` for MinIO data
2. **Performance**: Use separate disks for different workloads
3. **Security**: Set proper permissions (755 for directories)
4. **Backup**: Organize paths for easier backup strategies
