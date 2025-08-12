# Module 5: Advanced S3 API Features

## 🎯 Learning Objectives

By the end of this module, you will:
- Understand and implement official MinIO multipart uploads
- Work with object metadata using official S3-compatible features
- Implement official object lifecycle management
- Use advanced official S3 API features like presigned URLs
- Optimize upload/download performance using official MinIO capabilities

## 📚 Key Concepts

### Official Multipart Upload
MinIO's official implementation automatically uses multipart upload for files larger than 64MB, following AWS S3 specifications for better performance, reliability, and the ability to resume interrupted uploads.

### Official Object Metadata
Custom metadata in MinIO follows official S3 standards, allowing you to store additional information with objects for application-specific data, content management, and automation.

### Official Storage Classes
MinIO supports official S3-compatible storage classes for cost optimization and performance tuning.

## 📋 Step-by-Step Instructions

### Step 1: Prepare Test Environment (Official Setup)

```bash
# Ensure official MinIO client is configured and port forwarding is active
mc admin info minio-official

# Create a bucket for advanced testing using official commands
mc mb minio-official/advanced-features

# Create test files of different sizes for official testing
echo "Small file content" > small-file.txt
dd if=/dev/zero of=medium-file.dat bs=1M count=10
dd if=/dev/zero of=large-file.dat bs=1M count=100
```

### Step 2: Understanding Official Multipart Uploads

```bash
# Upload small file (single part) using official method
time mc cp small-file.txt minio-official/advanced-features/

# Upload medium file (may use multipart) using official method
time mc cp medium-file.dat minio-official/advanced-features/

# Upload large file (definitely uses multipart) using official method
time mc cp large-file.dat minio-official/advanced-features/

# Check upload details using official stat command
mc stat minio-official/advanced-features/small-file.txt
mc stat minio-official/advanced-features/large-file.dat
```

### Step 3: Working with Official Object Metadata

```bash
# Upload file with custom metadata using official attr parameter
mc cp small-file.txt minio-official/advanced-features/metadata-example.txt \
  --attr "Content-Type=text/plain,Author=Workshop-User,Department=Engineering,Version=1.0,Environment=Development"

# View object metadata using official stat command
mc stat minio-official/advanced-features/metadata-example.txt

# Upload with different content types using official method
echo '{"name": "test", "value": 123}' > test.json
mc cp test.json minio-official/advanced-features/ \
  --attr "Content-Type=application/json,API-Version=v1"

# Upload binary file with metadata using official method
mc cp medium-file.dat minio-official/advanced-features/binary-with-metadata.dat \
  --attr "Content-Type=application/octet-stream,Purpose=Testing,Size-Category=Medium"

# List all objects with their metadata
mc ls minio-official/advanced-features/
```

### Step 4: Official Advanced Copy Operations

```bash
# Copy with metadata preservation using official method
mc cp minio-official/advanced-features/metadata-example.txt minio-official/advanced-features/copied-with-metadata.txt

# Copy with metadata modification using official method
mc cp minio-official/advanced-features/metadata-example.txt minio-official/advanced-features/modified-metadata.txt \
  --attr "Version=2.0,Status=Modified"

# Server-side copy (efficient for large files) using official method
mc cp minio-official/advanced-features/large-file.dat minio-official/advanced-features/server-side-copy.dat

# Compare copy performance using official methods
time mc cp minio-official/advanced-features/large-file.dat /tmp/local-copy.dat
time mc cp minio-official/advanced-features/large-file.dat minio-official/advanced-features/server-copy.dat
```

### Step 5: Working with Official Presigned URLs

```bash
# Generate presigned URL for download using official share command (valid for 1 hour)
mc share download minio-official/advanced-features/metadata-example.txt --expire=1h

# Generate presigned URL for upload using official share command
mc share upload minio-official/advanced-features/presigned-upload.txt --expire=30m

# Test the presigned download URL (copy the URL from above)
# curl "<presigned-download-url>" -o presigned-download-test.txt
```

### Step 6: Official Object Versioning Simulation

