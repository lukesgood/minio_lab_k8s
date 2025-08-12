# Module 4: Basic Operations & Client Setup

## 🎯 Learning Objectives

By the end of this module, you will:
- Install and configure MinIO Client (mc)
- Perform basic S3 operations (buckets, objects)
- Understand data flow and storage verification
- Verify data integrity and actual file locations
- Master essential MinIO client commands

## 📚 Key Concepts

### MinIO Client (mc)
The MinIO Client provides a modern alternative to UNIX commands like ls, cat, cp, mirror, diff, find etc. It supports filesystems and Amazon S3 compatible cloud storage services.

### S3 API Compatibility
MinIO provides full compatibility with Amazon S3 APIs, making it a drop-in replacement for S3 in many applications.

## 📋 Step-by-Step Instructions

### Step 1: Install MinIO Client

```bash
# Download and install MinIO client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

# Make it executable
chmod +x $HOME/minio-binaries/mc

# Add to PATH for this session
export PATH=$PATH:$HOME/minio-binaries

# Verify installation
mc --version
```

**Expected Output:**
```
mc version RELEASE.2025-07-23T15-54-02Z
```

### Step 2: Configure MinIO Client

```bash
# Ensure port forwarding is active
kubectl port-forward svc/minio -n minio-tenant 9000:80 &

# Configure mc to connect to our MinIO instance
mc alias set local http://localhost:9000 admin password123

# Verify connection
mc admin info local
```

**Expected Output:**
```
●  localhost:9000
   Uptime: 5 minutes
   Version: 2025-04-08T15:41:24Z
   Network: 1/1 OK
   Drives: 4/4 OK
   Pool: 1
```

### Step 3: Basic Bucket Operations

```bash
# List existing buckets (should be empty initially)
mc ls local

# Create a new bucket
mc mb local/test-bucket

# Create additional buckets for testing
mc mb local/documents
mc mb local/images

# List buckets again
mc ls local
```

**Expected Output:**
```
[2025-08-11 23:55:00 UTC]     0B documents/
[2025-08-11 23:55:00 UTC]     0B images/
[2025-08-11 23:55:00 UTC]     0B test-bucket/
```

### Step 4: Basic Object Operations

```bash
# Create test files
echo "Hello MinIO Workshop!" > test-file.txt
echo "This is a sample document" > document.txt
dd if=/dev/zero of=large-file.dat bs=1M count=5

# Upload files to buckets
mc cp test-file.txt local/test-bucket/
mc cp document.txt local/documents/
mc cp large-file.dat local/test-bucket/

# List objects in buckets
mc ls local/test-bucket/
mc ls local/documents/
```

### Step 5: Verify Data Integrity

```bash
# Download files and compare
mc cp local/test-bucket/test-file.txt downloaded-test-file.txt
mc cp local/documents/document.txt downloaded-document.txt

# Compare original and downloaded files
diff test-file.txt downloaded-test-file.txt
diff document.txt downloaded-document.txt

# Check file sizes
ls -lh test-file.txt downloaded-test-file.txt
ls -lh large-file.dat
mc ls local/test-bucket/large-file.dat
```

### Step 6: Explore Object Metadata

```bash
# Get detailed object information
mc stat local/test-bucket/test-file.txt
mc stat local/test-bucket/large-file.dat

# List objects with detailed information
mc ls --recursive local/
```

**Expected Output:**
```
Name      : test-file.txt
Date      : 2025-08-11 23:55:00 UTC
Size      : 22 B
ETag      : 9bb58f26192e4ba00f01e2e7b136bbd8
Type      : file
Metadata  :
  Content-Type: text/plain
```

### Step 7: Verify Actual Storage Locations

Now let's see where the data is actually stored on the filesystem:

```bash
# Check MinIO's internal directory structure
kubectl exec -n minio-tenant minio-pool-0-0 -- find /export -name "*.txt" -o -name "*.dat" 2>/dev/null

# Look at the erasure coding structure
kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export/data1/
kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export/data2/

# Check bucket directories
kubectl exec -n minio-tenant minio-pool-0-0 -- find /export -type d -name "*test-bucket*"
```

### Step 8: Understanding Erasure Coding Storage

```bash
# MinIO splits files across multiple drives using erasure coding
# Let's see how our files are distributed

# Check each data directory for our bucket
for i in {1..4}; do
  echo "=== Data directory $i ==="
  kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export/data${i}/ 2>/dev/null || echo "Directory not accessible"
done

# Look for MinIO's internal file structure
kubectl exec -n minio-tenant minio-pool-0-0 -- find /export -type f -name "xl.meta" | head -5
```

### Step 9: Advanced Object Operations

