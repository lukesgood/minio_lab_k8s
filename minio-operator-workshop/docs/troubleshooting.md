# MinIO Operator Workshop - Troubleshooting Guide

## 🚨 Common Issues and Solutions

This guide covers the most common issues you might encounter during the workshop and their solutions.

## 📋 Quick Diagnostic Commands

Before diving into specific issues, run these commands to gather information:

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes

# Check MinIO operator status
kubectl get pods -n minio-operator
kubectl logs -n minio-operator deployment/minio-operator

# Check MinIO tenant status
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
kubectl get pvc -n minio-tenant
kubectl get pv

# Check services and networking
kubectl get svc -n minio-tenant
kubectl describe svc minio -n minio-tenant
```

## 🔧 Environment Setup Issues

### Issue: No Default Storage Class

**Symptoms:**
- PVCs stuck in Pending state
- Error: "no default storage class"

**Solution:**
```bash
# Install local-path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Set as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify
kubectl get storageclass
```

### Issue: Pods Cannot Schedule (Control-plane Taint)

**Symptoms:**
- Pods stuck in Pending state
- Error: "node(s) had taint that the pod didn't tolerate"

**Solution:**
```bash
# Remove control-plane taint (single-node clusters)
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# Verify nodes are schedulable
kubectl describe nodes | grep -i taint
```

### Issue: Insufficient Resources

**Symptoms:**
- Pods stuck in Pending state
- Error: "Insufficient cpu/memory"

**Solution:**
```bash
# Check node resources
kubectl describe nodes

# Check resource requests
kubectl describe pod <pod-name> -n <namespace>

# For development, reduce resource requirements or add more nodes
```

## 🏗️ Operator Installation Issues

### Issue: Operator Pods Not Starting

**Symptoms:**
- Operator pods in CrashLoopBackOff or Pending state
- Installation appears to hang

**Diagnosis:**
```bash
# Check operator pod status
kubectl get pods -n minio-operator

# Check pod events
kubectl describe pod <operator-pod-name> -n minio-operator

# Check operator logs
kubectl logs <operator-pod-name> -n minio-operator
```

**Solutions:**
```bash
# Reinstall operator
kubectl delete namespace minio-operator
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -

# Check for network policies blocking installation
kubectl get networkpolicies --all-namespaces

# Verify RBAC permissions
kubectl auth can-i create clusterroles
kubectl auth can-i create customresourcedefinitions
```

### Issue: CRDs Not Created

**Symptoms:**
- Error: "no matches for kind Tenant"
- CRDs missing from cluster

**Solution:**
```bash
# Check if CRDs exist
kubectl get crd | grep minio

# Reinstall operator (CRDs are included)
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -

# Verify CRDs are created
kubectl get crd tenants.minio.min.io
```

## 🏢 Tenant Deployment Issues

### Issue: Tenant Stuck in "Initializing" State

**Symptoms:**
- Tenant shows "Initializing" status for extended period
- MinIO pods not starting

**Diagnosis:**
```bash
# Check tenant status
kubectl describe tenant minio -n minio-tenant

# Check StatefulSet status
kubectl describe statefulset minio-pool-0 -n minio-tenant

# Check pod events
kubectl describe pod minio-pool-0-0 -n minio-tenant
```

**Solutions:**
```bash
# Check PVC status
kubectl get pvc -n minio-tenant

# If PVCs are Pending, check storage class
kubectl get storageclass

# Check for resource constraints
kubectl describe nodes

# Verify secret exists and is correct
kubectl get secret minio-creds-secret -n minio-tenant -o yaml
```

### Issue: PVCs Stuck in Pending State

**Symptoms:**
- PVCs show "Pending" status
- Pods cannot start due to volume mounting issues

**Diagnosis:**
```bash
# Check PVC status and events
kubectl describe pvc <pvc-name> -n minio-tenant

# Check storage class configuration
kubectl describe storageclass <storage-class-name>

