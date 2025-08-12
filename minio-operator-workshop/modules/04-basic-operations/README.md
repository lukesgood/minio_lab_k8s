# Module 4: Basic Operations & Client Setup

## 🎯 Learning Objectives

By the end of this module, you will:
- Install and configure MinIO Client (mc) using official methods
- Perform basic S3 operations with official MinIO deployment
- Understand data flow with official service endpoints
- Verify data integrity using official MinIO client commands
- Master essential MinIO client commands with official examples

## 📚 Key Concepts

### Official MinIO Client (mc)
The MinIO Client provides a modern alternative to UNIX commands like ls, cat, cp, mirror, diff, find etc. It supports filesystems and Amazon S3 compatible cloud storage services, and is the official tool for interacting with MinIO.

### Official S3 API Compatibility
MinIO provides full compatibility with Amazon S3 APIs, making it a drop-in replacement for S3 in many applications, following official AWS S3 specifications.

## 📋 Step-by-Step Instructions

### Step 1: Install Official MinIO Client

```bash
# Download official MinIO client (latest stable)
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

# Make it executable
chmod +x $HOME/minio-binaries/mc

# Add to PATH for this session
export PATH=$PATH:$HOME/minio-binaries

# Verify installation with official version check
mc --version
```

**Expected Output:**
```
mc version RELEASE.2024-10-08T09-37-26Z
```

### Step 2: Configure MinIO Client (Official Service Names)

```bash
# Ensure port forwarding is active for official services
kubectl port-forward svc/tenant-lite-hl -n tenant-lite 9000:9000 &

# Configure mc to connect to our official MinIO instance
mc alias set minio-official http://localhost:9000 minio minio123

# Verify connection using official admin command
mc admin info minio-official
```

**Expected Output:**
```
●  localhost:9000
   Uptime: 5 minutes
   Version: 2024-10-02T17:50:41Z
   Network: 1/1 OK
   Drives: 4/4 OK
   Pool: 1
```

### Step 3: Basic Bucket Operations (Official Commands)

```bash
# List existing buckets (should be empty initially)
mc ls minio-official

# Create a new bucket using official naming conventions
mc mb minio-official/test-bucket

# Create additional buckets for testing
mc mb minio-official/documents
mc mb minio-official/images

# List buckets again
mc ls minio-official
```

**Expected Output:**
```
[2025-08-12 04:44:00 UTC]     0B documents/
[2025-08-12 04:44:00 UTC]     0B images/
[2025-08-12 04:44:00 UTC]     0B test-bucket/
```

### Step 4: Basic Object Operations

```bash
# Create test files
echo "Hello Official MinIO Workshop!" > test-file.txt
echo "This is a sample document" > document.txt
dd if=/dev/zero of=large-file.dat bs=1M count=5

# Upload files to buckets using official commands
mc cp test-file.txt minio-official/test-bucket/
mc cp document.txt minio-official/documents/
mc cp large-file.dat minio-official/test-bucket/

# List objects in buckets
mc ls minio-official/test-bucket/
mc ls minio-official/documents/
```

### Step 5: Verify Data Integrity (Official Verification)

```bash
# Download files and compare using official commands
mc cp minio-official/test-bucket/test-file.txt downloaded-test-file.txt
mc cp minio-official/documents/document.txt downloaded-document.txt

# Compare original and downloaded files
diff test-file.txt downloaded-test-file.txt
diff document.txt downloaded-document.txt

# Check file sizes using official stat command
mc stat minio-official/test-bucket/test-file.txt
mc stat minio-official/test-bucket/large-file.dat
```

### Step 6: Explore Object Metadata (Official Commands)

```bash
# Get detailed object information using official stat command
mc stat minio-official/test-bucket/test-file.txt
mc stat minio-official/test-bucket/large-file.dat

# List objects with detailed information
mc ls --recursive minio-official/
```

**Expected Output:**
```
Name      : test-file.txt
Date      : 2025-08-12 04:44:00 UTC
Size      : 30 B
ETag      : 9bb58f26192e4ba00f01e2e7b136bbd8
Type      : file
Metadata  :
  Content-Type: text/plain
```

### Step 7: Verify Actual Storage Locations (Official Structure)

Now let's see where the data is actually stored using official tenant structure:

```bash
# Check MinIO's official internal directory structure
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- find /export -name "*.txt" -o -name "*.dat" 2>/dev/null

# Look at the official erasure coding structure
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- ls -la /export/data1/
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- ls -la /export/data2/

# Check official bucket directories
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- find /export -type d -name "*test-bucket*"
```

### Step 8: Understanding Official Erasure Coding Storage

```bash
# MinIO splits files across multiple drives using official erasure coding
# Let's see how our files are distributed in the official structure

# Check each official data directory for our bucket
for i in {1..4}; do
  echo "=== Official Data directory $i ==="
  kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- ls -la /export/data${i}/ 2>/dev/null || echo "Directory not accessible"
done

# Look for MinIO's official internal file structure
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- find /export -type f -name "xl.meta" | head -5
```

### Step 9: Advanced Object Operations (Official Commands)

```bash
# Copy objects within MinIO using official commands
mc cp minio-official/test-bucket/test-file.txt minio-official/documents/copied-file.txt

# Mirror a directory to MinIO using official mirror command
mkdir local-docs
echo "Local document 1" > local-docs/doc1.txt
echo "Local document 2" > local-docs/doc2.txt
mc mirror local-docs/ minio-official/documents/local-docs/

# Sync files using official mirror command (like rsync)
echo "Updated content" > local-docs/doc1.txt
mc mirror local-docs/ minio-official/documents/local-docs/

# List all objects recursively using official command
mc ls --recursive minio-official/
```

