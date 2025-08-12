# Module 6: Performance Testing & Optimization

## 🎯 Learning Objectives

By the end of this module, you will:
- Conduct comprehensive performance benchmarks
- Understand MinIO performance characteristics
- Identify bottlenecks and optimization opportunities
- Use built-in and external benchmarking tools
- Analyze performance metrics and results

## 📚 Key Concepts

### Performance Metrics
- **Throughput**: Data transfer rate (MB/s, GB/s)
- **IOPS**: Input/Output Operations Per Second
- **Latency**: Time to complete operations
- **Concurrency**: Simultaneous operations handling

### Factors Affecting Performance
- File size and type
- Network bandwidth
- Storage backend performance
- CPU and memory resources
- Concurrent connections

## 📋 Step-by-Step Instructions

### Step 1: Prepare Performance Testing Environment

```bash
# Ensure clean environment
mc rm --recursive --force local/perf-test/ 2>/dev/null || true
mc mb local/perf-test

# Create test files of various sizes
echo "Creating test files..."
dd if=/dev/zero of=1kb.dat bs=1K count=1
dd if=/dev/zero of=1mb.dat bs=1M count=1
dd if=/dev/zero of=10mb.dat bs=1M count=10
dd if=/dev/zero of=50mb.dat bs=1M count=50
dd if=/dev/zero of=100mb.dat bs=1M count=100

echo "Test files created:"
ls -lh *.dat
```

### Step 2: Basic Upload Performance Testing

```bash
# Test upload performance for different file sizes
echo "=== Upload Performance Testing ==="

# Small file performance
echo "Testing 1KB file uploads..."
for i in {1..10}; do
  time_output=$(time mc cp 1kb.dat local/perf-test/1kb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done

# Medium file performance
echo "Testing 10MB file uploads..."
for i in {1..5}; do
  time_output=$(time mc cp 10mb.dat local/perf-test/10mb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done

# Large file performance
echo "Testing 100MB file uploads..."
for i in {1..3}; do
  time_output=$(time mc cp 100mb.dat local/perf-test/100mb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done
```

### Step 3: Download Performance Testing

```bash
echo "=== Download Performance Testing ==="

# Download performance tests
echo "Testing downloads..."

# Small file downloads
echo "Testing 1KB file downloads..."
for i in {1..10}; do
  time_output=$(time mc cp local/perf-test/1kb-${i}.dat downloaded-1kb-${i}.dat 2>&1)
  echo "Download $i: $time_output"
done

# Large file downloads
echo "Testing 100MB file downloads..."
for i in {1..3}; do
  time_output=$(time mc cp local/perf-test/100mb-${i}.dat downloaded-100mb-${i}.dat 2>&1)
  echo "Download $i: $time_output"
done

# Clean up downloaded files
rm -f downloaded-*.dat
```

### Step 4: Concurrent Operations Testing

```bash
echo "=== Concurrent Operations Testing ==="

# Concurrent uploads
echo "Testing concurrent uploads..."
start_time=$(date +%s)

# Upload 10 files concurrently
for i in {1..10}; do
  mc cp 10mb.dat local/perf-test/concurrent-${i}.dat &
done

# Wait for all uploads to complete
wait
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Concurrent upload of 10 x 10MB files completed in ${duration} seconds"
echo "Total data: 100MB, Throughput: $((100 / duration)) MB/s"

# Concurrent downloads
echo "Testing concurrent downloads..."
start_time=$(date +%s)

for i in {1..10}; do
  mc cp local/perf-test/concurrent-${i}.dat concurrent-download-${i}.dat &
done

wait
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Concurrent download of 10 x 10MB files completed in ${duration} seconds"
echo "Total data: 100MB, Throughput: $((100 / duration)) MB/s"

# Clean up
rm -f concurrent-download-*.dat
```

### Step 5: MinIO Built-in Performance Testing

```bash
echo "=== MinIO Built-in Performance Testing ==="

# Use MinIO's built-in speed test
mc admin speedtest local

# Run extended speed test with custom parameters
mc admin speedtest local --duration=30s --size=64MB

# Test with different object sizes
mc admin speedtest local --duration=15s --size=1MB
mc admin speedtest local --duration=15s --size=32MB
```

### Step 6: Batch Operations Performance

