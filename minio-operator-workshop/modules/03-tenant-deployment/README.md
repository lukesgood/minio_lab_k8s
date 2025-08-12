# Module 3: MinIO Tenant Deployment

## 🎯 Learning Objectives

By the end of this module, you will:
- Deploy a MinIO Tenant using the Operator
- Understand MinIO Tenant architecture and components
- Observe real-time dynamic storage provisioning
- Access MinIO Console and API endpoints
- Verify data persistence and storage paths

## 📚 Key Concepts

### MinIO Tenant
A Tenant is a complete MinIO deployment managed by the Operator. It includes:
- MinIO server pods (StatefulSet)
- Storage volumes (PVCs)
- Services for API and Console access
- Secrets for credentials

### Erasure Coding
MinIO uses erasure coding for data protection. With EC:4, data is split across 8 drives, allowing up to 4 drive failures while maintaining data integrity.

## 📋 Step-by-Step Instructions

### Step 1: Prepare Tenant Credentials

```bash
# Create credentials secret for MinIO
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant
```

**Security Note**: In production, use stronger passwords and consider using external secret management.

### Step 2: Create MinIO Tenant

```bash
# Create the tenant resource
cat << EOF | kubectl apply -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  credsSecret:
    name: minio-creds-secret
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 4
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
        storageClassName: local-path
  mountPath: /export
  requestAutoCert: false
  console:
    image: minio/console:v1.5.0
    replicas: 1
    consoleSecret:
      name: minio-creds-secret
EOF
```

### Step 3: Watch Real-Time Provisioning

This is where the magic happens! Let's observe the operator creating resources:

```bash
# In one terminal, watch PVCs being created
kubectl get pvc -n minio-tenant -w
```

```bash
# In another terminal, watch pods being created
kubectl get pods -n minio-tenant -w
```

```bash
# In a third terminal, watch PVs being dynamically created
kubectl get pv -w
```

**What You'll Observe:**
1. PVCs created in "Pending" state (WaitForFirstConsumer)
2. StatefulSet pod starts
3. PVCs transition to "Bound" as pods use them
4. PVs automatically created by the provisioner

### Step 4: Monitor Deployment Progress

```bash
# Check tenant status
kubectl get tenant minio -n minio-tenant

# Describe the tenant for detailed information
kubectl describe tenant minio -n minio-tenant
```

**Expected Tenant Status:**
```
NAME    STATE         AGE
minio   Initialized   2m
```

### Step 5: Examine Created Resources

```bash
# List all resources created by the operator
kubectl get all -n minio-tenant

# Check StatefulSet details
kubectl describe statefulset minio-pool-0 -n minio-tenant

# Examine PVCs and their binding
kubectl get pvc -n minio-tenant -o wide
```

### Step 6: Verify Storage Provisioning

```bash
# Check that PVs were created automatically
kubectl get pv

# Examine PV details to see actual storage paths
kubectl describe pv $(kubectl get pv -o jsonpath='{.items[0].metadata.name}')

# List all PV paths (where data is actually stored)
kubectl get pv -o jsonpath='{range .items[*]}{.spec.local.path}{"\n"}{end}'
```

### Step 7: Access MinIO Services

```bash
# Set up port forwarding for MinIO API
kubectl port-forward svc/minio -n minio-tenant 9000:80 &

# Set up port forwarding for MinIO Console
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &

# Verify services are accessible
curl -I http://localhost:9000/minio/health/live
```

### Step 8: Access MinIO Console

Open your web browser and navigate to:
- **Console URL**: http://localhost:9001
- **Username**: admin
- **Password**: password123

**Console Features to Explore:**
- Dashboard overview
- Bucket management
- User management
- Monitoring metrics
- System settings

### Step 9: Verify MinIO API Endpoint

```bash
# Test MinIO API health endpoint
curl http://localhost:9000/minio/health/live

# Test MinIO API ready endpoint
curl http://localhost:9000/minio/health/ready
```

**Expected Response:**
```json
{"status":"ok"}
```

### Step 10: Examine Data Storage Structure

