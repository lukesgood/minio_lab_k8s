# Module 5: Advanced S3 API Features

## 🎯 Learning Objectives

By the end of this module, you will:
- Understand and implement multipart uploads
- Work with object metadata and storage classes
- Implement object lifecycle management
- Use advanced S3 API features like presigned URLs
- Optimize upload/download performance for different file sizes

## 📚 Key Concepts

### Multipart Upload
For large files, multipart upload provides better performance, reliability, and the ability to resume interrupted uploads. MinIO automatically uses multipart upload for files larger than 64MB.

### Object Metadata
Custom metadata allows you to store additional information with objects, useful for application-specific data, content management, and automation.

### Storage Classes
MinIO supports different storage classes for cost optimization and performance tuning.

## 📋 Step-by-Step Instructions

### Step 1: Prepare Test Environment

```bash
# Ensure MinIO client is configured and port forwarding is active
mc admin info local

# Create a bucket for advanced testing
mc mb local/advanced-features

# Create test files of different sizes
echo "Small file content" > small-file.txt
dd if=/dev/zero of=medium-file.dat bs=1M count=10
dd if=/dev/zero of=large-file.dat bs=1M count=100
```

### Step 2: Understanding Multipart Uploads

```bash
# Upload small file (single part)
time mc cp small-file.txt local/advanced-features/

# Upload medium file (may use multipart)
time mc cp medium-file.dat local/advanced-features/

# Upload large file (definitely uses multipart)
time mc cp large-file.dat local/advanced-features/

# Check upload details
mc stat local/advanced-features/small-file.txt
mc stat local/advanced-features/large-file.dat
```

### Step 3: Working with Object Metadata

```bash
# Upload file with custom metadata
mc cp small-file.txt local/advanced-features/metadata-example.txt \
  --attr "Content-Type=text/plain,Author=Workshop-User,Department=Engineering,Version=1.0,Environment=Development"

# View object metadata
mc stat local/advanced-features/metadata-example.txt

# Upload with different content types
echo '{"name": "test", "value": 123}' > test.json
mc cp test.json local/advanced-features/ \
  --attr "Content-Type=application/json,API-Version=v1"

# Upload binary file with metadata
mc cp medium-file.dat local/advanced-features/binary-with-metadata.dat \
  --attr "Content-Type=application/octet-stream,Purpose=Testing,Size-Category=Medium"

# List all objects with their metadata
mc ls local/advanced-features/
```

### Step 4: Advanced Copy Operations

```bash
# Copy with metadata preservation
mc cp local/advanced-features/metadata-example.txt local/advanced-features/copied-with-metadata.txt

# Copy with metadata modification
mc cp local/advanced-features/metadata-example.txt local/advanced-features/modified-metadata.txt \
  --attr "Version=2.0,Status=Modified"

# Server-side copy (efficient for large files)
mc cp local/advanced-features/large-file.dat local/advanced-features/server-side-copy.dat

# Compare copy performance
time mc cp local/advanced-features/large-file.dat /tmp/local-copy.dat
time mc cp local/advanced-features/large-file.dat local/advanced-features/server-copy.dat
```

### Step 5: Working with Presigned URLs

```bash
# Generate presigned URL for download (valid for 1 hour)
mc share download local/advanced-features/metadata-example.txt --expire=1h

# Generate presigned URL for upload
mc share upload local/advanced-features/presigned-upload.txt --expire=30m

# Test the presigned download URL (copy the URL from above)
# curl "<presigned-download-url>" -o presigned-download-test.txt
```

### Step 6: Object Versioning Simulation

```bash
# Create multiple versions of the same object
echo "Version 1 content" > versioned-file.txt
mc cp versioned-file.txt local/advanced-features/

echo "Version 2 content - updated" > versioned-file.txt
mc cp versioned-file.txt local/advanced-features/

echo "Version 3 content - final" > versioned-file.txt
mc cp versioned-file.txt local/advanced-features/

# Check current version
mc cat local/advanced-features/versioned-file.txt
mc stat local/advanced-features/versioned-file.txt
```

### Step 7: Batch Operations and Mirroring

```bash
# Create a directory structure for mirroring
mkdir -p local-data/{documents,images,archives}
echo "Document 1" > local-data/documents/doc1.txt
echo "Document 2" > local-data/documents/doc2.txt
echo "Image metadata" > local-data/images/img1.meta
dd if=/dev/zero of=local-data/archives/archive1.tar bs=1M count=5

# Mirror entire directory structure
mc mirror local-data/ local/advanced-features/mirrored-data/

# Update local files and sync
echo "Updated Document 1" > local-data/documents/doc1.txt
echo "New Document 3" > local-data/documents/doc3.txt

# Sync changes (only uploads changed/new files)
mc mirror local-data/ local/advanced-features/mirrored-data/

# List mirrored structure
mc ls --recursive local/advanced-features/mirrored-data/
```

### Step 8: Performance Comparison Tests

```bash
# Test different file sizes and upload methods
echo "=== Performance Testing ==="

# Small files (< 1MB)
for i in {1..5}; do
  dd if=/dev/zero of=small-${i}.dat bs=1K count=100
  time mc cp small-${i}.dat local/advanced-features/perf-test/
done

# Medium files (5-50MB)
for i in {1..3}; do
  dd if=/dev/zero of=medium-${i}.dat bs=1M count=20
  time mc cp medium-${i}.dat local/advanced-features/perf-test/
done

# Large files (>50MB) - observe multipart upload
dd if=/dev/zero of=large-test.dat bs=1M count=75
time mc cp large-test.dat local/advanced-features/perf-test/

# Parallel uploads
mc cp --recursive local-data/ local/advanced-features/parallel-test/ &
mc cp large-test.dat local/advanced-features/parallel-large.dat &
wait

echo "Performance tests completed"
```

