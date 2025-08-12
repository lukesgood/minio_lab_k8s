# MinIO Operator Workshop - Best Practices

## 🎯 Production Deployment Best Practices

This guide covers best practices for deploying and operating MinIO in production Kubernetes environments.

## 🏗️ Architecture and Planning

### Cluster Design

#### Multi-Node Deployment
```yaml
# Recommended: Distribute across multiple nodes
spec:
  pools:
  - servers: 4  # Minimum for production
    name: pool-0
    volumesPerServer: 4
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: v1.min.io/tenant
              operator: In
              values:
              - minio
          topologyKey: kubernetes.io/hostname
```

#### Resource Planning
```yaml
# Production resource allocation
resources:
  requests:
    memory: "8Gi"
    cpu: "4000m"
  limits:
    memory: "16Gi"
    cpu: "8000m"
```

### Storage Configuration

#### Storage Classes
```yaml
# Use high-performance storage for production
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-storage
provisioner: kubernetes.io/aws-ebs  # or your preferred provisioner
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain  # Important for data safety
```

#### Erasure Coding
- **EC:4**: Recommended for most production workloads (50% storage efficiency)
- **EC:6**: For higher durability requirements (33% storage efficiency)
- **EC:8**: Maximum protection (25% storage efficiency)

## 🔒 Security Best Practices

### Credentials Management

#### Use Kubernetes Secrets
```bash
# Never hardcode credentials
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-20)
export MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)" \
  -n minio-tenant
```

#### External Secret Management
```yaml
# Use external secret operators for production
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
```

### Network Security

#### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: minio-network-policy
  namespace: minio-tenant
spec:
  podSelector:
    matchLabels:
      v1.min.io/tenant: minio
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: allowed-namespace
    ports:
    - protocol: TCP
      port: 9000
```

#### TLS Configuration
```yaml
# Enable TLS for production
spec:
  requestAutoCert: true
  certConfig:
    commonName: "minio.example.com"
    organizationName: ["Your Organization"]
    dnsNames:
    - "minio.example.com"
    - "*.minio.example.com"
```

### Access Control

#### IAM Policies
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::production-data/department/${aws:username}/*"
      ]
    }
  ]
}
```

#### Service Accounts
```bash
# Use service accounts for application access
mc admin user svcacct add local app-user \
  --access-key "AKIA..." \
  --secret-key "..." \
  --policy app-policy
```

## 📊 Monitoring and Observability

### Prometheus Metrics

#### Enable Metrics Collection
```yaml
# In tenant spec
spec:
  prometheusOperator: true
  logging:
    anonymous: false
    json: true
    quiet: false
```

#### Key Metrics to Monitor
- `minio_cluster_capacity_usable_free_bytes`
- `minio_cluster_capacity_usable_total_bytes`
- `minio_s3_requests_total`
- `minio_s3_errors_total`
- `minio_cluster_nodes_offline_total`

### Logging

#### Structured Logging
```yaml
spec:
  logging:
    anonymous: false
    json: true
    quiet: false
  env:
  - name: MINIO_LOGGER_WEBHOOK_ENABLE
    value: "on"
  - name: MINIO_LOGGER_WEBHOOK_ENDPOINT
    value: "https://logging.example.com/webhook"
```

### Health Checks

#### Liveness and Readiness Probes
```yaml
# Automatically configured by operator, but can be customized
spec:
  liveness:
    httpGet:
      path: /minio/health/live
      port: 9000
    initialDelaySeconds: 10
    periodSeconds: 30
  readiness:
    httpGet:
      path: /minio/health/ready
      port: 9000
    initialDelaySeconds: 5
    periodSeconds: 10
```

## 🚀 Performance Optimization

### Resource Allocation

#### CPU and Memory
```yaml
# Scale based on workload
resources:
  requests:
    memory: "16Gi"  # 2GB per drive minimum
    cpu: "8000m"    # 2 cores per drive minimum
  limits:
    memory: "32Gi"
    cpu: "16000m"
```

#### Storage Performance
```bash
# Use high-performance storage
# NVMe SSD > SATA SSD > HDD
# Local storage > Network storage (when possible)
```

### Network Optimization

#### Service Configuration
```yaml
# Use headless service for direct pod access
apiVersion: v1
kind: Service
metadata:
  name: minio-headless
spec:
  clusterIP: None
  selector:
    v1.min.io/tenant: minio
  ports:
  - port: 9000
    name: minio
```

#### Load Balancing
```yaml
# Use appropriate load balancer for your environment
apiVersion: v1
kind: Service
metadata:
  name: minio-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    v1.min.io/tenant: minio
  ports:
  - port: 9000
    targetPort: 9000
```

## 🔄 Backup and Disaster Recovery

### Backup Strategies