```bash
# Find where MinIO data is actually stored
kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export/

# Check MinIO's internal directory structure
kubectl exec -n minio-tenant minio-pool-0-0 -- find /export -type d -maxdepth 3
```

**MinIO Directory Structure:**
```
/export/
├── .minio.sys/          # MinIO system data
├── data1/               # First drive
├── data2/               # Second drive
├── data3/               # Third drive
└── data4/               # Fourth drive
```

## 🔍 Understanding the Deployment

### What the Operator Created

1. **StatefulSet**: `minio-pool-0` with 1 replica
2. **PVCs**: 4 PVCs per pod (data-0-minio-pool-0-0, data-1-minio-pool-0-0, etc.)
3. **PVs**: 4 automatically provisioned persistent volumes
4. **Services**: 
   - `minio` (API access)
   - `minio-tenant-console` (Web console)
   - `minio-hl` (Headless service)
5. **Console Deployment**: Web-based management interface

### Erasure Coding Configuration

With 4 volumes per server:
- **EC:2 Configuration**: Can tolerate 2 drive failures
- **Storage Efficiency**: ~50% (2 data + 2 parity)
- **Data Protection**: High redundancy for single-node setup

### Real-Time Provisioning Process

1. **Tenant Created**: Operator receives Tenant resource
2. **StatefulSet Created**: Operator creates StatefulSet with PVC templates
3. **PVCs Created**: StatefulSet controller creates PVCs (Pending state)
4. **Pod Scheduled**: Kubernetes schedules the MinIO pod
5. **PVs Provisioned**: Storage provisioner creates PVs when pod uses PVCs
6. **PVCs Bound**: PVCs transition from Pending to Bound
7. **MinIO Started**: Pod starts and MinIO initializes storage

## ✅ Validation Checklist

Before proceeding to Module 4, ensure:

- [ ] Tenant status shows "Initialized"
- [ ] All pods are Running (minio-pool-0-0, console pod)
- [ ] All PVCs are Bound
- [ ] PVs were automatically created
- [ ] Port forwarding works for both API (9000) and Console (9001)
- [ ] MinIO Console is accessible via web browser
- [ ] API health endpoints respond correctly

## 🚨 Common Issues & Solutions

### Issue: PVCs Stuck in Pending
```bash
# Check storage class exists and is default
kubectl get storageclass

# Check if provisioner is running
kubectl get pods -n local-path-storage
```

### Issue: Pods Not Starting
```bash
# Check pod events
kubectl describe pod minio-pool-0-0 -n minio-tenant

# Check node resources
kubectl describe nodes
```

### Issue: Port Forward Fails
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart port forwarding
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &
```

### Issue: Console Login Fails
```bash
# Verify secret was created correctly
kubectl get secret minio-creds-secret -n minio-tenant -o yaml

# Check console pod logs
kubectl logs -n minio-tenant deployment/minio-tenant-console
```

## 🔧 Advanced Configuration (Optional)

### Scaling the Tenant

```bash
# Scale to 2 servers (requires more resources)
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"pools":[{"servers":2,"name":"pool-0","volumesPerServer":4,"volumeClaimTemplate":{"metadata":{"name":"data"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"1Gi"}},"storageClassName":"local-path"}}}]}}'
```

### Custom Storage Configuration

```bash
# Use different storage class or size
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"pools":[{"volumeClaimTemplate":{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}}]}}'
```

## 📖 Additional Reading

- [MinIO Tenant Configuration](https://github.com/minio/operator/blob/master/docs/tenant_crd.adoc)
- [MinIO Erasure Coding](https://docs.min.io/minio/baremetal/concepts/erasure-coding.html)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## ➡️ Next Steps

Now that your MinIO Tenant is deployed and accessible:

```bash
cd ../04-basic-operations
cat README.md
```

---

**🎉 Outstanding!** You've successfully deployed a MinIO Tenant and observed the entire provisioning process in real-time. You now have a fully functional S3-compatible object storage system running in Kubernetes. In the next module, we'll learn how to interact with it using the MinIO client and perform basic operations.