# Check provisioner status
kubectl get pods -n local-path-storage  # for local-path provisioner
```

**Solutions:**
```bash
# For WaitForFirstConsumer binding mode (normal behavior)
# PVCs will remain Pending until Pod is scheduled

# If using local-path provisioner, ensure it's running
kubectl get pods -n local-path-storage

# Check node storage capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Verify storage class exists and is accessible
kubectl get storageclass
```

### Issue: MinIO Pods CrashLoopBackOff

**Symptoms:**
- MinIO pods repeatedly crashing
- Pods show CrashLoopBackOff status

**Diagnosis:**
```bash
# Check pod logs
kubectl logs minio-pool-0-0 -n minio-tenant

# Check previous container logs
kubectl logs minio-pool-0-0 -n minio-tenant --previous

# Check pod events
kubectl describe pod minio-pool-0-0 -n minio-tenant
```

**Common Solutions:**
```bash
# Check secret format (common issue with v5.x operator)
kubectl get secret minio-creds-secret -n minio-tenant -o yaml

# Recreate secret with correct format
kubectl delete secret minio-creds-secret -n minio-tenant
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant

# Check storage permissions
kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export

# Verify erasure coding configuration
# Ensure volumes per server matches MinIO requirements
```

## 🌐 Networking and Access Issues

### Issue: Cannot Access MinIO Console/API

**Symptoms:**
- Port forwarding fails
- Connection refused errors
- Timeouts when accessing MinIO

**Diagnosis:**
```bash
# Check services
kubectl get svc -n minio-tenant

# Check service endpoints
kubectl get endpoints -n minio-tenant

# Check if pods are ready
kubectl get pods -n minio-tenant
```

**Solutions:**
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart port forwarding
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &

# Test service connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://minio.minio-tenant.svc.cluster.local/minio/health/live

# Check for network policies
kubectl get networkpolicies -n minio-tenant
```

### Issue: MinIO Client Connection Fails

**Symptoms:**
- mc commands fail with connection errors
- Authentication failures

**Diagnosis:**
```bash
# Test basic connectivity
curl -I http://localhost:9000/minio/health/live

# Check mc configuration
mc alias list

# Test with verbose output
mc --debug ls local
```

**Solutions:**
```bash
# Reconfigure mc alias
mc alias set local http://localhost:9000 admin password123

# Verify credentials match secret
kubectl get secret minio-creds-secret -n minio-tenant -o jsonpath='{.data.config\.env}' | base64 -d

# Check port forwarding is active
ps aux | grep "kubectl port-forward"
```

## 💾 Storage and Data Issues

### Issue: Data Not Persisting

**Symptoms:**
- Data disappears after pod restart
- Objects uploaded but not found later

**Diagnosis:**
```bash
# Check PV reclaim policy
kubectl get pv -o wide

# Check if PVCs are bound
kubectl get pvc -n minio-tenant

# Verify data exists on storage backend
kubectl exec -n minio-tenant minio-pool-0-0 -- find /export -name "*.txt" -o -name "*.dat"
```

**Solutions:**
```bash
# Ensure PVs have Retain reclaim policy for production
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# Check storage class reclaim policy
kubectl describe storageclass <storage-class-name>

# Verify MinIO is using correct storage paths
kubectl exec -n minio-tenant minio-pool-0-0 -- ls -la /export/
```

### Issue: Storage Full or Performance Issues

**Symptoms:**
- Upload failures
- Slow performance
- Out of space errors

**Diagnosis:**
```bash
# Check storage usage
kubectl exec -n minio-tenant minio-pool-0-0 -- df -h /export

# Check PV sizes
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage

# Monitor I/O performance
kubectl exec -n minio-tenant minio-pool-0-0 -- iostat -x 1 3
```