### Step 9: Advanced Listing and Search

```bash
# List with different formats and filters
mc ls local/advanced-features/ --recursive
mc ls local/advanced-features/ --recursive --json

# Find objects by pattern
mc find local/advanced-features/ --name "*.txt"
mc find local/advanced-features/ --name "*.dat"
mc find local/advanced-features/ --larger 10MB

# Get storage usage statistics
mc du local/advanced-features/
mc du local/advanced-features/ --depth=2
```

### Step 10: Object Integrity and Verification

```bash
# Calculate and verify checksums
md5sum large-file.dat
mc stat local/advanced-features/large-file.dat | grep ETag

# Download and verify integrity
mc cp local/advanced-features/large-file.dat downloaded-large-file.dat
md5sum downloaded-large-file.dat

# Compare original and downloaded
diff large-file.dat downloaded-large-file.dat
echo "Exit code: $?" # Should be 0 for identical files

# Verify all uploaded files
echo "=== Integrity Verification ==="
for file in small-file.txt medium-file.dat large-file.dat; do
  echo "Verifying $file..."
  mc cp local/advanced-features/$file downloaded-$file
  if diff $file downloaded-$file > /dev/null; then
    echo "✅ $file integrity verified"
  else
    echo "❌ $file integrity check failed"
  fi
done
```

## 🔍 Understanding Advanced Features

### Multipart Upload Benefits

1. **Improved Performance**: Parallel upload of parts
2. **Reliability**: Resume interrupted uploads
3. **Memory Efficiency**: Upload large files without loading entirely into memory
4. **Network Optimization**: Better handling of network issues

### Metadata Use Cases

- **Content Management**: Store document properties, versions, authors
- **Application Integration**: Store application-specific data
- **Automation**: Trigger workflows based on metadata
- **Compliance**: Store audit trails and classification information

### Performance Characteristics

| File Size | Upload Method | Typical Performance |
|-----------|---------------|-------------------|
| < 5MB     | Single Part   | Fast, low overhead |
| 5-64MB    | Single Part   | Good performance |
| > 64MB    | Multipart     | Optimal for large files |
| > 100MB   | Multipart     | Best with parallel parts |

## ✅ Validation Checklist

Before proceeding to Module 6, ensure:

- [ ] Successfully uploaded files of various sizes
- [ ] Observed multipart upload behavior for large files
- [ ] Added and retrieved custom metadata
- [ ] Generated and tested presigned URLs
- [ ] Performed server-side copy operations
- [ ] Completed mirroring and sync operations
- [ ] Verified data integrity for all uploads
- [ ] Understood performance characteristics

## 🚨 Common Issues & Solutions

### Issue: Multipart Upload Fails
```bash
# Check available disk space
kubectl exec -n minio-tenant minio-pool-0-0 -- df -h /export

# Check MinIO logs for errors
kubectl logs -n minio-tenant minio-pool-0-0 | tail -20

# Verify network connectivity
mc admin info local
```

### Issue: Metadata Not Preserved
```bash
# Ensure using correct syntax
mc cp source.txt local/bucket/dest.txt --attr "key=value,key2=value2"

# Check if metadata was actually set
mc stat local/bucket/dest.txt
```

### Issue: Presigned URL Access Denied
```bash
# Verify URL hasn't expired
# Check bucket policies (we'll cover this in Module 7)
mc admin policy list local

# Ensure proper URL encoding
```

### Issue: Poor Upload Performance
```bash
# Check network latency
ping localhost

# Monitor resource usage
kubectl top pods -n minio-tenant

# Consider adjusting multipart thresholds (advanced)
```

## 🔧 Advanced Configuration (Optional)

### Custom Multipart Settings

```bash
# Set custom multipart threshold (advanced users)
export MC_MULTIPART_SIZE=16MB
mc cp large-file.dat local/advanced-features/custom-multipart.dat
```

### Parallel Upload Optimization

```bash
# Upload multiple files in parallel
for i in {1..5}; do
  mc cp medium-file.dat local/advanced-features/parallel-${i}.dat &
done
wait
```

## 📊 Performance Analysis

### Upload Performance Summary

```bash
# Analyze your test results
echo "=== Upload Performance Summary ==="
echo "Small files (< 1MB): Fast, single-part upload"
echo "Medium files (5-50MB): Good performance, may use multipart"
echo "Large files (> 50MB): Multipart upload, optimal for large data"
echo ""
echo "Key observations:"
echo "- Multipart uploads provide better reliability"
echo "- Server-side copy is much faster than download/upload"
echo "- Metadata adds minimal overhead"
echo "- Parallel operations improve overall throughput"
```

## 📖 Additional Reading

- [MinIO Multipart Upload](https://docs.min.io/minio/baremetal/developers/javascript/API.html#putObject)
- [S3 API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
- [Object Metadata Best Practices](https://docs.min.io/minio/baremetal/administration/object-management.html)

## ➡️ Next Steps

Now that you've mastered advanced S3 features:

```bash
cd ../06-performance-testing
cat README.md
```

---

**🎉 Excellent work!** You've explored advanced S3 API features and understand how to optimize MinIO for different use cases. You've learned about multipart uploads, metadata management, and performance optimization techniques. In the next module, we'll dive deeper into performance testing and benchmarking to help you optimize your MinIO deployment for production workloads.
