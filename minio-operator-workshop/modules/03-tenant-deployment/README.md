# Module 3: MinIO Tenant Deployment

## 🎯 Learning Objectives

By the end of this module, you will:
- Deploy a MinIO tenant using the official operator
- Understand tenant configuration options
- Verify tenant deployment and health
- Access the MinIO console and API
- Troubleshoot common deployment issues

## 📋 Prerequisites

- Module 1 (Environment Setup) completed
- Module 2 (Operator Installation) completed
- MinIO Operator running in `minio-operator` namespace

## 🚀 Step 1: Verify Operator Status

Before deploying a tenant, ensure the operator is running:

```bash
# Check operator status
kubectl get pods -n minio-operator

# Verify operator is ready
kubectl wait --for=condition=available deployment/minio-operator -n minio-operator --timeout=300s

# Check operator version
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected output:
```
NAME                              READY   STATUS    RESTARTS   AGE
minio-operator-69fd675557-xxxxx   1/1     Running   0          10m
```

## 🏗️ Step 2: Create Tenant Namespace

Create a dedicated namespace for your MinIO tenant:

```bash
# Create namespace for the tenant
kubectl create namespace minio-workshop

# Verify namespace creation
kubectl get namespace minio-workshop
```

## 🔐 Step 3: Create Tenant Credentials

MinIO requires root credentials to initialize. Create a secret with the credentials:

```bash
# Create credentials secret
kubectl create secret generic minio-workshop-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=\"admin\"
export MINIO_ROOT_PASSWORD=\"workshop123\"" \
  -n minio-workshop

# Verify secret creation
kubectl get secret minio-workshop-secret -n minio-workshop
```

## 📄 Step 4: Download and Customize Tenant Configuration

Download the official tenant configuration:

```bash
# Download the official tenant-lite example
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-lite/tenant.yaml

# View the configuration
cat tenant.yaml
```

Create a customized version for the workshop:

```bash
# Create workshop-specific tenant configuration
cat > minio-workshop-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-workshop
  namespace: minio-workshop
spec:
  ## Specification for MinIO Pool(s) in this Tenant.
  pools:
    ## Servers specifies the number of MinIO Tenant Pods / Servers in this pool.
    ## For standalone mode, supply 1. For distributed mode, supply 4 or more.
    - servers: 4
      ## custom pool name
      name: pool-0
      ## volumesPerServer specifies the number of volumes attached per MinIO Tenant Pod / Server.
      volumesPerServer: 2
      ## This VolumeClaimTemplate is used across all the volumes provisioned for MinIO Tenant in this Pool.
      volumeClaimTemplate:
        metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
      ## Configure security context for MinIO pods
      containerSecurityContext:
        runAsUser: 1000
        runAsGroup: 1000
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault
  ## Configuration for MinIO Tenant
  configuration:
    name: minio-workshop-secret
  ## Enable MinIO Console
  console:
    image: quay.io/minio/console:v1.6.0
    replicas: 1
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
      seccompProfile:
        type: RuntimeDefault
EOF
```

## 🚀 Step 5: Deploy the MinIO Tenant

Deploy the tenant using the customized configuration:

```bash
# Apply the tenant configuration
kubectl apply -f minio-workshop-tenant.yaml

# Verify tenant creation
kubectl get tenant -n minio-workshop
```

Expected output:
```
NAME             STATE         HEALTH   AGE
minio-workshop   Provisioned   green    30s
```

## 📊 Step 6: Monitor Deployment Progress

Watch the deployment progress:

```bash
# Watch tenant status
kubectl get tenant minio-workshop -n minio-workshop -w

# In another terminal, watch PVC creation
kubectl get pvc -n minio-workshop -w

# In another terminal, watch pod creation
kubectl get pods -n minio-workshop -w
```

Wait for all components to be ready. This may take 2-5 minutes.

## ✅ Step 7: Verify Deployment

Check that all components are running:

```bash
# Check tenant status
kubectl get tenant minio-workshop -n minio-workshop

# Check all pods are running
kubectl get pods -n minio-workshop

# Check PVCs are bound
kubectl get pvc -n minio-workshop

# Check services
kubectl get svc -n minio-workshop
```

Expected healthy output:
```bash
# Tenant should show "Provisioned" and "green"
NAME             STATE         HEALTH   AGE
minio-workshop   Provisioned   green    5m

# All pods should be Running
NAME                        READY   STATUS    RESTARTS   AGE
minio-workshop-pool-0-0     2/2     Running   0          5m
minio-workshop-pool-0-1     2/2     Running   0          5m
minio-workshop-pool-0-2     2/2     Running   0          5m
minio-workshop-pool-0-3     2/2     Running   0          5m

