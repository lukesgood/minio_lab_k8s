# MinIO Operator v2 Schema Update Guide

## 🎯 Overview

This document explains the schema changes in MinIO Operator v2 and how to update your Tenant configurations.

## 📋 Key Schema Changes

### 1. Credentials Configuration

**Old Schema (v1):**
```yaml
spec:
  credsSecret:
    name: minio-creds-secret
```

**New Schema (v2):**
```yaml
spec:
  configuration:
    name: minio-creds-secret
```

### 2. Console Configuration

**Old Schema (v1):**
```yaml
spec:
  console:
    image: minio/console:v1.5.0
    replicas: 1
    consoleSecret:
      name: minio-console-secret
```

**New Schema (v2):**
```yaml
spec:
  users:
  - name: storage-user
```

### 3. Required Features Section

**New in v2:**
```yaml
spec:
  features:
    bucketDNS: false
    domains: {}
```

## 🔧 Complete Updated Tenant Example

```yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  configuration:
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
  features:
    bucketDNS: false
    domains: {}
  users:
  - name: storage-user
```

## ⚠️ Common Errors

### Error: Unknown Field "spec.console"
```
Error from server (BadRequest): error when creating "STDIN": Tenant in version "v2" cannot be handled as a Tenant: strict decoding error: unknown field "spec.console"
```

**Solution:** Remove the `console` section and add `users` array instead.

### Error: Unknown Field "spec.credsSecret"
```
Error from server (BadRequest): error when creating "STDIN": Tenant in version "v2" cannot be handled as a Tenant: strict decoding error: unknown field "spec.credsSecret"
```

**Solution:** Replace `credsSecret` with `configuration`.

## 🔍 Verification Commands

```bash
# Check current CRD version
kubectl get crd tenants.minio.min.io -o jsonpath='{.spec.versions[*].name}'

# Explain current schema
kubectl explain tenant.spec --recursive

# Check specific fields
kubectl explain tenant.spec.configuration
kubectl explain tenant.spec.features
kubectl explain tenant.spec.users
```

## 📖 Migration Steps

1. **Update Tenant YAML files** with new schema
2. **Remove old console configurations**
3. **Add required features section**
4. **Add users array**
5. **Test deployment** with new schema

## 🎉 Benefits of v2 Schema

- **Simplified Configuration**: Cleaner, more intuitive field names
- **Better Validation**: Stricter schema validation
- **Enhanced Features**: New features section for advanced configurations
- **Improved User Management**: Simplified user configuration

---

**Note:** This schema update affects MinIO Operator v7.1.1+ installations. Always check your operator version before applying configurations.