```bash
echo "=== Batch Operations Performance ==="

# Create multiple small files for batch testing
mkdir -p batch-test
for i in {1..100}; do
  echo "File content $i" > batch-test/file-${i}.txt
done

# Test batch upload performance
echo "Testing batch upload of 100 small files..."
start_time=$(date +%s)
mc mirror batch-test/ local/perf-test/batch-upload/
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Batch upload completed in ${duration} seconds"
echo "Files per second: $((100 / duration))"

# Test batch download performance
echo "Testing batch download of 100 small files..."
start_time=$(date +%s)
mc mirror local/perf-test/batch-upload/ batch-download/
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Batch download completed in ${duration} seconds"
echo "Files per second: $((100 / duration))"

# Clean up
rm -rf batch-test batch-download
```

### Step 7: Resource Monitoring During Tests

```bash
echo "=== Resource Monitoring ==="

# Monitor MinIO pod resources during a large upload
echo "Starting resource monitoring..."

# Start monitoring in background
kubectl top pods -n minio-tenant --no-headers > resource-monitor.log &
MONITOR_PID=$!

# Perform a resource-intensive operation
echo "Uploading large file while monitoring resources..."
time mc cp 100mb.dat local/perf-test/monitored-upload.dat

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

# Show resource usage
echo "Resource usage during upload:"
cat resource-monitor.log | tail -5
rm -f resource-monitor.log
```

### Step 8: Network Latency Impact Testing

```bash
echo "=== Network Latency Impact Testing ==="

# Test local operations (should be fast)
echo "Testing local network performance..."

# Multiple rapid small operations
start_time=$(date +%s.%N)
for i in {1..50}; do
  mc cp 1kb.dat local/perf-test/latency-test-${i}.dat > /dev/null 2>&1
done
end_time=$(date +%s.%N)

duration=$(echo "$end_time - $start_time" | bc)
echo "50 small file uploads completed in ${duration} seconds"
echo "Average time per operation: $(echo "scale=4; $duration / 50" | bc) seconds"

# Clean up latency test files
mc rm --recursive --force local/perf-test/latency-test-* > /dev/null 2>&1
```

### Step 9: Storage Backend Performance Analysis

```bash
echo "=== Storage Backend Analysis ==="

# Check storage performance on the MinIO pod
kubectl exec -n minio-tenant minio-pool-0-0 -- df -h /export

# Test write performance on storage backend
echo "Testing storage backend write performance..."
kubectl exec -n minio-tenant minio-pool-0-0 -- sh -c "
  dd if=/dev/zero of=/export/data1/write-test.dat bs=1M count=50 2>&1 | grep -E 'copied|MB/s'
"

# Test read performance on storage backend
echo "Testing storage backend read performance..."
kubectl exec -n minio-tenant minio-pool-0-0 -- sh -c "
  dd if=/export/data1/write-test.dat of=/dev/null bs=1M 2>&1 | grep -E 'copied|MB/s'
"

# Clean up test file
kubectl exec -n minio-tenant minio-pool-0-0 -- rm -f /export/data1/write-test.dat
```

### Step 10: Performance Summary and Analysis

```bash
echo "=== Performance Summary ==="

# Get current system information
echo "System Information:"
echo "- MinIO Version: $(mc admin info local | grep Version)"
echo "- Kubernetes Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "- Storage Class: $(kubectl get pvc -n minio-tenant -o jsonpath='{.items[0].spec.storageClassName}')"

# Storage usage summary
echo ""
echo "Storage Usage:"
mc du local/perf-test/

# Object count summary
echo ""
echo "Object Count:"
mc ls local/perf-test/ --recursive | wc -l | xargs echo "Total objects:"

# Performance recommendations
echo ""
echo "Performance Observations:"
echo "1. Small files (< 1MB): Best for high-frequency operations"
echo "2. Large files (> 50MB): Benefit from multipart upload"
echo "3. Concurrent operations: Improve overall throughput"
echo "4. Batch operations: Efficient for many small files"
echo "5. Network latency: Minimal impact in local cluster"
```

## 🔍 Performance Analysis

### Expected Performance Characteristics

#### Single Node Setup (Typical Results)
- **Small files (1KB-1MB)**: 100-1000 ops/sec
- **Medium files (10-50MB)**: 50-200 MB/s throughput
- **Large files (100MB+)**: 100-500 MB/s throughput
- **Concurrent operations**: 2-5x improvement over sequential