# All PVCs should be Bound
NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
data0-minio-workshop-pool-0-0      Bound    pvc-xxx-xxx-xxx                           2Gi        RWO            local-path
data1-minio-workshop-pool-0-0      Bound    pvc-xxx-xxx-xxx                           2Gi        RWO            local-path
...
```

## 🌐 Step 8: Access MinIO Console

Set up port forwarding to access the MinIO console:

```bash
# Port forward to MinIO console
kubectl port-forward svc/minio-workshop-console -n minio-workshop 9090:9090 &

# Open browser to http://localhost:9090
echo "MinIO Console: http://localhost:9090"
echo "Username: admin"
echo "Password: workshop123"
```

## 🔧 Step 9: Access MinIO API

Set up port forwarding for the MinIO API:

```bash
# Port forward to MinIO API
kubectl port-forward svc/minio-workshop-hl -n minio-workshop 9000:9000 &

# Test API access
curl -I http://localhost:9000/minio/health/live
```

## 🧪 Step 10: Basic Functionality Test

Test basic MinIO operations:

```bash
# Install MinIO client (if not already installed)
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# Configure MinIO client
mc alias set workshop http://localhost:9000 admin workshop123

# Test connection
mc admin info workshop

# Create a test bucket
mc mb workshop/test-bucket

# List buckets
mc ls workshop
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. Tenant Stuck in "Initializing" State

```bash
# Check operator logs
kubectl logs -n minio-operator deployment/minio-operator

# Check tenant events
kubectl describe tenant minio-workshop -n minio-workshop

# Common fix: Ensure credentials secret exists
kubectl get secret minio-workshop-secret -n minio-workshop
```

#### 2. PVCs Stuck in "Pending" State

```bash
# Check storage class
kubectl get storageclass

# Check PVC events
kubectl describe pvc -n minio-workshop

# For local development, ensure local-path provisioner is running
kubectl get pods -n local-path-storage
```

#### 3. Pods Not Starting

```bash
# Check pod logs
kubectl logs -n minio-workshop minio-workshop-pool-0-0 -c minio

# Check pod events
kubectl describe pod -n minio-workshop minio-workshop-pool-0-0

# Check resource constraints
kubectl top nodes
kubectl top pods -n minio-workshop
```

#### 4. Console Not Accessible

```bash
# Check console service
kubectl get svc -n minio-workshop | grep console

# Check console pod
kubectl get pods -n minio-workshop | grep console

# Restart port-forward
pkill -f "kubectl port-forward.*9090"
kubectl port-forward svc/minio-workshop-console -n minio-workshop 9090:9090
```

### Emergency Reset

If you need to start over:

```bash
# Delete the tenant (this will delete all data!)
kubectl delete tenant minio-workshop -n minio-workshop

# Delete PVCs (if they don't auto-delete)
kubectl delete pvc -n minio-workshop --all

# Delete the namespace
kubectl delete namespace minio-workshop

# Start over from Step 2
```

## 📋 Verification Checklist

- [ ] MinIO Operator is running
- [ ] Tenant namespace created
- [ ] Credentials secret created
- [ ] Tenant configuration applied
- [ ] Tenant shows "Provisioned" and "green" status
- [ ] All pods are "Running" (2/2 ready)
- [ ] All PVCs are "Bound"
- [ ] Console accessible at http://localhost:9090
- [ ] API accessible at http://localhost:9000
- [ ] MinIO client can connect and create buckets

## 🎯 Success Criteria

Your MinIO tenant deployment is successful when:

1. **Tenant Status**: Shows `Provisioned` state and `green` health
2. **Pod Status**: All 4 MinIO pods are `Running` with `2/2` containers ready
3. **Storage**: All 8 PVCs (2 per pod) are `Bound` to persistent volumes
4. **Console Access**: Can login to console with admin/workshop123
5. **API Access**: Can connect with MinIO client and perform operations
6. **Basic Operations**: Can create buckets and upload/download objects

## 📚 Key Concepts Learned

- **Tenant**: A MinIO deployment managed by the operator
- **Pool**: A group of MinIO servers with shared configuration
- **Distributed Mode**: 4+ servers for high availability and performance
- **PVC Template**: Defines storage requirements for each MinIO server
- **Security Context**: Ensures pods run with proper security constraints
- **Console**: Web-based management interface for MinIO

## ➡️ Next Steps

Once your tenant is successfully deployed and verified:
- Proceed to [Module 4: Basic Operations & Client Setup](../04-basic-operations/)
- Explore the MinIO console interface
- Practice basic S3 operations using the MinIO client

## 📖 Additional Resources

- [MinIO Operator Tenant Configuration](https://docs.min.io/minio/k8s/tenant-management/deploy-minio-tenant.html)
- [MinIO Console Documentation](https://docs.min.io/minio/baremetal/console/minio-console.html)
- [MinIO Client (mc) Documentation](https://docs.min.io/minio/baremetal/reference/minio-mc.html)

---

**🎉 Congratulations!** You have successfully deployed a MinIO tenant using the MinIO Operator. Your object storage system is now ready for use!
