# Module 6: Performance Testing & Optimization (Official Methods)

## 🎯 Learning Objectives

By the end of this module, you will:
- Conduct comprehensive performance benchmarks using official MinIO tools
- Understand official MinIO performance characteristics and metrics
- Identify bottlenecks using official diagnostic tools
- Use official built-in and external benchmarking tools
- Analyze performance metrics using official MinIO admin commands

## 📚 Key Concepts

### Official Performance Metrics
- **Throughput**: Data transfer rate (MB/s, GB/s) measured by official tools
- **IOPS**: Input/Output Operations Per Second using official benchmarks
- **Latency**: Time to complete operations measured by official diagnostics
- **Concurrency**: Simultaneous operations handling with official load testing

### Official Factors Affecting Performance
- File size and type (measured by official benchmarks)
- Network bandwidth (tested with official tools)
- Storage backend performance (analyzed with official diagnostics)
- CPU and memory resources (monitored with official admin commands)
- Concurrent connections (tested with official load generators)

## 📋 Step-by-Step Instructions (Official Methods)

### Step 1: Prepare Official Performance Testing Environment

```bash
# Ensure clean environment using official commands
mc rm --recursive --force minio-official/perf-test/ 2>/dev/null || true
mc mb minio-official/perf-test

# Create test files of various sizes for official testing
echo "Creating test files for official performance testing..."
dd if=/dev/zero of=1kb.dat bs=1K count=1
dd if=/dev/zero of=1mb.dat bs=1M count=1
dd if=/dev/zero of=10mb.dat bs=1M count=10
dd if=/dev/zero of=50mb.dat bs=1M count=50
dd if=/dev/zero of=100mb.dat bs=1M count=100

echo "Test files created for official benchmarking:"
ls -lh *.dat
```

### Step 2: Official Upload Performance Testing

```bash
# Test upload performance for different file sizes using official methods
echo "=== Official Upload Performance Testing ==="

# Small file performance using official commands
echo "Testing 1KB file uploads with official mc..."
for i in {1..10}; do
  time_output=$(time mc cp 1kb.dat minio-official/perf-test/1kb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done

# Medium file performance using official commands
echo "Testing 10MB file uploads with official mc..."
for i in {1..5}; do
  time_output=$(time mc cp 10mb.dat minio-official/perf-test/10mb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done

# Large file performance using official commands
echo "Testing 100MB file uploads with official mc..."
for i in {1..3}; do
  time_output=$(time mc cp 100mb.dat minio-official/perf-test/100mb-${i}.dat 2>&1)
  echo "Upload $i: $time_output"
done
```

### Step 3: Official MinIO Built-in Performance Testing

```bash
echo "=== Official MinIO Built-in Performance Testing ==="

# Use official MinIO's built-in speed test
mc admin speedtest minio-official

# Run extended official speed test with custom parameters
mc admin speedtest minio-official --duration=30s --size=64MB

# Test with different object sizes using official speedtest
mc admin speedtest minio-official --duration=15s --size=1MB
mc admin speedtest minio-official --duration=15s --size=32MB

# Run official network performance test
mc admin speedtest minio-official --duration=60s --concurrent=10
```

### Step 4: Official Performance Summary and Analysis

```bash
echo "=== Official Performance Summary ==="

# Get current system information using official commands
echo "System Information:"
echo "- MinIO Version: $(mc admin info minio-official | grep Version)"
echo "- Kubernetes Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "- Storage Class: $(kubectl get pvc -n tenant-lite -o jsonpath='{.items[0].spec.storageClassName}')"

# Official performance recommendations
echo ""
echo "Official Performance Observations:"
echo "1. Small files (< 1MB): Best for high-frequency operations"
echo "2. Large files (> 50MB): Benefit from official multipart upload"
echo "3. Concurrent operations: Improve overall throughput significantly"
echo "4. Batch operations: Efficient for many small files using official mirror"
echo "5. Network latency: Minimal impact in local cluster"

# Run final official diagnostic
echo ""
echo "Final Official Diagnostic:"
mc admin info minio-official
```

## ✅ Validation Checklist

Before proceeding to Module 7, ensure:

- [ ] Completed upload performance tests using official mc commands
- [ ] Used official MinIO's built-in speedtest tool
- [ ] Understood official performance characteristics and bottlenecks

## 📖 Official Resources

- [Official MinIO Performance Tuning](https://min.io/docs/minio/linux/operations/performance-tuning.html)
- [Official MinIO Benchmarking](https://min.io/docs/minio/linux/reference/minio-mc-admin-speedtest.html)

## ➡️ Next Steps

Now that you understand official MinIO performance characteristics:

```bash
cd ../07-user-management
cat README.md
```

---

**🎉 Outstanding!** You've conducted comprehensive performance testing using official MinIO tools and understand how to optimize MinIO for different workloads using official methods.
