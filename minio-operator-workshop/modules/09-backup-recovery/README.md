# Module 9: Backup & Disaster Recovery

## 🎯 Learning Objectives

By the end of this module, you will:
- Implement comprehensive backup strategies for MinIO
- Configure object versioning and lifecycle policies
- Set up automated backup systems
- Practice disaster recovery scenarios
- Understand data protection best practices

## 📚 Key Concepts

### Backup Strategies
- **Full Backup**: Complete copy of all data
- **Incremental Backup**: Only changed data since last backup
- **Differential Backup**: Changed data since last full backup
- **Continuous Replication**: Real-time data synchronization

### Recovery Objectives
- **RTO (Recovery Time Objective)**: Maximum acceptable downtime
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss

## 📋 Step-by-Step Instructions

### Step 1: Set Up Backup Infrastructure

```bash
# Create backup namespace and storage
kubectl create namespace backup-system

# Create backup bucket on our MinIO instance
mc mb local/backup-primary

# Create a second MinIO instance for backup destination (simulating remote site)
cat << EOF | kubectl apply -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: backup-minio
  namespace: backup-system
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  configuration:
    name: backup-minio-creds
  pools:
  - servers: 1
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
            storage: 5Gi
        storageClassName: local-path
  mountPath: /export
  requestAutoCert: false
  features:
    bucketDNS: false
    domains: {}
  users:
  - name: backup-user
EOF

# Create credentials for backup MinIO
kubectl create secret generic backup-minio-creds \
  --from-literal=config.env="export MINIO_ROOT_USER=backup-admin
export MINIO_ROOT_PASSWORD=backup123456" \
  -n backup-system

# Wait for backup MinIO to be ready
kubectl wait --for=condition=ready pod -l v1.min.io/tenant=backup-minio -n backup-system --timeout=300s
```

### Step 2: Configure Backup MinIO Client

```bash
# Set up port forwarding for backup MinIO
kubectl port-forward svc/backup-minio -n backup-system 9001:80 &

# Configure mc alias for backup MinIO
mc alias set backup http://localhost:9001 backup-admin backup123456

# Verify backup MinIO is accessible
mc admin info backup

# Create backup buckets
mc mb backup/production-backup
mc mb backup/archive-backup
mc mb backup/disaster-recovery
```

### Step 3: Enable Object Versioning

```bash
# Enable versioning on critical buckets
mc version enable local/test-bucket
mc version enable local/documents
mc version enable local/shared-data

# Verify versioning is enabled
mc version info local/test-bucket

# Test versioning with multiple file versions
echo "Version 1 content" > version-test.txt
mc cp version-test.txt local/test-bucket/

echo "Version 2 content - updated" > version-test.txt
mc cp version-test.txt local/test-bucket/

echo "Version 3 content - final" > version-test.txt
mc cp version-test.txt local/test-bucket/

# List object versions (if supported by MinIO version)
mc ls --versions local/test-bucket/version-test.txt 2>/dev/null || echo "Version listing not available in this MinIO version"
```

### Step 4: Implement Basic Backup Strategies

```bash
# Create test data for backup scenarios
echo "Creating test data for backup scenarios..."

# Create various types of test data
mkdir -p backup-test-data/{documents,images,databases,logs}

# Documents
for i in {1..10}; do
  echo "Document $i content - $(date)" > backup-test-data/documents/doc-${i}.txt
done

# Images (simulated)
for i in {1..5}; do
  dd if=/dev/zero of=backup-test-data/images/image-${i}.jpg bs=1M count=2
done

# Database dumps (simulated)
for i in {1..3}; do
  echo "Database dump $i - $(date)" > backup-test-data/databases/db-dump-${i}.sql
done

# Log files
for i in {1..20}; do
  echo "$(date): Log entry $i" >> backup-test-data/logs/application.log
done

# Upload test data to MinIO
mc mirror backup-test-data/ local/production-data/

echo "Test data created and uploaded"
```

### Step 5: Full Backup Implementation