```bash
# Create multiple versions of the same object using official methods
echo "Version 1 content" > versioned-file.txt
mc cp versioned-file.txt minio-official/advanced-features/

echo "Version 2 content - updated" > versioned-file.txt
mc cp versioned-file.txt minio-official/advanced-features/

echo "Version 3 content - final" > versioned-file.txt
mc cp versioned-file.txt minio-official/advanced-features/

# Check current version using official commands
mc cat minio-official/advanced-features/versioned-file.txt
mc stat minio-official/advanced-features/versioned-file.txt
```

### Step 7: Official Batch Operations and Mirroring

```bash
# Create a directory structure for official mirroring
mkdir -p local-data/{documents,images,archives}
echo "Document 1" > local-data/documents/doc1.txt
echo "Document 2" > local-data/documents/doc2.txt
echo "Image metadata" > local-data/images/img1.meta
dd if=/dev/zero of=local-data/archives/archive1.tar bs=1M count=5

# Mirror entire directory structure using official mirror command
mc mirror local-data/ minio-official/advanced-features/mirrored-data/

# Update local files and sync using official method
echo "Updated Document 1" > local-data/documents/doc1.txt
echo "New Document 3" > local-data/documents/doc3.txt

# Sync changes using official mirror (only uploads changed/new files)
mc mirror local-data/ minio-official/advanced-features/mirrored-data/

# List mirrored structure using official commands
mc ls --recursive minio-official/advanced-features/mirrored-data/
```

### Step 8: Official Performance Comparison Tests

```bash
# Test different file sizes and upload methods using official commands
echo "=== Official Performance Testing ==="

# Small files (< 1MB) using official method
for i in {1..5}; do
  dd if=/dev/zero of=small-${i}.dat bs=1K count=100
  time mc cp small-${i}.dat minio-official/advanced-features/perf-test/
done

# Medium files (5-50MB) using official method
for i in {1..3}; do
  dd if=/dev/zero of=medium-${i}.dat bs=1M count=20
  time mc cp medium-${i}.dat minio-official/advanced-features/perf-test/
done

# Large files (>50MB) - observe official multipart upload
dd if=/dev/zero of=large-test.dat bs=1M count=75
time mc cp large-test.dat minio-official/advanced-features/perf-test/

# Parallel uploads using official method
mc cp --recursive local-data/ minio-official/advanced-features/parallel-test/ &
mc cp large-test.dat minio-official/advanced-features/parallel-large.dat &
wait

echo "Official performance tests completed"
```

### Step 9: Official Advanced Listing and Search

```bash
# List with different formats and filters using official commands
mc ls minio-official/advanced-features/ --recursive
mc ls minio-official/advanced-features/ --recursive --json

# Find objects by pattern using official find command
mc find minio-official/advanced-features/ --name "*.txt"
mc find minio-official/advanced-features/ --name "*.dat"
mc find minio-official/advanced-features/ --larger 10MB

# Get storage usage statistics using official du command
mc du minio-official/advanced-features/
mc du minio-official/advanced-features/ --depth=2
```

### Step 10: Official Object Integrity and Verification

```bash
# Calculate and verify checksums using official methods
md5sum large-file.dat
mc stat minio-official/advanced-features/large-file.dat | grep ETag

# Download and verify integrity using official commands
mc cp minio-official/advanced-features/large-file.dat downloaded-large-file.dat
md5sum downloaded-large-file.dat

# Compare original and downloaded using official verification
diff large-file.dat downloaded-large-file.dat
echo "Exit code: $?" # Should be 0 for identical files

# Verify all uploaded files using official methods
echo "=== Official Integrity Verification ==="
for file in small-file.txt medium-file.dat large-file.dat; do
  echo "Verifying $file..."
  mc cp minio-official/advanced-features/$file downloaded-$file
  if diff $file downloaded-$file > /dev/null; then
    echo "✅ $file integrity verified"
  else
    echo "❌ $file integrity check failed"
  fi
done
```

### Step 11: Official Admin Operations and Monitoring

```bash
# Use official admin commands for advanced monitoring
mc admin info minio-official

# Check official server configuration
mc admin config get minio-official

# View official server logs
mc admin logs minio-official

# Run official performance diagnostics
mc admin speedtest minio-official --duration=60s

# Check official cluster health
mc admin heal minio-official --dry-run
```

