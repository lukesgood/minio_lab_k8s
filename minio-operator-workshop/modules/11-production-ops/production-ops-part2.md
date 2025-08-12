### Step 8: Automated Operations with GitOps

```bash
# Create GitOps configuration for MinIO
mkdir -p gitops/{base,overlays/production,overlays/staging}

# Base configuration
cat << EOF > gitops/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- tenant.yaml
- secrets.yaml

commonLabels:
  app: minio
  managed-by: gitops
EOF

cat << EOF > gitops/base/tenant.yaml
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
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
EOF

# Production overlay
cat << EOF > gitops/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patchesStrategicMerge:
- production-patches.yaml

commonLabels:
  environment: production
EOF

cat << EOF > gitops/overlays/production/production-patches.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio
  namespace: minio-tenant
spec:
  pools:
  - servers: 4  # Production scale
    volumesPerServer: 4
    volumeClaimTemplate:
      spec:
        resources:
          requests:
            storage: 100Gi  # Production storage
  resources:
    requests:
      memory: "8Gi"
      cpu: "4000m"
    limits:
      memory: "16Gi"
      cpu: "8000m"
  prometheusOperator: true
  logging:
    json: true
    quiet: false
EOF

echo "GitOps configuration created"
echo "To deploy: kubectl apply -k gitops/overlays/production/"
```

### Step 9: Performance Optimization

```bash
# Create performance optimization script
cat << 'EOF' > performance-optimization.sh
#!/bin/bash

echo "=== MinIO Performance Optimization ==="
echo ""

# 1. Resource Optimization
echo "1. Current Resource Usage:"
kubectl top pods -n minio-tenant

echo ""
echo "2. Resource Recommendations:"

# Get current resource requests/limits
current_memory=$(kubectl get statefulset minio-pool-0 -n minio-tenant -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
current_cpu=$(kubectl get statefulset minio-pool-0 -n minio-tenant -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')

echo "   Current Memory Request: $current_memory"
echo "   Current CPU Request: $current_cpu"

# Performance tuning recommendations
echo ""
echo "3. Performance Tuning Recommendations:"
echo "   Memory: 2GB per drive minimum (current: 4 drives = 8GB recommended)"
echo "   CPU: 2 cores per drive minimum (current: 4 drives = 8 cores recommended)"
echo "   Network: 10GbE recommended for production"
echo "   Storage: NVMe SSD for best performance"

# 4. Erasure Coding Optimization
echo ""
echo "4. Erasure Coding Analysis:"
servers=$(kubectl get tenant minio -n minio-tenant -o jsonpath='{.spec.pools[0].servers}')
volumes=$(kubectl get tenant minio -n minio-tenant -o jsonpath='{.spec.pools[0].volumesPerServer}')
total_drives=$((servers * volumes))

echo "   Current Configuration: $servers servers × $volumes volumes = $total_drives drives"

if [ $total_drives -eq 4 ]; then
    echo "   Erasure Coding: EC:2 (50% storage efficiency, 2 drive failure tolerance)"
elif [ $total_drives -eq 8 ]; then
    echo "   Erasure Coding: EC:4 (50% storage efficiency, 4 drive failure tolerance)"
elif [ $total_drives -eq 16 ]; then
    echo "   Erasure Coding: EC:8 (50% storage efficiency, 8 drive failure tolerance)"
else
    echo "   Erasure Coding: Custom configuration"
fi

# 5. Performance Testing
echo ""
echo "5. Running Performance Test:"
mc admin speedtest local --duration=30s

# 6. Optimization Commands
echo ""
echo "6. Optimization Commands:"
echo ""
echo "   Increase Memory:"
echo "   kubectl patch tenant minio -n minio-tenant --type='merge' -p='{\"spec\":{\"pools\":[{\"resources\":{\"requests\":{\"memory\":\"8Gi\"},\"limits\":{\"memory\":\"16Gi\"}}}]}}'"
echo ""
echo "   Increase CPU:"
echo "   kubectl patch tenant minio -n minio-tenant --type='merge' -p='{\"spec\":{\"pools\":[{\"resources\":{\"requests\":{\"cpu\":\"4000m\"},\"limits\":{\"cpu\":\"8000m\"}}}]}}'"
echo ""
echo "   Scale Horizontally:"
echo "   kubectl patch tenant minio -n minio-tenant --type='merge' -p='{\"spec\":{\"pools\":[{\"servers\":2}]}}'"

EOF

chmod +x performance-optimization.sh

# Run performance optimization analysis
./performance-optimization.sh
```