```bash
# Create full backup script
cat << 'EOF' > full-backup.sh
#!/bin/bash

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
SOURCE_ALIAS="local"
BACKUP_ALIAS="backup"
BACKUP_BUCKET="production-backup"

echo "Starting full backup at $(date)"
echo "Backup ID: $BACKUP_DATE"

# Create backup directory
mc mb ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE} 2>/dev/null || true

# Perform full backup using mirror
echo "Backing up production-data..."
mc mirror ${SOURCE_ALIAS}/production-data ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}/production-data

echo "Backing up test-bucket..."
mc mirror ${SOURCE_ALIAS}/test-bucket ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}/test-bucket

echo "Backing up documents..."
mc mirror ${SOURCE_ALIAS}/documents ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}/documents

# Create backup manifest
cat << MANIFEST > backup-manifest-${BACKUP_DATE}.txt
Backup Type: Full
Backup Date: $(date)
Backup ID: ${BACKUP_DATE}
Source: ${SOURCE_ALIAS}
Destination: ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}
Buckets Backed Up:
- production-data
- test-bucket
- documents
MANIFEST

# Upload manifest
mc cp backup-manifest-${BACKUP_DATE}.txt ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}/

echo "Full backup completed at $(date)"
echo "Backup location: ${BACKUP_ALIAS}/${BACKUP_BUCKET}/full-${BACKUP_DATE}"

# Cleanup local manifest
rm backup-manifest-${BACKUP_DATE}.txt
EOF

chmod +x full-backup.sh

# Run full backup
./full-backup.sh
```

### Step 6: Incremental Backup Implementation

```bash
# Create incremental backup script
cat << 'EOF' > incremental-backup.sh
#!/bin/bash

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
SOURCE_ALIAS="local"
BACKUP_ALIAS="backup"
BACKUP_BUCKET="production-backup"
LAST_BACKUP_FILE="/tmp/last-backup-timestamp"

echo "Starting incremental backup at $(date)"
echo "Backup ID: $BACKUP_DATE"

# Get last backup timestamp
if [ -f "$LAST_BACKUP_FILE" ]; then
    LAST_BACKUP=$(cat $LAST_BACKUP_FILE)
    echo "Last backup: $LAST_BACKUP"
else
    LAST_BACKUP="1970-01-01T00:00:00Z"
    echo "No previous backup found, treating as full backup"
fi

# Create backup directory
mc mb ${BACKUP_ALIAS}/${BACKUP_BUCKET}/incremental-${BACKUP_DATE} 2>/dev/null || true

# Function to backup changed files
backup_bucket_incremental() {
    local bucket=$1
    echo "Checking $bucket for changes since $LAST_BACKUP..."
    
    # Use mc find to get files modified after last backup
    # Note: This is a simplified approach - production systems might use more sophisticated change detection
    mc mirror ${SOURCE_ALIAS}/${bucket} ${BACKUP_ALIAS}/${BACKUP_BUCKET}/incremental-${BACKUP_DATE}/${bucket} --overwrite
}

# Backup each bucket incrementally
backup_bucket_incremental "production-data"
backup_bucket_incremental "test-bucket"
backup_bucket_incremental "documents"

# Update last backup timestamp
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > $LAST_BACKUP_FILE

# Create backup manifest
cat << MANIFEST > backup-manifest-incremental-${BACKUP_DATE}.txt
Backup Type: Incremental
Backup Date: $(date)
Backup ID: ${BACKUP_DATE}
Source: ${SOURCE_ALIAS}
Destination: ${BACKUP_ALIAS}/${BACKUP_BUCKET}/incremental-${BACKUP_DATE}
Last Backup: ${LAST_BACKUP}
Buckets Backed Up:
- production-data
- test-bucket
- documents
MANIFEST

# Upload manifest
mc cp backup-manifest-incremental-${BACKUP_DATE}.txt ${BACKUP_ALIAS}/${BACKUP_BUCKET}/incremental-${BACKUP_DATE}/

echo "Incremental backup completed at $(date)"

# Cleanup local manifest
rm backup-manifest-incremental-${BACKUP_DATE}.txt
EOF

chmod +x incremental-backup.sh

# Modify some data to test incremental backup
echo "Modified content - $(date)" > backup-test-data/documents/doc-1.txt
echo "New document - $(date)" > backup-test-data/documents/doc-new.txt
mc mirror backup-test-data/ local/production-data/

# Run incremental backup
./incremental-backup.sh
```