## 🔍 Understanding Official Advanced Features

### Official Multipart Upload Benefits

1. **Improved Performance**: Parallel upload of parts using official algorithm
2. **Reliability**: Resume interrupted uploads with official recovery
3. **Memory Efficiency**: Upload large files without loading entirely into memory
4. **Network Optimization**: Better handling of network issues with official retry logic

### Official Metadata Use Cases

- **Content Management**: Store document properties, versions, authors using official metadata
- **Application Integration**: Store application-specific data with official S3 headers
- **Automation**: Trigger workflows based on official metadata tags
- **Compliance**: Store audit trails and classification using official attributes

### Official Performance Characteristics

| File Size | Official Upload Method | Typical Performance |
|-----------|----------------------|-------------------|
| < 5MB     | Single Part (Official) | Fast, low overhead |
| 5-64MB    | Single Part (Official) | Good performance |
| > 64MB    | Multipart (Official)   | Optimal for large files |
| > 100MB   | Multipart (Official)   | Best with parallel parts |

## ✅ Validation Checklist

Before proceeding to Module 6, ensure:

- [ ] Successfully uploaded files of various sizes using official methods
- [ ] Observed official multipart upload behavior for large files
- [ ] Added and retrieved custom metadata using official attr parameter
- [ ] Generated and tested official presigned URLs
- [ ] Performed server-side copy operations using official commands
- [ ] Completed mirroring and sync operations with official mirror
- [ ] Verified data integrity for all uploads using official verification
- [ ] Used official admin commands for monitoring and diagnostics

## 🚨 Common Issues & Solutions

### Issue: Official Multipart Upload Fails
```bash
# Check available disk space using official tenant
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- df -h /export

# Check official MinIO logs for errors
kubectl logs -n tenant-lite tenant-lite-pool-0-0 | tail -20

# Verify network connectivity using official health check
mc admin info minio-official
```

### Issue: Official Metadata Not Preserved
```bash
# Ensure using correct official syntax
mc cp source.txt minio-official/bucket/dest.txt --attr "key=value,key2=value2"

# Check if metadata was actually set using official stat
mc stat minio-official/bucket/dest.txt
```

### Issue: Official Presigned URL Access Denied
```bash
# Verify URL hasn't expired
# Check bucket policies using official admin commands
mc admin policy list minio-official

# Ensure proper URL encoding
```

## 🔧 Official Advanced Configuration (Optional)

### Official Custom Multipart Settings

```bash
# Set custom multipart threshold using official environment variable
export MC_MULTIPART_SIZE=16MB
mc cp large-file.dat minio-official/advanced-features/custom-multipart.dat
```

### Official Parallel Upload Optimization

```bash
# Upload multiple files in parallel using official method
for i in {1..5}; do
  mc cp medium-file.dat minio-official/advanced-features/parallel-${i}.dat &
done
wait
```

## 📊 Official Performance Analysis

### Official Upload Performance Summary

```bash
# Analyze your test results using official methods
echo "=== Official Upload Performance Summary ==="
echo "Small files (< 1MB): Fast, single-part upload (official)"
echo "Medium files (5-50MB): Good performance, may use official multipart"
echo "Large files (> 50MB): Official multipart upload, optimal for large data"
echo ""
echo "Key observations from official testing:"
echo "- Official multipart uploads provide better reliability"
echo "- Server-side copy using official commands is much faster"
echo "- Official metadata adds minimal overhead"
echo "- Parallel operations using official methods improve throughput"
```

## 📖 Official Resources

- [Official MinIO S3 API Documentation](https://min.io/docs/minio/linux/developers/s3-compatible-api.html)
- [Official MinIO Client Reference](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [Official Object Metadata Guide](https://min.io/docs/minio/linux/administration/object-management.html)

## ➡️ Next Steps

Now that you've mastered official advanced S3 features:

```bash
cd ../06-performance-testing
cat README.md
```

---

**🎉 Excellent work!** You've explored official advanced S3 API features and understand how to optimize MinIO using official methods and capabilities. You've learned about official multipart uploads, metadata management, and performance optimization techniques. In the next module, we'll dive deeper into performance testing using official MinIO benchmarking tools.
