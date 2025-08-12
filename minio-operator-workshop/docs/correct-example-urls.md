# Correct MinIO Operator Example URLs

## ⚠️ Important Notice

The MinIO Operator repository has restructured its examples directory. Many online tutorials and documentation still reference the old URLs that no longer exist.

## ❌ Old URLs (404 Not Found)

These URLs **DO NOT WORK** and will return "404: Not Found":

```bash
# ❌ BROKEN - DO NOT USE
https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml
https://raw.githubusercontent.com/minio/operator/master/examples/tenant-tiny.yaml
https://raw.githubusercontent.com/minio/operator/master/examples/tenant.yaml
```

## ✅ Correct URLs (Working)

Use these updated URLs instead:

### Tenant Lite (4 servers, distributed mode)
```bash
# Download tenant-lite configuration
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-lite/tenant.yaml

# Direct kubectl apply
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-lite/tenant.yaml
```

### Tenant Tiny (1 server, standalone mode)
```bash
# Download tenant-tiny configuration
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-tiny/tenant.yaml

# Direct kubectl apply
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-tiny/tenant.yaml
```

### Other Available Examples

The MinIO Operator provides many other example configurations:

```bash
# Tenant with cert-manager
https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-certmanager/tenant.yaml

# Tenant with KES encryption
https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-kes-encryption/tenant.yaml

# Tenant with external OIDC
https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-external-idp-oidc/tenant.yaml

# Tenant with LDAP
https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-external-idp-ldap/tenant.yaml
```

## 📁 Repository Structure

The current structure in the MinIO Operator repository is:

```
examples/
├── kustomization/
│   ├── tenant-lite/
│   │   ├── tenant.yaml
│   │   └── kustomization.yaml
│   ├── tenant-tiny/
│   │   ├── tenant.yaml
│   │   └── kustomization.yaml
│   ├── tenant-certmanager/
│   ├── tenant-kes-encryption/
│   └── ... (other examples)
└── vault/
```

## 🔄 Migration Guide

If you're updating existing scripts or documentation:

1. **Replace old URLs** with the new kustomization paths
2. **Update filenames** - the downloaded file will be named `tenant.yaml`
3. **Test the URLs** before deploying to ensure they work

## 📝 Example Script Update

### Before (Broken)
```bash
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/tenant-lite.yaml
kubectl apply -f tenant-lite.yaml
```

### After (Working)
```bash
curl -O https://raw.githubusercontent.com/minio/operator/master/examples/kustomization/tenant-lite/tenant.yaml
kubectl apply -f tenant.yaml
```

## 🔗 References

- [MinIO Operator GitHub Repository](https://github.com/minio/operator)
- [Official MinIO Operator Documentation](https://docs.min.io/minio/k8s/)
- [MinIO Operator Examples Directory](https://github.com/minio/operator/tree/master/examples/kustomization)