#### Factors Affecting Performance
1. **Storage Backend**: Local SSD > Local HDD > Network Storage
2. **CPU Resources**: More cores = better concurrent performance
3. **Memory**: Affects caching and multipart upload efficiency
4. **Network**: Kubernetes internal networking is typically fast

### Performance Bottlenecks

Common bottlenecks and solutions:

| Bottleneck | Symptoms | Solutions |
|------------|----------|-----------|
| Storage I/O | Low throughput, high latency | Use faster storage (SSD) |
| CPU | High CPU usage during operations | Increase CPU limits |
| Memory | OOM errors, slow multipart uploads | Increase memory limits |
| Network | Slow transfers, timeouts | Check network policies |

## ✅ Validation Checklist

Before proceeding to Module 7, ensure:

- [ ] Completed upload performance tests for various file sizes
- [ ] Tested download performance and verified results
- [ ] Conducted concurrent operations testing
- [ ] Used MinIO's built-in speedtest tool
- [ ] Analyzed batch operations performance
- [ ] Monitored resource usage during tests
- [ ] Understood performance characteristics and bottlenecks

## 🚨 Common Issues & Solutions

### Issue: Poor Performance Results
```bash
# Check resource limits
kubectl describe pod minio-pool-0-0 -n minio-tenant | grep -A 10 "Limits\|Requests"

# Check storage performance
kubectl exec -n minio-tenant minio-pool-0-0 -- iostat -x 1 3

# Verify no resource constraints
kubectl top pods -n minio-tenant
```

### Issue: Speedtest Fails
```bash
# Check MinIO health
mc admin info local

# Verify sufficient storage space
kubectl exec -n minio-tenant minio-pool-0-0 -- df -h /export

# Check for any errors in logs
kubectl logs -n minio-tenant minio-pool-0-0 | tail -20
```

### Issue: Inconsistent Results
```bash
# Run tests multiple times for average
# Clear caches between tests
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Ensure no other heavy operations running
kubectl get pods --all-namespaces | grep -v Running
```

## 🔧 Performance Optimization Tips

### For Better Upload Performance
1. Use appropriate file sizes (avoid very small files)
2. Leverage concurrent uploads for multiple files
3. Ensure adequate CPU and memory resources
4. Use fast storage backends (SSD preferred)

### For Better Download Performance
1. Implement client-side caching when appropriate
2. Use concurrent downloads for multiple files
3. Consider CDN for frequently accessed content
4. Optimize network configuration

### For Production Deployments
1. Use multiple nodes for better distribution
2. Implement proper resource limits and requests
3. Monitor performance metrics continuously
4. Plan capacity based on workload patterns

## 📊 Benchmark Results Template

Create your own performance baseline:

```bash
# Save your results
cat << EOF > performance-baseline.txt
MinIO Performance Baseline - $(date)
=====================================

Environment:
- Kubernetes Version: $(kubectl version --short --client)
- MinIO Version: $(mc admin info local | grep Version)
- Storage Class: $(kubectl get pvc -n minio-tenant -o jsonpath='{.items[0].spec.storageClassName}')
- Node Count: $(kubectl get nodes --no-headers | wc -l)

Performance Results:
- Small File Upload (1KB): [Your results]
- Medium File Upload (10MB): [Your results]  
- Large File Upload (100MB): [Your results]
- Concurrent Operations: [Your results]
- Built-in Speedtest: [Your results]

Recommendations:
- [Your observations and recommendations]
EOF

echo "Performance baseline saved to performance-baseline.txt"
```

## 📖 Additional Reading

- [MinIO Performance Tuning](https://docs.min.io/minio/baremetal/operations/performance-tuning.html)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Storage Performance Best Practices](https://kubernetes.io/docs/concepts/storage/storage-classes/#performance)

## ➡️ Next Steps

Now that you understand MinIO performance characteristics:

```bash
cd ../07-user-management
cat README.md
```

---

**🎉 Outstanding!** You've conducted comprehensive performance testing and understand how to optimize MinIO for different workloads. You've learned to identify bottlenecks, measure performance metrics, and make data-driven optimization decisions. In the next module, we'll explore user and permission management to secure your MinIO deployment.