### Step 7: Automated Backup with CronJob

```bash
# Create ConfigMap with backup scripts
kubectl create configmap backup-scripts \
  --from-file=full-backup.sh \
  --from-file=incremental-backup.sh \
  -n backup-system

# Create backup CronJob
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: minio-backup
  namespace: backup-system
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: minio/mc:latest
            command:
            - /bin/sh
            - -c
            - |
              # Configure mc aliases
              mc alias set local http://minio.minio-tenant.svc.cluster.local admin password123
              mc alias set backup http://backup-minio.backup-system.svc.cluster.local backup-admin backup123456
              
              # Run backup script
              chmod +x /scripts/incremental-backup.sh
              /scripts/incremental-backup.sh
            volumeMounts:
            - name: backup-scripts
              mountPath: /scripts
            - name: backup-state
              mountPath: /tmp
          volumes:
          - name: backup-scripts
            configMap:
              name: backup-scripts
          - name: backup-state
            emptyDir: {}
          restartPolicy: OnFailure
EOF

# Verify CronJob is created
kubectl get cronjob -n backup-system
```

### Step 8: Disaster Recovery Testing

```bash
echo "=== Disaster Recovery Simulation ==="

# Simulate disaster by deleting some data
echo "Simulating data loss..."
mc rm local/production-data/documents/doc-1.txt
mc rm local/production-data/documents/doc-2.txt
mc rm --recursive --force local/test-bucket/version-test.txt

# Verify data is gone
echo "Verifying data loss..."
mc ls local/production-data/documents/ | grep -E "(doc-1|doc-2)" || echo "✅ Data confirmed lost"
mc ls local/test-bucket/ | grep version-test || echo "✅ Version test file confirmed lost"

# List available backups
echo "Available backups:"
mc ls backup/production-backup/

# Restore from latest full backup
LATEST_BACKUP=$(mc ls backup/production-backup/ | grep full- | tail -1 | awk '{print $5}')
echo "Restoring from backup: $LATEST_BACKUP"

# Restore lost data
echo "Restoring production-data/documents..."
mc mirror backup/production-backup/${LATEST_BACKUP}/production-data/documents/ local/production-data/documents/

echo "Restoring test-bucket..."
mc mirror backup/production-backup/${LATEST_BACKUP}/test-bucket/ local/test-bucket/

# Verify restoration
echo "Verifying restoration..."
mc ls local/production-data/documents/ | grep -E "(doc-1|doc-2)" && echo "✅ Documents restored successfully"
mc ls local/test-bucket/ | grep version-test && echo "✅ Version test file restored successfully"
```

### Step 9: Point-in-Time Recovery

```bash
echo "=== Point-in-Time Recovery Testing ==="

# Create a specific point in time
RECOVERY_POINT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Recovery point: $RECOVERY_POINT"

# Add more data after the recovery point
echo "Adding data after recovery point..."
echo "Data after recovery point - $(date)" > backup-test-data/documents/after-recovery.txt
mc cp backup-test-data/documents/after-recovery.txt local/production-data/documents/

# Create another backup to simulate having backups before and after the recovery point
./incremental-backup.sh

# Simulate need to recover to the specific point in time
echo "Simulating need for point-in-time recovery..."
mc rm local/production-data/documents/after-recovery.txt

# For demonstration, we'll restore from the backup closest to our recovery point
# In production, you'd have more sophisticated point-in-time recovery mechanisms
echo "Performing point-in-time recovery simulation..."
echo "In production, this would involve:"
echo "1. Identifying the backup closest to recovery point: $RECOVERY_POINT"
echo "2. Restoring from that backup"
echo "3. Applying any transaction logs or incremental changes up to the recovery point"
echo "4. Verifying data consistency"
```