**Solutions:**
```bash
# Increase PVC size (if storage class supports expansion)
kubectl patch pvc data-0-minio-pool-0-0 -n minio-tenant -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Check storage class allows volume expansion
kubectl describe storageclass <storage-class-name> | grep AllowVolumeExpansion

# For local-path, ensure host has sufficient space
df -h /opt/local-path-provisioner/
```

## 🔐 Security and Permission Issues

### Issue: IAM User Cannot Access Resources

**Symptoms:**
- Access denied errors for valid users
- Policies not taking effect

**Diagnosis:**
```bash
# Check user status
mc admin user info local <username>

# Check policy attachment
mc admin user info local <username> | grep -i policy

# Verify policy content
mc admin policy info local <policy-name>
```

**Solutions:**
```bash
# Re-attach policy
mc admin policy detach local <policy-name> --user <username>
mc admin policy attach local <policy-name> --user <username>

# Check policy JSON syntax
cat policy.json | jq .

# Verify resource ARNs match actual bucket names
mc ls local
```

### Issue: Console Login Fails

**Symptoms:**
- Cannot login to MinIO Console
- Invalid credentials error

**Solutions:**
```bash
# Check console service
kubectl get svc minio-tenant-console -n minio-tenant

# Verify console pod is running
kubectl get pods -n minio-tenant | grep console

# Check console logs
kubectl logs -n minio-tenant deployment/minio-tenant-console

# Verify secret is correctly formatted
kubectl get secret minio-creds-secret -n minio-tenant -o yaml
```

## 🔄 Performance Issues

### Issue: Slow Upload/Download Performance

**Symptoms:**
- Transfers much slower than expected
- Timeouts during large file operations

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n minio-tenant

# Check storage backend performance
kubectl exec -n minio-tenant minio-pool-0-0 -- dd if=/dev/zero of=/tmp/test bs=1M count=100

# Run MinIO speedtest
mc admin speedtest local
```

**Solutions:**
```bash
# Increase resource limits
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"pools":[{"resources":{"requests":{"memory":"2Gi","cpu":"1000m"},"limits":{"memory":"4Gi","cpu":"2000m"}}}]}}'

# Use faster storage class if available
# Optimize network configuration
# Consider multi-node deployment for better performance
```

## 🧹 Cleanup and Reset

### Complete Environment Reset

If you need to start over completely:

```bash
# Delete tenant
kubectl delete tenant minio -n minio-tenant

# Delete namespace (this will delete all resources)
kubectl delete namespace minio-tenant

# Delete operator
kubectl delete namespace minio-operator

# Delete PVs (if using Retain policy)
kubectl delete pv $(kubectl get pv -o jsonpath='{.items[*].metadata.name}')

# Reinstall everything
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
kubectl create namespace minio-tenant
# ... continue with tenant creation
```

### Partial Cleanup

To reset just the tenant:

```bash
# Delete tenant (keeps operator)
kubectl delete tenant minio -n minio-tenant

# Delete PVCs (will delete data)
kubectl delete pvc --all -n minio-tenant

# Recreate tenant
# ... follow tenant creation steps
```

## 📞 Getting Help

### Useful Commands for Support

When asking for help, provide this information:

```bash
# Environment information
kubectl version
kubectl get nodes
kubectl get storageclass

# MinIO specific information
kubectl get pods -n minio-operator
kubectl get pods -n minio-tenant
kubectl get tenant -n minio-tenant
kubectl describe tenant minio -n minio-tenant

# Logs
kubectl logs -n minio-operator deployment/minio-operator
kubectl logs -n minio-tenant minio-pool-0-0
```

### Community Resources

- [MinIO Slack Community](https://slack.min.io/)
- [MinIO GitHub Issues](https://github.com/minio/operator/issues)
- [MinIO Documentation](https://docs.min.io/)
- [Kubernetes Community](https://kubernetes.io/community/)

---

**💡 Pro Tip**: Most issues in this workshop are related to storage configuration or resource constraints. Always check storage classes, PVC status, and node resources first when troubleshooting deployment issues.
