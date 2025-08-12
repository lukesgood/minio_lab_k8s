# Disk Failure Recovery in Multi-Node MinIO with Direct PVs

## 🚨 Scenario: Disk Failure and Replacement

When a physical disk fails in a multi-node MinIO deployment using direct PVs (Persistent Volumes), the system administrator needs to follow a specific recovery procedure to restore the cluster to full health.

## 🎯 Overview

MinIO uses **Erasure Coding** for data protection, which means it can tolerate a certain number of disk failures without data loss. However, when a disk is replaced, MinIO needs to rebuild the data on the new disk.

### Erasure Coding Tolerance
- **EC:4 (8 drives)**: Can tolerate up to 4 drive failures
- **EC:6 (12 drives)**: Can tolerate up to 6 drive failures  
- **EC:8 (16 drives)**: Can tolerate up to 8 drive failures

## 📋 Step-by-Step Recovery Process

### Phase 1: Assess the Situation

#### Step 1: Identify the Failed Disk

```bash
# Check MinIO cluster health
mc admin info minio-cluster

# Check for offline drives
mc admin heal minio-cluster --dry-run

# Check Kubernetes PV status
kubectl get pv | grep -E "(Failed|Pending)"

# Check pod status
kubectl get pods -n minio-tenant -o wide

# Check events for disk-related issues
kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | grep -i "mount\|volume\|disk"
```

#### Step 2: Verify Data Integrity

```bash
# Check if cluster is still operational
mc admin info minio-cluster

# Verify read/write operations still work
echo "test-$(date)" > test-file.txt
mc cp test-file.txt minio-cluster/test-bucket/
mc cat minio-cluster/test-bucket/test-file.txt
rm test-file.txt
```

### Phase 2: Physical Disk Replacement

#### Step 3: Replace the Physical Disk

**⚠️ Important**: Ensure the replacement disk has the same or larger capacity.

```bash
# 1. Identify the failed node and disk path
kubectl describe pv <failed-pv-name>

# 2. On the affected node, identify the mount point
lsblk
df -h

# 3. Safely unmount the failed disk (if still mounted)
sudo umount /data/minio/drive-X

# 4. Replace the physical disk (hardware operation)
# - Power down the node if necessary
# - Replace the failed disk with a new one
# - Power up the node

# 5. Format and mount the new disk
sudo mkfs.ext4 /dev/sdX  # Replace X with actual device
sudo mount /dev/sdX /data/minio/drive-X

# 6. Set proper ownership and permissions
sudo chown -R 1000:1000 /data/minio/drive-X
sudo chmod 755 /data/minio/drive-X
```

### Phase 3: Kubernetes Recovery

#### Step 4: Handle the Failed PV

```bash
# Check the status of the failed PV
kubectl describe pv <failed-pv-name>

# If PV is in Failed state, delete it
kubectl delete pv <failed-pv-name>

# The PVC will remain in Pending state, waiting for a new PV
kubectl get pvc -n minio-tenant
```

#### Step 5: Create New PV for Replacement Disk

```bash
# Create a new PV pointing to the replacement disk
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-replacement-$(date +%s)
  labels:
    type: local
    app: minio
spec:
  capacity:
    storage: 100Gi  # Match original capacity or larger
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-local-storage
  hostPath:
    path: /data/minio/drive-X  # Path to replacement disk
    type: Directory
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <node-name>  # Name of the node with replacement disk
EOF
```

#### Step 6: Restart the Affected Pod

```bash
# Delete the pod to force recreation with new PV
kubectl delete pod <minio-pod-name> -n minio-tenant

# Wait for pod to restart and bind to new PV
kubectl wait --for=condition=ready pod -l v1.min.io/tenant=minio -n minio-tenant --timeout=300s

# Verify all PVCs are bound
kubectl get pvc -n minio-tenant
```

### Phase 4: MinIO Data Recovery

#### Step 7: Initiate MinIO Healing Process

```bash
# Start the healing process to rebuild data on the new disk
mc admin heal minio-cluster --recursive

# Monitor healing progress
mc admin heal minio-cluster --recursive --dry-run

# Check healing status
mc admin heal minio-cluster --recursive --verbose
```

#### Step 8: Monitor Recovery Progress

```bash
# Create a monitoring script for healing progress
cat << 'EOF' > monitor-healing.sh
#!/bin/bash
echo "MinIO Healing Progress Monitor"
echo "============================="

while true; do
    echo "$(date): Checking healing status..."
    
    # Get healing summary
    heal_output=$(mc admin heal minio-cluster --dry-run 2>/dev/null)
    
    if echo "$heal_output" | grep -q "No healing required"; then
        echo "✅ Healing completed successfully!"
        break
    else
        echo "🔄 Healing in progress..."
        echo "$heal_output" | grep -E "(Healing|Objects|Drives)"
    fi
    
    sleep 30
done
EOF

chmod +x monitor-healing.sh
./monitor-healing.sh
```

### Phase 5: Verification and Testing

#### Step 9: Comprehensive Health Check

