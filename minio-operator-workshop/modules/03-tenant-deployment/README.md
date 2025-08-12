# Module 3: MinIO Tenant Deployment

## 🎯 Learning Objectives

By the end of this module, you will:
- Deploy a MinIO Tenant using official examples and methods
- Understand official MinIO Tenant architecture and components
- Observe real-time dynamic storage provisioning with official configurations
- Access MinIO Console and API endpoints using official service names
- Verify data persistence using official storage paths

## 📚 Key Concepts

### MinIO Tenant (Official Definition)
A Tenant is a complete MinIO deployment managed by the Operator, following official MinIO architecture patterns. It includes:
- MinIO server pods (StatefulSet) with official images
- Storage volumes (PVCs) with official configurations
- Services for API and Console access using official naming
- Secrets for credentials in official format

### Official Image Repositories
MinIO uses official images hosted on Quay.io:
- **MinIO Server**: `quay.io/minio/minio`
- **MinIO Console**: `quay.io/minio/console`

## 📋 Step-by-Step Instructions

### Step 1: Download Tenant Example

```bash
# Download the official tenant-lite example
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml

# Examine the official configuration
cat tenant-lite.yaml
```

### Step 2: Create Namespace and Credentials (Official Format)

```bash
# Create namespace for our tenant
kubectl create namespace tenant-lite

# Create credentials secret using official format
kubectl create secret generic tenant-lite-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=\"minio\"
export MINIO_ROOT_PASSWORD=\"minio123\"" \
  -n tenant-lite

# Create console secret (official requirement)
kubectl create secret generic tenant-lite-console-secret \
  --from-literal=CONSOLE_PBKDF_PASSPHRASE="SECRET" \
  --from-literal=CONSOLE_PBKDF_SALT="SECRET" \
  --from-literal=CONSOLE_ACCESS_KEY="minio" \
  --from-literal=CONSOLE_SECRET_KEY="minio123" \
  -n tenant-lite
```

### Step 3: Deploy Official MinIO Tenant

```bash
# Apply the official tenant configuration
kubectl apply -f tenant-lite.yaml

# Alternative: Apply directly from GitHub
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml
```

### Step 4: Watch Real-Time Provisioning (Official Resources)

This is where the magic happens! Let's observe the operator creating resources:

```bash
# In one terminal, watch PVCs being created
kubectl get pvc -n tenant-lite -w
```

```bash
# In another terminal, watch pods being created
kubectl get pods -n tenant-lite -w
```

```bash
# In a third terminal, watch PVs being dynamically created
kubectl get pv -w
```

**What You'll Observe:**
1. PVCs created in "Pending" state (WaitForFirstConsumer)
2. StatefulSet pod starts with official MinIO image
3. PVCs transition to "Bound" as pods use them
4. PVs automatically created by the provisioner

### Step 5: Monitor Deployment Progress (Official Status)

```bash
# Check tenant status using official commands
kubectl get tenant tenant-lite -n tenant-lite

# Describe the tenant for detailed information
kubectl describe tenant tenant-lite -n tenant-lite

# Check official MinIO pods
kubectl get pods -n tenant-lite -l v1.min.io/tenant=tenant-lite
```

**Expected Tenant Status:**
```
NAME          STATE         AGE
tenant-lite   Initialized   2m
```

### Step 6: Examine Created Resources (Official Components)

```bash
# List all resources created by the operator
kubectl get all -n tenant-lite

# Check StatefulSet details (official configuration)
kubectl describe statefulset tenant-lite-pool-0 -n tenant-lite

# Examine PVCs and their binding
kubectl get pvc -n tenant-lite -o wide

# Check official services created
kubectl get svc -n tenant-lite
```

**Official Services Created:**
- `tenant-lite-hl` - Headless service for StatefulSet
- `tenant-lite-console` - Console web interface

### Step 7: Verify Storage Provisioning (Official Paths)

```bash
# Check that PVs were created automatically
kubectl get pv

# Examine PV details to see actual storage paths
kubectl describe pv $(kubectl get pv -o jsonpath='{.items[0].metadata.name}')

# List all PV paths (where data is actually stored)
kubectl get pv -o jsonpath='{range .items[*]}{.spec.hostPath.path}{"\n"}{end}' 2>/dev/null || \
kubectl get pv -o jsonpath='{range .items[*]}{.spec.local.path}{"\n"}{end}' 2>/dev/null || \
echo "PV paths not accessible (may be using cloud storage)"
```

### Step 8: Access MinIO Services

```bash
# Set up port forwarding for MinIO API (official service)
kubectl port-forward svc/tenant-lite-hl -n tenant-lite 9000:9000 &

# Set up port forwarding for MinIO Console (official service)
kubectl port-forward svc/tenant-lite-console -n tenant-lite 9090:9090 &

# Verify services are accessible
curl -I http://localhost:9000/minio/health/live
```

### Step 9: Access MinIO Console (Official Interface)

Open your web browser and navigate to:
- **Console URL**: http://localhost:9090
- **Username**: minio
- **Password**: minio123