```bash
# Copy objects within MinIO
mc cp local/test-bucket/test-file.txt local/documents/copied-file.txt

# Mirror a directory to MinIO
mkdir local-docs
echo "Local document 1" > local-docs/doc1.txt
echo "Local document 2" > local-docs/doc2.txt
mc mirror local-docs/ local/documents/local-docs/

# Sync files (like rsync)
echo "Updated content" > local-docs/doc1.txt
mc mirror local-docs/ local/documents/local-docs/

# List all objects recursively
mc ls --recursive local/
```

### Step 10: Object Versioning and Metadata

```bash
# Set custom metadata
mc cp test-file.txt local/test-bucket/metadata-test.txt \
  --attr "Author=Workshop,Department=Engineering,Project=MinIO-Lab"

# View object with metadata
mc stat local/test-bucket/metadata-test.txt

# Create multiple versions of the same object
echo "Version 1" > version-test.txt
mc cp version-test.txt local/test-bucket/

echo "Version 2" > version-test.txt
mc cp version-test.txt local/test-bucket/

# Check object information
mc stat local/test-bucket/version-test.txt
```

## 🔍 Understanding the Results

### Data Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   mc client │───▶│  Port Fwd   │───▶│ MinIO API   │───▶│ StatefulSet │
│             │    │ :9000       │    │ Service     │    │ Pod         │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                 │
                                                                 ▼
                                                    ┌─────────────────────┐
                                                    │ Erasure Coded       │
                                                    │ Storage             │
                                                    │ /export/data1-4/    │
                                                    └─────────────────────┘
```

### Erasure Coding in Action

With EC:2 configuration:
- Files are split into data and parity chunks
- Distributed across 4 drives
- Can recover from 2 drive failures
- Storage efficiency: ~50%

### File Storage Structure

```
/export/
├── data1/
│   ├── .minio.sys/
│   └── test-bucket/
├── data2/
│   ├── .minio.sys/
│   └── test-bucket/
├── data3/
│   └── test-bucket/
└── data4/
    └── test-bucket/
```

## ✅ Validation Checklist

Before proceeding to Module 5, ensure:

- [ ] MinIO client (mc) is installed and working
- [ ] Successfully connected to MinIO instance
- [ ] Created buckets and uploaded objects
- [ ] Verified data integrity (download matches upload)
- [ ] Explored object metadata and properties
- [ ] Understood erasure coding storage distribution
- [ ] Performed advanced operations (copy, mirror, sync)

## 🚨 Common Issues & Solutions

### Issue: mc Connection Fails
```bash
# Check port forwarding is active
ps aux | grep "kubectl port-forward"

# Restart port forwarding if needed
pkill -f "kubectl port-forward"
kubectl port-forward svc/minio -n minio-tenant 9000:80 &

# Test connection
curl -I http://localhost:9000/minio/health/live
```

### Issue: Permission Denied on Upload
```bash
# Verify credentials are correct
mc admin info local

# Check bucket policies (should be empty for new buckets)
mc admin policy list local
```

### Issue: Large File Upload Fails
```bash
# Check available storage space
kubectl exec -n minio-tenant minio-pool-0-0 -- df -h /export

# Check MinIO logs for errors
kubectl logs -n minio-tenant minio-pool-0-0
```

### Issue: Objects Not Found After Upload
```bash
# Check if upload actually completed
mc ls local/test-bucket/ --recursive

# Verify MinIO is healthy
mc admin info local
```

## 🔧 Advanced Operations (Optional)

### Batch Operations

```bash
# Upload multiple files at once
mc cp --recursive local-docs/ local/batch-upload/

# Remove objects
mc rm local/test-bucket/large-file.dat
mc rm --recursive local/batch-upload/
```

### Performance Testing

```bash
# Time large file operations
time mc cp large-file.dat local/test-bucket/performance-test.dat
time mc cp local/test-bucket/performance-test.dat downloaded-performance-test.dat

# Check transfer statistics
mc stat local/test-bucket/performance-test.dat
```

### Bucket Policies (Preview)

```bash
# List current policies (should be empty)
mc admin policy list local

# We'll explore this more in Module 7
```

## 📖 Additional Reading

- [MinIO Client Complete Guide](https://docs.min.io/minio/baremetal/reference/minio-mc.html)
- [S3 API Compatibility](https://docs.min.io/minio/baremetal/reference/s3-api-compatibility.html)
- [MinIO Erasure Coding](https://docs.min.io/minio/baremetal/concepts/erasure-coding.html)

## ➡️ Next Steps

Now that you've mastered basic MinIO operations:

```bash
cd ../05-advanced-s3
cat README.md
```

---

**🎉 Fantastic!** You've successfully set up the MinIO client and performed essential object storage operations. You've seen how data flows from the client through Kubernetes services to the actual storage, and how MinIO's erasure coding protects your data. In the next module, we'll explore advanced S3 API features and performance optimization techniques.