### Step 10: Backup Verification and Monitoring

```bash
# Create backup verification script
cat << 'EOF' > verify-backup.sh
#!/bin/bash

BACKUP_ALIAS="backup"
BACKUP_BUCKET="production-backup"

echo "=== Backup Verification Report ==="
echo "Generated at: $(date)"
echo ""

# List all backups
echo "Available Backups:"
mc ls ${BACKUP_ALIAS}/${BACKUP_BUCKET}/ | while read line; do
    backup_name=$(echo $line | awk '{print $5}')
    backup_date=$(echo $line | awk '{print $1, $2}')
    echo "  - $backup_name ($backup_date)"
done

echo ""

# Check latest backup integrity
LATEST_BACKUP=$(mc ls ${BACKUP_ALIAS}/${BACKUP_BUCKET}/ | tail -1 | awk '{print $5}')
echo "Latest Backup: $LATEST_BACKUP"

if [ -n "$LATEST_BACKUP" ]; then
    echo "Verifying latest backup integrity..."
    
    # Check if manifest exists
    if mc stat ${BACKUP_ALIAS}/${BACKUP_BUCKET}/${LATEST_BACKUP}/backup-manifest-*.txt >/dev/null 2>&1; then
        echo "✅ Backup manifest found"
        mc cat ${BACKUP_ALIAS}/${BACKUP_BUCKET}/${LATEST_BACKUP}/backup-manifest-*.txt
    else
        echo "❌ Backup manifest missing"
    fi
    
    # Check backup size
    echo ""
    echo "Backup Size Analysis:"
    mc du ${BACKUP_ALIAS}/${BACKUP_BUCKET}/${LATEST_BACKUP}/
    
    # Verify some key files exist
    echo ""
    echo "Key Files Verification:"
    mc ls ${BACKUP_ALIAS}/${BACKUP_BUCKET}/${LATEST_BACKUP}/production-data/documents/ >/dev/null 2>&1 && echo "✅ Documents backed up" || echo "❌ Documents missing"
    mc ls ${BACKUP_ALIAS}/${BACKUP_BUCKET}/${LATEST_BACKUP}/test-bucket/ >/dev/null 2>&1 && echo "✅ Test bucket backed up" || echo "❌ Test bucket missing"
else
    echo "❌ No backups found"
fi

echo ""
echo "=== End of Verification Report ==="
EOF

chmod +x verify-backup.sh

# Run backup verification
./verify-backup.sh

# Create backup monitoring alerts (for integration with monitoring from Module 8)
cat << EOF > backup-monitoring-queries.txt
# Prometheus queries for backup monitoring

# Time since last successful backup
time() - minio_backup_last_success_timestamp

# Backup failure rate
rate(minio_backup_failures_total[24h])

# Backup size growth
increase(minio_backup_size_bytes[7d])

# Recovery time objective monitoring
minio_recovery_time_seconds > 3600  # Alert if recovery takes more than 1 hour

# Recovery point objective monitoring
time() - minio_last_backup_timestamp > 86400  # Alert if no backup in 24 hours
EOF

echo "Backup monitoring queries saved to backup-monitoring-queries.txt"
```

## 🔍 Understanding Backup Strategies

### Backup Types Comparison

| Type | Pros | Cons | Use Case |
|------|------|------|---------|
| **Full** | Complete data copy, simple restore | Large storage, long time | Weekly/monthly |
| **Incremental** | Fast, efficient storage | Complex restore chain | Daily |
| **Differential** | Faster restore than incremental | Larger than incremental | Every few days |
| **Continuous** | Minimal data loss | Complex, resource intensive | Critical systems |

### Recovery Scenarios