**Official Console Features to Explore:**
- Dashboard overview with official metrics
- Bucket management with official UI
- User management with official IAM
- Monitoring metrics from official sources
- System settings with official configurations

### Step 10: Verify MinIO API Endpoint (Official Health Checks)

```bash
# Test MinIO API health endpoint (official)
curl http://localhost:9000/minio/health/live

# Test MinIO API ready endpoint (official)
curl http://localhost:9000/minio/health/ready

# Test MinIO API cluster endpoint (official)
curl http://localhost:9000/minio/health/cluster
```

**Expected Response:**
```json
{"status":"ok"}
```

### Step 11: Examine Official Data Storage Structure

```bash
# Find where MinIO data is actually stored (official structure)
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- ls -la /export/

# Check MinIO's official internal directory structure
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- find /export -type d -maxdepth 3

# View official MinIO configuration
kubectl exec -n tenant-lite tenant-lite-pool-0-0 -- cat /tmp/minio-config/config.env
```

**Official MinIO Directory Structure:**
```
/export/
├── .minio.sys/          # MinIO system data (official)
├── data1/               # First drive (official layout)
├── data2/               # Second drive (official layout)
├── data3/               # Third drive (official layout)
└── data4/               # Fourth drive (official layout)
```

## 🔍 Understanding the Official Deployment

### What the Operator Created (Official Components)

1. **StatefulSet**: `tenant-lite-pool-0` with official MinIO image
2. **PVCs**: 4 PVCs per pod with official naming convention
3. **PVs**: 4 automatically provisioned persistent volumes
4. **Services**: 
   - `tenant-lite-hl` (Headless service for StatefulSet)
   - `tenant-lite-console` (Console web interface)
5. **Console Deployment**: Official MinIO Console interface

### Official Erasure Coding Configuration

With 4 volumes per server (official default):
- **EC:2 Configuration**: Can tolerate 2 drive failures
- **Storage Efficiency**: ~50% (2 data + 2 parity)
- **Data Protection**: High redundancy following official recommendations

### Official Real-Time Provisioning Process

1. **Tenant Created**: Operator receives official Tenant resource
2. **StatefulSet Created**: Operator creates StatefulSet with official PVC templates
3. **PVCs Created**: StatefulSet controller creates PVCs (Pending state)
4. **Pod Scheduled**: Kubernetes schedules the MinIO pod with official image
5. **PVs Provisioned**: Storage provisioner creates PVs when pod uses PVCs
6. **PVCs Bound**: PVCs transition from Pending to Bound
7. **MinIO Started**: Pod starts with official MinIO image and initializes storage

## ✅ Validation Checklist

Before proceeding to Module 4, ensure:

- [ ] Tenant status shows "Initialized"
- [ ] All pods are Running with official MinIO images
- [ ] All PVCs are Bound
- [ ] PVs were automatically created
- [ ] Port forwarding works for both API (9000) and Console (9090)
- [ ] MinIO Console is accessible via web browser with official interface
- [ ] API health endpoints respond correctly

## 🚨 Common Issues & Solutions

### Issue: Official Images Not Pulling
```bash
# Check if images are accessible
kubectl describe pod tenant-lite-pool-0-0 -n tenant-lite

# Verify image repositories
kubectl get tenant tenant-lite -n tenant-lite -o jsonpath='{.spec.image}'
```

### Issue: Console Access Denied
```bash
# Verify console secret was created correctly
kubectl get secret tenant-lite-console-secret -n tenant-lite -o yaml

# Check console pod logs
kubectl logs -n tenant-lite deployment/tenant-lite-console
```

### Issue: Official Services Not Found
```bash
# Check if services were created with official names
kubectl get svc -n tenant-lite

# Verify service endpoints
kubectl get endpoints -n tenant-lite
```

## 🔧 Advanced Configuration

### Using Tenant with Custom Storage

```bash
# Download official tenant example
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/tenant.yaml

# Modify for custom storage class
sed -i 's/storageClassName: ""/storageClassName: "fast-ssd"/' tenant.yaml

# Apply modified official configuration
kubectl apply -f tenant.yaml
```

### Tenant with KES (Encryption)

```bash
# Use official KES-enabled tenant
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/examples/tenant-kes.yaml
```

## 📖 Official Resources

- [Official Tenant Examples](https://github.com/minio/operator/tree/master/examples)
- [Official Tenant Configuration](https://github.com/minio/operator/blob/master/docs/tenant_crd.adoc)
- [Official MinIO Documentation](https://min.io/docs/minio/kubernetes/upstream/)

## ➡️ Next Steps

Now that your official MinIO Tenant is deployed and accessible:

```bash
cd ../04-basic-operations
cat README.md
```

---

**🎉 Outstanding!** You've successfully deployed a MinIO Tenant using official methods and observed the entire provisioning process in real-time. You now have a fully functional S3-compatible object storage system running with official MinIO components. In the next module, we'll learn how to interact with it using the MinIO client and perform basic operations.