### Step 10: Disaster Recovery Automation

```bash
# Create disaster recovery automation
cat << 'EOF' > disaster-recovery.sh
#!/bin/bash

DR_ACTION=${1:-"status"}

case $DR_ACTION in
    "status")
        echo "=== Disaster Recovery Status ==="
        echo ""
        
        echo "1. Primary Site Status:"
        if mc admin info local >/dev/null 2>&1; then
            echo "   ✅ Primary site operational"
            mc admin info local | head -5
        else
            echo "   ❌ Primary site not accessible"
        fi
        
        echo ""
        echo "2. Backup Site Status:"
        if mc admin info backup >/dev/null 2>&1; then
            echo "   ✅ Backup site operational"
            mc admin info backup | head -5
        else
            echo "   ❌ Backup site not accessible"
        fi
        
        echo ""
        echo "3. Latest Backup:"
        latest_backup=$(mc ls backup/production-backup/ | tail -1 | awk '{print $1, $2, $5}')
        echo "   $latest_backup"
        
        echo ""
        echo "4. Replication Status:"
        # In production, check replication status
        echo "   Check replication lag and status"
        ;;
        
    "failover")
        echo "=== Initiating Failover to Backup Site ==="
        echo ""
        
        # 1. Verify backup site is ready
        if ! mc admin info backup >/dev/null 2>&1; then
            echo "❌ Backup site not accessible. Cannot failover."
            exit 1
        fi
        
        # 2. Update DNS/Load Balancer (simulated)
        echo "1. Updating DNS to point to backup site..."
        echo "   (In production: update DNS records or load balancer)"
        
        # 3. Verify data consistency
        echo "2. Verifying data consistency..."
        echo "   (In production: run data consistency checks)"
        
        # 4. Start services on backup site
        echo "3. Starting services on backup site..."
        echo "   Services already running on backup site"
        
        echo ""
        echo "✅ Failover completed. Monitor backup site closely."
        ;;
        
    "failback")
        echo "=== Initiating Failback to Primary Site ==="
        echo ""
        
        # 1. Verify primary site is ready
        if ! mc admin info local >/dev/null 2>&1; then
            echo "❌ Primary site not ready. Cannot failback."
            exit 1
        fi
        
        # 2. Sync data from backup to primary
        echo "1. Syncing data from backup to primary..."
        echo "   mc mirror backup/production-data local/production-data"
        
        # 3. Update DNS/Load Balancer back to primary
        echo "2. Updating DNS to point back to primary site..."
        echo "   (In production: update DNS records or load balancer)"
        
        echo ""
        echo "✅ Failback completed. Primary site restored."
        ;;
        
    "test")
        echo "=== Disaster Recovery Test ==="
        echo ""
        
        # Create test data
        echo "1. Creating test data..."
        echo "DR Test $(date)" > dr-test.txt
        mc cp dr-test.txt local/test-bucket/
        
        # Backup test data
        echo "2. Backing up test data..."
        mc mirror local/test-bucket backup/dr-test-bucket
        
        # Simulate disaster (remove from primary)
        echo "3. Simulating disaster (removing from primary)..."
        mc rm local/test-bucket/dr-test.txt
        
        # Restore from backup
        echo "4. Restoring from backup..."
        mc cp backup/dr-test-bucket/dr-test.txt local/test-bucket/
        
        # Verify restoration
        if mc stat local/test-bucket/dr-test.txt >/dev/null 2>&1; then
            echo "5. ✅ DR test successful - data restored"
        else
            echo "5. ❌ DR test failed - data not restored"
        fi
        
        # Cleanup
        rm -f dr-test.txt
        mc rm local/test-bucket/dr-test.txt 2>/dev/null
        mc rm --recursive --force backup/dr-test-bucket 2>/dev/null
        ;;
        
    *)
        echo "Usage: $0 {status|failover|failback|test}"
        echo ""
        echo "  status   - Check DR status"
        echo "  failover - Failover to backup site"
        echo "  failback - Failback to primary site"
        echo "  test     - Run DR test"
        exit 1
        ;;
esac
EOF

chmod +x disaster-recovery.sh

# Test disaster recovery status
./disaster-recovery.sh status
```