#### Data Corruption
- **Detection**: Monitoring alerts, user reports
- **Response**: Restore from last known good backup
- **Prevention**: Checksums, versioning, replication

#### Accidental Deletion
- **Detection**: User reports, missing data alerts
- **Response**: Restore specific objects/buckets
- **Prevention**: Access controls, versioning, soft delete

#### Site Disaster
- **Detection**: Infrastructure monitoring
- **Response**: Failover to backup site
- **Prevention**: Geographic replication, DR testing

#### Ransomware Attack
- **Detection**: Unusual encryption activity
- **Response**: Isolate, restore from clean backup
- **Prevention**: Immutable backups, access controls

## ✅ Validation Checklist

Before proceeding to Module 10, ensure:

- [ ] Backup MinIO instance deployed and accessible
- [ ] Object versioning enabled on critical buckets
- [ ] Full backup script created and tested
- [ ] Incremental backup script created and tested
- [ ] Automated backup CronJob configured
- [ ] Disaster recovery scenario tested successfully
- [ ] Point-in-time recovery concepts understood
- [ ] Backup verification process implemented

## 🚨 Common Issues & Solutions

### Issue: Backup Takes Too Long

```bash
# Use parallel transfers
mc mirror --parallel 10 source/ destination/

# Exclude unnecessary files
mc mirror --exclude "*.tmp" --exclude "*.log" source/ destination/

# Use compression for network transfers
mc mirror --compress source/ destination/
```

### Issue: Backup Storage Full

```bash
# Implement backup retention policy
# Delete backups older than 30 days
find /backup/path -name "full-*" -mtime +30 -delete

# Use lifecycle policies
mc ilm add --expiry-days 30 backup/old-backups
```

### Issue: Restore Fails

```bash
# Verify backup integrity first
mc ls backup/production-backup/latest-backup/

# Check permissions
mc admin user info backup backup-admin

# Test with small subset first
mc cp backup/production-backup/latest-backup/test-file.txt local/test-restore/
```

### Issue: Inconsistent Backups

```bash
# Use atomic operations
mc mirror --overwrite source/ destination/

# Verify checksums
mc mirror --checksum source/ destination/

# Use backup locks
mc retention set --default GOVERNANCE "30d" backup/production-backup
```

## 🔧 Advanced Backup Features (Optional)

### Cross-Region Replication

```bash
# Set up replication to another region
mc replicate add local/production-data backup/disaster-recovery \
  --priority 1 \
  --storage-class STANDARD
```

### Backup Encryption

```bash
# Encrypt backups at rest
mc encrypt set sse-s3 backup/production-backup/
```

### Backup Compression

```bash
# Use compression for space efficiency
mc mirror --compress local/production-data backup/compressed-backup/
```

## 📊 Backup Best Practices

### 3-2-1 Rule
- **3** copies of important data
- **2** different storage media
- **1** offsite backup

### Testing Strategy
- **Monthly**: Full restore test
- **Weekly**: Partial restore test
- **Daily**: Backup verification
- **Quarterly**: Disaster recovery drill

### Documentation
- Recovery procedures
- Contact information
- System dependencies
- Testing schedules

### Monitoring
- Backup success/failure rates
- Backup duration trends
- Storage usage growth
- Recovery time metrics

## 📖 Additional Reading

- [MinIO Backup Best Practices](https://docs.min.io/minio/baremetal/operations/backup-restore.html)
- [Disaster Recovery Planning](https://docs.min.io/minio/baremetal/operations/disaster-recovery.html)
- [Object Versioning Guide](https://docs.min.io/minio/baremetal/administration/object-management.html#versioning)

## ➡️ Next Steps

Now that you have comprehensive backup and disaster recovery capabilities:

```bash
cd ../10-security
cat README.md
```

---

**🎉 Outstanding!** You've implemented a robust backup and disaster recovery system for MinIO. You understand different backup strategies, have automated backup processes, and can recover from various disaster scenarios. In the next module, we'll focus on security hardening to protect your MinIO deployment from threats.