#### Regular Backups
```bash
# Automated backup script
#!/bin/bash
BACKUP_BUCKET="backup-$(date +%Y%m%d)"
mc mb backup/$BACKUP_BUCKET
mc mirror production/data backup/$BACKUP_BUCKET/
```

#### Cross-Region Replication
```bash
# Set up replication to another region
mc replicate add production/data backup/replica \
  --priority 1 \
  --storage-class STANDARD
```

### Disaster Recovery

#### Multi-Site Setup
```yaml
# Deploy in multiple availability zones
spec:
  pools:
  - servers: 4
    name: pool-0
    volumesPerServer: 4
    nodeSelector:
      topology.kubernetes.io/zone: us-west-2a
  - servers: 4
    name: pool-1
    volumesPerServer: 4
    nodeSelector:
      topology.kubernetes.io/zone: us-west-2b
```

#### Backup Verification
```bash
# Regular backup integrity checks
mc admin heal production --recursive --dry-run
```

## 🔧 Operational Procedures

### Deployment

#### GitOps Approach
```yaml
# Use ArgoCD or Flux for deployment management
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio-tenant
spec:
  source:
    repoURL: https://github.com/your-org/minio-config
    path: production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: minio-tenant
```

#### Rolling Updates
```bash
# Use operator for safe updates
kubectl patch tenant minio -n minio-tenant \
  --type='merge' \
  -p='{"spec":{"image":"minio/minio:RELEASE.2025-04-08T15-41-24Z"}}'
```

### Maintenance

#### Regular Tasks
```bash
# Weekly maintenance checklist
# 1. Check cluster health
mc admin info production

# 2. Review storage usage
mc admin prometheus metrics production | grep capacity

# 3. Check for failed drives
mc admin heal production --dry-run

# 4. Review access logs
kubectl logs -n minio-tenant minio-pool-0-0 | grep ERROR

# 5. Update policies and users as needed
mc admin policy list production
```

#### Scaling Operations
```bash
# Scale tenant (add more servers)
kubectl patch tenant minio -n minio-tenant \
  --type='merge' \
  -p='{"spec":{"pools":[{"servers":8}]}}'

# Add new pool
kubectl patch tenant minio -n minio-tenant \
  --type='merge' \
  -p='{"spec":{"pools":[{"servers":4,"name":"pool-1","volumesPerServer":4}]}}'
```

## 📋 Compliance and Governance

### Data Governance

#### Lifecycle Policies
```json
{
  "Rules": [
    {
      "ID": "DeleteOldVersions",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "logs/"
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
```

#### Audit Logging
```yaml
spec:
  env:
  - name: MINIO_AUDIT_WEBHOOK_ENABLE
    value: "on"
  - name: MINIO_AUDIT_WEBHOOK_ENDPOINT
    value: "https://audit.example.com/webhook"
```

### Compliance

#### Encryption
```yaml
# Enable encryption at rest
spec:
  kes:
    image: minio/kes:latest
    replicas: 3
    configuration: |
      address: 0.0.0.0:7373
      root: disabled
      
      tls:
        key: /tmp/kes/server.key
        cert: /tmp/kes/server.crt
      
      policy:
        my-policy:
          allow:
          - /v1/key/create/my-key*
          - /v1/key/generate/my-key*
          - /v1/key/decrypt/my-key*
```

#### Data Retention
```bash
# Implement retention policies
mc retention set --default GOVERNANCE "30d" production/sensitive-data
```

## 🚨 Troubleshooting

### Common Production Issues

#### Split-Brain Prevention
```yaml
# Use proper quorum settings
spec:
  pools:
  - servers: 4  # Always use even numbers >= 4
    volumesPerServer: 4
```

#### Resource Monitoring
```bash
# Set up alerts for resource usage
# CPU > 80%
# Memory > 85%
# Storage > 90%
# Network errors > 1%
```

### Emergency Procedures

#### Data Recovery
```bash
# In case of data corruption
mc admin heal production --recursive --verbose

# Check healing status
mc admin heal production --status
```

#### Cluster Recovery
```bash
# If cluster is unresponsive
kubectl delete pod --all -n minio-tenant
# Operator will recreate pods automatically
```

## 📖 Additional Resources

### Documentation
- [MinIO Production Deployment Guide](https://docs.min.io/minio/baremetal/operations/installation.html)
- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
- [MinIO Security Guide](https://docs.min.io/minio/baremetal/security/)

### Tools and Integrations
- [MinIO Console](https://github.com/minio/console)
- [MinIO Client (mc)](https://docs.min.io/minio/baremetal/reference/minio-mc.html)
- [Prometheus Monitoring](https://docs.min.io/minio/baremetal/operations/monitoring.html)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/13502)

---

**💡 Remember**: These best practices should be adapted to your specific environment, compliance requirements, and operational procedures. Always test changes in a non-production environment first.