## 🔍 Understanding Production Operations

### Operational Maturity Levels

#### Level 1: Basic Operations
- Manual processes
- Reactive monitoring
- Basic backup procedures

#### Level 2: Improved Operations
- Some automation
- Proactive monitoring
- Documented procedures

#### Level 3: Advanced Operations
- Extensive automation
- Predictive monitoring
- Self-healing systems

#### Level 4: Optimized Operations
- Full automation
- AI-driven operations
- Continuous optimization

### Key Performance Indicators (KPIs)

#### Availability Metrics
- **Uptime**: 99.9% target
- **MTTR**: Mean Time To Recovery
- **MTBF**: Mean Time Between Failures

#### Performance Metrics
- **Response Time**: < 100ms for API calls
- **Throughput**: MB/s for data operations
- **Error Rate**: < 0.1% of requests

#### Operational Metrics
- **Deployment Frequency**: Weekly releases
- **Change Failure Rate**: < 5%
- **Recovery Time**: < 1 hour for P1 incidents

## ✅ Validation Checklist

Ensure you have completed:

- [ ] Capacity monitoring and planning procedures
- [ ] Scaling operations (horizontal and vertical)
- [ ] Automated maintenance procedures
- [ ] Update and upgrade procedures
- [ ] Comprehensive health checks
- [ ] Incident response procedures
- [ ] Operational runbooks created
- [ ] GitOps configuration implemented
- [ ] Performance optimization analysis
- [ ] Disaster recovery automation

## 🚨 Common Operational Issues

### Issue: Capacity Planning Failures

```bash
# Implement automated capacity alerts
# Set up monitoring for 80% usage threshold
# Plan expansion at 70% usage
```

### Issue: Update Failures

```bash
# Always backup before updates
# Test updates in staging first
# Have rollback procedures ready
# Monitor closely during updates
```

### Issue: Performance Degradation

```bash
# Regular performance baselines
# Monitor resource usage trends
# Implement automated scaling
# Optimize based on usage patterns
```

## 📊 Production Operations Best Practices

### Automation
- Automate repetitive tasks
- Use Infrastructure as Code
- Implement CI/CD pipelines
- Self-healing systems

### Monitoring
- Comprehensive observability
- Proactive alerting
- Performance baselines
- Capacity planning

### Documentation
- Keep runbooks updated
- Document all procedures
- Maintain contact lists
- Regular training

### Testing
- Regular DR tests
- Performance testing
- Security assessments
- Chaos engineering

## 📖 Additional Reading

- [Site Reliability Engineering](https://sre.google/books/)
- [The DevOps Handbook](https://itrevolution.com/the-devops-handbook/)
- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)

## 🎓 Workshop Completion

Congratulations! You have completed all modules of the MinIO Operator Workshop. You now have:

- **Foundation Knowledge**: Kubernetes storage, operators, and MinIO architecture
- **Practical Skills**: Deployment, configuration, and basic operations
- **Advanced Capabilities**: Performance tuning, security, monitoring
- **Production Readiness**: Backup, disaster recovery, and operational procedures

### Next Steps

```bash
# Run the workshop completion verification
cd ../../scripts
./workshop-completion.sh
```

### Continuing Your Journey

1. **Deploy in Production**: Apply what you've learned to real environments
2. **Join the Community**: Participate in MinIO and Kubernetes communities
3. **Stay Updated**: Follow MinIO releases and best practices
4. **Share Knowledge**: Help others learn these technologies

---

**🎉 Congratulations!** You've mastered MinIO operations in Kubernetes and are ready to deploy and manage production-grade object storage systems. Your journey in cloud-native storage has just begun!