```bash
# Verify cluster health
mc admin info minio-cluster

# Check all drives are online
mc admin heal minio-cluster --dry-run | grep -E "(online|offline)"

# Verify data integrity with test operations
echo "integrity-test-$(date)" > integrity-test.txt
mc cp integrity-test.txt minio-cluster/test-bucket/
mc cat minio-cluster/test-bucket/integrity-test.txt
mc rm minio-cluster/test-bucket/integrity-test.txt
rm integrity-test.txt

# Run performance test to ensure no degradation
mc admin speedtest minio-cluster --duration=60s
```

#### Step 10: Update Monitoring and Documentation

```bash
# Update monitoring dashboards
# Document the incident and recovery process
# Update disaster recovery procedures if needed

# Create incident report
cat << EOF > disk-failure-incident-$(date +%Y%m%d).md
# Disk Failure Incident Report

**Date**: $(date)
**Failed Disk**: /data/minio/drive-X on node-Y
**Downtime**: None (cluster remained operational)
**Recovery Time**: X hours
**Data Loss**: None

## Actions Taken:
1. Identified failed disk
2. Replaced physical hardware
3. Created new PV
4. Initiated healing process
5. Verified full recovery

## Lessons Learned:
- Erasure coding protected against data loss
- Recovery process completed successfully
- Consider implementing automated disk monitoring

## Recommendations:
- Monitor disk health proactively
- Maintain spare disks for quick replacement
- Test recovery procedures regularly
EOF
```

## 🔧 Automation Script for Disk Recovery

```bash
# Create automated recovery script
cat << 'EOF' > disk-recovery-automation.sh
#!/bin/bash

# MinIO Disk Recovery Automation Script
# Usage: ./disk-recovery-automation.sh <node-name> <disk-path> <pv-name>

NODE_NAME=$1
DISK_PATH=$2
FAILED_PV_NAME=$3

if [ $# -ne 3 ]; then
    echo "Usage: $0 <node-name> <disk-path> <pv-name>"
    echo "Example: $0 worker-1 /data/minio/drive-1 minio-pv-1"
    exit 1
fi

echo "🔧 Starting automated disk recovery process..."
echo "Node: $NODE_NAME"
echo "Disk Path: $DISK_PATH"
echo "Failed PV: $FAILED_PV_NAME"

# Step 1: Delete failed PV
echo "Step 1: Removing failed PV..."
kubectl delete pv $FAILED_PV_NAME --ignore-not-found=true

# Step 2: Create replacement PV
echo "Step 2: Creating replacement PV..."
cat << PVEOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${FAILED_PV_NAME}-replacement-$(date +%s)
  labels:
    type: local
    app: minio
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-local-storage
  hostPath:
    path: $DISK_PATH
    type: Directory
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
PVEOF

# Step 3: Restart affected pods
echo "Step 3: Restarting MinIO pods..."
kubectl delete pods -l v1.min.io/tenant=minio -n minio-tenant --field-selector spec.nodeName=$NODE_NAME

# Step 4: Wait for pods to be ready
echo "Step 4: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l v1.min.io/tenant=minio -n minio-tenant --timeout=300s

# Step 5: Initiate healing
echo "Step 5: Starting MinIO healing process..."
mc admin heal minio-cluster --recursive

echo "✅ Automated recovery process completed!"
echo "Monitor healing progress with: mc admin heal minio-cluster --dry-run"
EOF

chmod +x disk-recovery-automation.sh
```

## 🚨 Emergency Procedures

### If Multiple Disks Fail Simultaneously

```bash
# Check if cluster can tolerate the failures
# For EC:4, maximum 4 drives can fail
# If more than tolerance level fails, immediate action required

# 1. Stop all write operations
# 2. Replace disks one by one
# 3. Do not restart all pods simultaneously
# 4. Replace and recover one disk at a time
```

### If Healing Fails

```bash
# Check MinIO logs for errors
kubectl logs -n minio-tenant <minio-pod-name>

# Verify disk permissions and ownership
kubectl exec -n minio-tenant <minio-pod-name> -- ls -la /export/

# Check disk space and health
kubectl exec -n minio-tenant <minio-pod-name> -- df -h /export/

# If healing continues to fail, consider:
# 1. Checking disk health with smartctl
# 2. Verifying network connectivity between nodes
# 3. Checking for filesystem corruption
```

## 📊 Best Practices for Disk Management

### 1. Proactive Monitoring

```bash
# Monitor disk health
smartctl -a /dev/sdX

# Monitor disk usage
df -h /data/minio/

# Monitor MinIO metrics
mc admin prometheus metrics minio-cluster
```

### 2. Regular Health Checks

```bash
# Weekly healing dry-run
mc admin heal minio-cluster --dry-run

# Monthly full healing
mc admin heal minio-cluster --recursive
```

### 3. Disaster Recovery Preparation

- Maintain spare disks of the same size
- Document all disk serial numbers and locations
- Test recovery procedures regularly
- Maintain current backups
- Monitor erasure coding health

## 🎯 Key Takeaways

1. **MinIO's erasure coding provides protection** against disk failures
2. **The cluster remains operational** during single disk failures
3. **Healing process automatically rebuilds** data on replacement disks
4. **Proper PV management** is crucial for Kubernetes integration
5. **Monitoring and automation** reduce recovery time and human error

---

**💡 Pro Tip**: Always test your disk recovery procedures in a development environment before a real failure occurs. This ensures your team is prepared and the process is well-documented.