### Step 10: Object Versioning and Metadata (Official Features)

```bash
# Set custom metadata using official attr parameter
mc cp test-file.txt minio-official/test-bucket/metadata-test.txt \
  --attr "Author=Workshop,Department=Engineering,Project=MinIO-Official-Lab"

# View object with metadata using official stat command
mc stat minio-official/test-bucket/metadata-test.txt

# Create multiple versions of the same object (official versioning)
echo "Version 1" > version-test.txt
mc cp version-test.txt minio-official/test-bucket/

echo "Version 2" > version-test.txt
mc cp version-test.txt minio-official/test-bucket/

# Check object information using official commands
mc stat minio-official/test-bucket/version-test.txt
```

### Step 11: Official Health and Performance Checks

```bash
# Use official admin commands to check cluster health
mc admin info minio-official

# Run official performance test
mc admin speedtest minio-official --duration=30s

# Check official server configuration
mc admin config get minio-official

# View official server logs
mc admin logs minio-official
```

## 🔍 Understanding the Official Results

### Official Data Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   mc client │───▶│  Port Fwd   │───▶│ Official    │───▶│ Official    │
│  (official) │    │ :9000       │    │ MinIO API   │    │ StatefulSet │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                 │
                                                                 ▼
                                                    ┌─────────────────────┐
                                                    │ Official Erasure    │
                                                    │ Coded Storage       │
                                                    │ /export/data1-4/    │
                                                    └─────────────────────┘
```

### Official Erasure Coding in Action

With EC:2 configuration (official default for 4 drives):
- Files are split into data and parity chunks using official algorithm
- Distributed across 4 drives following official layout
- Can recover from 2 drive failures (official tolerance)
- Storage efficiency: ~50% (official calculation)

### Official File Storage Structure

```
/export/ (official mount path)
├── data1/ (official drive 1)
│   ├── .minio.sys/ (official system data)
│   └── test-bucket/ (official bucket structure)
├── data2/ (official drive 2)
│   ├── .minio.sys/
│   └── test-bucket/
├── data3/ (official drive 3)
│   └── test-bucket/
└── data4/ (official drive 4)
    └── test-bucket/
```

## ✅ Validation Checklist

Before proceeding to Module 5, ensure:

- [ ] Official MinIO client (mc) is installed and working
- [ ] Successfully connected to official MinIO instance
- [ ] Created buckets and uploaded objects using official commands
- [ ] Verified data integrity (download matches upload)
- [ ] Explored object metadata using official stat command
- [ ] Understood official erasure coding storage distribution
- [ ] Performed advanced operations (copy, mirror, sync) with official commands
- [ ] Used official admin commands for health checks

## 🚨 Common Issues & Solutions

### Issue: Official mc Connection Fails
```bash
# Check port forwarding is active for official service
ps aux | grep "kubectl port-forward.*tenant-lite-hl"

# Restart port forwarding if needed
pkill -f "kubectl port-forward.*tenant-lite"
kubectl port-forward svc/tenant-lite-hl -n tenant-lite 9000:9000 &

# Test connection using official health endpoint
curl -I http://localhost:9000/minio/health/live
```

### Issue: Permission Denied with Official Credentials
```bash
# Verify official credentials are correct
mc admin info minio-official

# Check official secret format
kubectl get secret tenant-lite-secret -n tenant-lite -o yaml
```

### Issue: Large File Upload Fails
```bash
# Check available storage space in official tenant
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- df -h /export

# Check official MinIO logs for errors
kubectl logs -n tenant-lite tenant-lite-pool-0-0
```

## 🔧 Advanced Operations

### Official Batch Operations

```bash
# Upload multiple files at once using official commands
mc cp --recursive local-docs/ minio-official/batch-upload/

# Remove objects using official commands
mc rm minio-official/test-bucket/large-file.dat
mc rm --recursive minio-official/batch-upload/
```

### Official Performance Testing

```bash
# Time large file operations using official commands
time mc cp large-file.dat minio-official/test-bucket/performance-test.dat
time mc cp minio-official/test-bucket/performance-test.dat downloaded-performance-test.dat

# Check transfer statistics using official stat
mc stat minio-official/test-bucket/performance-test.dat
```

### Official Admin Operations

```bash
# List official policies (should be empty initially)
mc admin policy list minio-official

# Check official server info
mc admin info minio-official

# View official configuration
mc admin config get minio-official
```

## 📖 Official Resources

- [Official MinIO Client Guide](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [Official S3 API Compatibility](https://min.io/docs/minio/linux/developers/s3-compatible-api.html)
- [Official MinIO Documentation](https://min.io/docs/minio/kubernetes/upstream/)

## ➡️ Next Steps

Now that you've mastered basic MinIO operations with official methods:

```bash
cd ../05-advanced-s3
cat README.md
```

---

**🎉 Fantastic!** You've successfully set up the official MinIO client and performed essential object storage operations using official methods and commands. You've seen how data flows from the client through official Kubernetes services to the actual storage, and how MinIO's official erasure coding protects your data. In the next module, we'll explore advanced S3 API features using official MinIO capabilities.
