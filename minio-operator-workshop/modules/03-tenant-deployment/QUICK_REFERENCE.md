# Module 3: Quick Reference Guide

## 🚀 Quick Start (Automated)

```bash
# Deploy tenant automatically
./deploy-tenant.sh

# Test the deployment
./test-tenant.sh

# Clean up when done
./cleanup-tenant.sh
```

## 📋 Manual Commands

### Deploy Tenant
```bash
# 1. Create namespace
kubectl create namespace minio-workshop

# 2. Create credentials
kubectl create secret generic minio-workshop-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=\"admin\"
export MINIO_ROOT_PASSWORD=\"workshop123\"" \
  -n minio-workshop

# 3. Apply tenant configuration
kubectl apply -f minio-workshop-tenant.yaml
```

### Monitor Deployment
```bash
# Watch tenant status
kubectl get tenant minio-workshop -n minio-workshop -w

# Watch pods
kubectl get pods -n minio-workshop -w

# Watch PVCs
kubectl get pvc -n minio-workshop -w
```

### Access MinIO
```bash
# Console (Web UI)
kubectl port-forward svc/minio-workshop-console -n minio-workshop 9090:9090
# Open: http://localhost:9090

# API
kubectl port-forward svc/minio-workshop-hl -n minio-workshop 9000:9000
# Use: http://localhost:9000
```

### Credentials
- **Username**: `admin`
- **Password**: `workshop123`

## 🔍 Troubleshooting Commands

```bash
# Check tenant status
kubectl describe tenant minio-workshop -n minio-workshop

# Check pod logs
kubectl logs -n minio-workshop minio-workshop-pool-0-0 -c minio

# Check operator logs
kubectl logs -n minio-operator deployment/minio-operator

# Check events
kubectl get events -n minio-workshop --sort-by='.lastTimestamp'
```

## 📊 Expected Results

### Healthy Tenant
```bash
$ kubectl get tenant minio-workshop -n minio-workshop
NAME             STATE         HEALTH   AGE
minio-workshop   Provisioned   green    5m
```

### Running Pods
```bash
$ kubectl get pods -n minio-workshop
NAME                        READY   STATUS    RESTARTS   AGE
minio-workshop-pool-0-0     2/2     Running   0          5m
minio-workshop-pool-0-1     2/2     Running   0          5m
minio-workshop-pool-0-2     2/2     Running   0          5m
minio-workshop-pool-0-3     2/2     Running   0          5m
```

### Bound PVCs
```bash
$ kubectl get pvc -n minio-workshop
NAME                               STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS
data0-minio-workshop-pool-0-0      Bound    pvc-xxx     2Gi        RWO            local-path
data1-minio-workshop-pool-0-0      Bound    pvc-xxx     2Gi        RWO            local-path
# ... (8 total PVCs)
```

## 🧹 Cleanup

```bash
# Automated cleanup
./cleanup-tenant.sh

# Manual cleanup
kubectl delete tenant minio-workshop -n minio-workshop
kubectl delete pvc -n minio-workshop --all
kubectl delete namespace minio-workshop
```

## 📁 Files in this Module

- `README.md` - Complete step-by-step guide
- `deploy-tenant.sh` - Automated deployment script
- `test-tenant.sh` - Verification and testing script
- `cleanup-tenant.sh` - Cleanup script
- `QUICK_REFERENCE.md` - This quick reference guide

## ⏱️ Time Estimates

- **Automated deployment**: 5-10 minutes
- **Manual deployment**: 15-20 minutes
- **Testing and verification**: 5 minutes
- **Total module time**: 20-35 minutes
