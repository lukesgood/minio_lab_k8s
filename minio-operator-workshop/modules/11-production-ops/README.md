# Module 11: Production Operations

## 🎯 Learning Objectives

By the end of this module, you will:
- Implement production-ready operational procedures
- Master scaling and capacity management
- Configure automated maintenance and updates
- Develop incident response procedures
- Create operational runbooks and documentation

## 📚 Key Concepts

### Day-2 Operations
Ongoing operational activities required to maintain a production system after initial deployment.

### Site Reliability Engineering (SRE)
Practices that incorporate aspects of software engineering and apply them to infrastructure and operations problems.

### Operational Excellence
The ability to run and monitor systems to deliver business value and continually improve supporting processes and procedures.

## 📋 Step-by-Step Instructions

### Step 1: Capacity Planning and Monitoring

```bash
# Create capacity monitoring script
cat << 'EOF' > capacity-monitor.sh
#!/bin/bash

echo "=== MinIO Capacity Monitoring Report ==="
echo "Generated at: $(date)"
echo ""

# Get cluster capacity information
echo "1. Storage Capacity:"
mc admin info local | grep -E "(Used|Total|Available)"

echo ""
echo "2. Per-Bucket Usage:"
buckets=$(mc ls local | awk '{print $5}')
for bucket in $buckets; do
    size=$(mc du local/$bucket 2>/dev/null | tail -1 | awk '{print $1, $2}')
    echo "   $bucket: $size"
done

echo ""
echo "3. Growth Trends (last 7 days):"
# In production, this would query historical metrics
echo "   Note: Implement with Prometheus queries for historical data"
echo "   Example: increase(minio_bucket_usage_total_bytes[7d])"

echo ""
echo "4. Capacity Alerts:"
# Check if usage is above thresholds
total_bytes=$(mc admin info local | grep "Used" | awk '{print $2}' | sed 's/[^0-9]//g')
if [ -n "$total_bytes" ] && [ "$total_bytes" -gt 0 ]; then
    # Simplified calculation - in production use proper metrics
    echo "   Current usage monitoring active"
else
    echo "   Unable to determine current usage"
fi

echo ""
echo "5. Recommendations:"
echo "   - Monitor growth trends weekly"
echo "   - Plan capacity expansion at 70% usage"
echo "   - Implement automated alerts at 80% usage"
echo "   - Review data lifecycle policies monthly"

EOF

chmod +x capacity-monitor.sh

# Run capacity monitoring
./capacity-monitor.sh
```

### Step 2: Scaling Operations

```bash
# Create scaling procedures
echo "=== Scaling MinIO Tenant ==="

# Current tenant configuration
echo "Current tenant configuration:"
kubectl get tenant minio -n minio-tenant -o jsonpath='{.spec.pools[0].servers}' | xargs echo "Servers:"
kubectl get tenant minio -n minio-tenant -o jsonpath='{.spec.pools[0].volumesPerServer}' | xargs echo "Volumes per server:"

# Horizontal scaling (add more servers)
echo ""
echo "Horizontal scaling example (adding servers):"
cat << EOF > scale-horizontal.yaml
# Scale from 1 to 2 servers
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio
  namespace: minio-tenant
spec:
  pools:
  - servers: 2  # Increased from 1
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
EOF

echo "To scale horizontally: kubectl apply -f scale-horizontal.yaml"

# Vertical scaling (increase resources)
echo ""
echo "Vertical scaling example (increase resources):"
cat << EOF > scale-vertical.yaml
# Increase CPU and memory resources
spec:
  pools:
  - resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
      limits:
        memory: "8Gi"
        cpu: "4000m"
EOF

echo "To scale vertically: kubectl patch tenant minio -n minio-tenant --type='merge' -p='\$(cat scale-vertical.yaml)'"

# Storage scaling
echo ""
echo "Storage scaling (expand PVCs):"
echo "kubectl patch pvc data-0-minio-pool-0-0 -n minio-tenant -p='{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"5Gi\"}}}}'"
echo "Note: Requires storage class with allowVolumeExpansion: true"
```

### Step 3: Automated Maintenance Procedures

```bash
# Create maintenance automation
cat << 'EOF' > maintenance-procedures.sh
#!/bin/bash

MAINTENANCE_MODE=${1:-"check"}  # check, enable, disable

case $MAINTENANCE_MODE in
    "check")
        echo "=== Maintenance Status Check ==="
        echo "Cluster Health:"
        mc admin info local
        
        echo ""
        echo "Pod Status:"
        kubectl get pods -n minio-tenant
        
        echo ""
        echo "Storage Status:"
        kubectl get pvc -n minio-tenant
        
        echo ""
        echo "Recent Events:"
        kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | tail -10
        ;;
        
    "enable")
        echo "=== Enabling Maintenance Mode ==="
        
        # Scale down console (optional)
        kubectl scale deployment minio-tenant-console -n minio-tenant --replicas=0
        
        # Add maintenance annotation
        kubectl annotate tenant minio -n minio-tenant maintenance.minio.io/mode="enabled"
        kubectl annotate tenant minio -n minio-tenant maintenance.minio.io/timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        echo "Maintenance mode enabled"
        echo "MinIO API remains available, Console scaled down"
        ;;
        
    "disable")
        echo "=== Disabling Maintenance Mode ==="
        
        # Scale up console
        kubectl scale deployment minio-tenant-console -n minio-tenant --replicas=1
        
        # Remove maintenance annotation
        kubectl annotate tenant minio -n minio-tenant maintenance.minio.io/mode-
        kubectl annotate tenant minio -n minio-tenant maintenance.minio.io/timestamp-
        
        echo "Maintenance mode disabled"
        echo "All services restored"
        ;;
        
    *)
        echo "Usage: $0 {check|enable|disable}"
        exit 1
        ;;
esac
EOF

chmod +x maintenance-procedures.sh

# Test maintenance procedures
./maintenance-procedures.sh check
```

### Step 4: Update and Upgrade Procedures

```bash
# Create update procedures
cat << 'EOF' > update-procedures.sh
#!/bin/bash

UPDATE_TYPE=${1:-"check"}  # check, operator, tenant, rollback

case $UPDATE_TYPE in
    "check")
        echo "=== Update Status Check ==="
        
        echo "Current Operator Version:"
        kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
        echo ""
        
        echo "Current Tenant Version:"
        kubectl get tenant minio -n minio-tenant -o jsonpath='{.spec.image}'
        echo ""
        
        echo "Available Updates:"
        echo "Check https://github.com/minio/operator/releases for latest operator"
        echo "Check https://github.com/minio/minio/releases for latest MinIO"
        ;;
        
    "operator")
        echo "=== Updating MinIO Operator ==="
        
        # Backup current operator configuration
        kubectl get deployment minio-operator -n minio-operator -o yaml > operator-backup-$(date +%Y%m%d).yaml
        
        # Update operator
        echo "Updating to latest operator version..."
        kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
        
        # Wait for rollout
        kubectl rollout status deployment/minio-operator -n minio-operator
        
        echo "Operator update completed"
        ;;
        
    "tenant")
        echo "=== Updating MinIO Tenant ==="
        
        # Backup current tenant configuration
        kubectl get tenant minio -n minio-tenant -o yaml > tenant-backup-$(date +%Y%m%d).yaml
        
        # Update tenant image
        NEW_IMAGE="minio/minio:RELEASE.2025-04-08T15-41-24Z"
        kubectl patch tenant minio -n minio-tenant --type='merge' -p="{\"spec\":{\"image\":\"$NEW_IMAGE\"}}"
        
        # Monitor rollout
        echo "Monitoring tenant update..."
        kubectl rollout status statefulset/minio-pool-0 -n minio-tenant
        
        echo "Tenant update completed"
        ;;
        
    "rollback")
        echo "=== Rolling Back Update ==="
        
        # List available backups
        echo "Available backups:"
        ls -la *-backup-*.yaml 2>/dev/null || echo "No backups found"
        
        echo ""
        echo "To rollback:"
        echo "1. kubectl apply -f operator-backup-YYYYMMDD.yaml"
        echo "2. kubectl apply -f tenant-backup-YYYYMMDD.yaml"
        echo "3. Monitor rollout status"
        ;;
        
    *)
        echo "Usage: $0 {check|operator|tenant|rollback}"
        exit 1
        ;;
esac
EOF

chmod +x update-procedures.sh

# Check current update status
./update-procedures.sh check
```

### Step 5: Health Checks and Monitoring

```bash
# Create comprehensive health check
cat << 'EOF' > health-check.sh
#!/bin/bash

echo "=== MinIO Health Check ==="
echo "Timestamp: $(date)"
echo ""

# 1. Kubernetes Resources Health
echo "1. Kubernetes Resources:"
echo "   Operator Status:"
kubectl get pods -n minio-operator | grep minio-operator | awk '{print "     " $1 ": " $3}'

echo "   Tenant Status:"
kubectl get pods -n minio-tenant | grep minio-pool | awk '{print "     " $1 ": " $3}'

echo "   Storage Status:"
kubectl get pvc -n minio-tenant | grep -v NAME | awk '{print "     " $1 ": " $2}'

# 2. MinIO Service Health
echo ""
echo "2. MinIO Service Health:"
if mc admin info local >/dev/null 2>&1; then
    echo "   ✅ MinIO API accessible"
    
    # Get detailed health info
    mc admin info local | grep -E "(Uptime|Version|Network|Drives)"
else
    echo "   ❌ MinIO API not accessible"
fi

# 3. Storage Health
echo ""
echo "3. Storage Health:"
if mc admin heal local --dry-run >/dev/null 2>&1; then
    echo "   ✅ Storage integrity check passed"
else
    echo "   ⚠️  Storage integrity check failed or not available"
fi

# 4. Performance Check
echo ""
echo "4. Performance Check:"
if command -v time >/dev/null 2>&1; then
    echo "   Testing basic operations..."
    
    # Create test file
    echo "Health check test" > health-test.txt
    
    # Upload test
    upload_time=$(time mc cp health-test.txt local/test-bucket/health-check.txt 2>&1 | grep real | awk '{print $2}')
    echo "   Upload time: $upload_time"
    
    # Download test
    download_time=$(time mc cp local/test-bucket/health-check.txt health-check-downloaded.txt 2>&1 | grep real | awk '{print $2}')
    echo "   Download time: $download_time"
    
    # Cleanup
    rm -f health-test.txt health-check-downloaded.txt
    mc rm local/test-bucket/health-check.txt 2>/dev/null
else
    echo "   Performance testing not available"
fi

# 5. Security Check
echo ""
echo "5. Security Status:"
if kubectl get networkpolicy minio-network-policy -n minio-tenant >/dev/null 2>&1; then
    echo "   ✅ Network policies configured"
else
    echo "   ⚠️  Network policies not configured"
fi

if kubectl get secret minio-tls-secret -n minio-tenant >/dev/null 2>&1; then
    echo "   ✅ TLS certificates configured"
else
    echo "   ⚠️  TLS certificates not configured"
fi

# 6. Backup Status
echo ""
echo "6. Backup Status:"
if mc ls backup/production-backup/ >/dev/null 2>&1; then
    latest_backup=$(mc ls backup/production-backup/ | tail -1 | awk '{print $1, $2}')
    echo "   ✅ Backups available, latest: $latest_backup"
else
    echo "   ⚠️  No backups found or backup system not accessible"
fi

# 7. Resource Usage
echo ""
echo "7. Resource Usage:"
kubectl top pods -n minio-tenant 2>/dev/null | grep minio-pool || echo "   Resource metrics not available"

echo ""
echo "=== Health Check Complete ==="

# Return appropriate exit code
if mc admin info local >/dev/null 2>&1; then
    echo "Overall Status: ✅ HEALTHY"
    exit 0
else
    echo "Overall Status: ❌ UNHEALTHY"
    exit 1
fi
EOF

chmod +x health-check.sh

# Run health check
./health-check.sh
```

### Step 6: Incident Response Procedures

```bash
# Create incident response runbook
cat << 'EOF' > incident-response.sh
#!/bin/bash

INCIDENT_TYPE=${1:-"help"}

case $INCIDENT_TYPE in
    "help")
        echo "=== MinIO Incident Response ==="
        echo ""
        echo "Available incident types:"
        echo "  pod-crash     - Handle pod crashes"
        echo "  storage-full  - Handle storage full scenarios"
        echo "  network-issue - Handle network connectivity issues"
        echo "  performance   - Handle performance degradation"
        echo "  security      - Handle security incidents"
        echo "  data-loss     - Handle data loss scenarios"
        echo ""
        echo "Usage: $0 <incident-type>"
        ;;
        
    "pod-crash")
        echo "=== Pod Crash Incident Response ==="
        echo ""
        echo "1. Assess the situation:"
        kubectl get pods -n minio-tenant
        
        echo ""
        echo "2. Check pod logs:"
        crashed_pods=$(kubectl get pods -n minio-tenant | grep -E "(Error|CrashLoopBackOff)" | awk '{print $1}')
        for pod in $crashed_pods; do
            echo "   Logs for $pod:"
            kubectl logs $pod -n minio-tenant --tail=20
        done
        
        echo ""
        echo "3. Check events:"
        kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | tail -10
        
        echo ""
        echo "4. Recovery actions:"
        echo "   - If persistent issue: kubectl delete pod <pod-name> -n minio-tenant"
        echo "   - Check resource constraints: kubectl describe pod <pod-name> -n minio-tenant"
        echo "   - Verify storage: kubectl get pvc -n minio-tenant"
        ;;
        
    "storage-full")
        echo "=== Storage Full Incident Response ==="
        echo ""
        echo "1. Check storage usage:"
        mc admin info local
        
        echo ""
        echo "2. Identify large objects:"
        buckets=$(mc ls local | awk '{print $5}')
        for bucket in $buckets; do
            echo "   Large objects in $bucket:"
            mc ls --recursive local/$bucket | sort -k3 -hr | head -5
        done
        
        echo ""
        echo "3. Recovery actions:"
        echo "   - Clean up unnecessary data"
        echo "   - Expand storage: kubectl patch pvc <pvc-name> -n minio-tenant -p='{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"<new-size>\"}}}}'"
        echo "   - Add more volumes/servers"
        echo "   - Implement lifecycle policies"
        ;;
        
    "network-issue")
        echo "=== Network Issue Incident Response ==="
        echo ""
        echo "1. Test connectivity:"
        kubectl exec -n minio-tenant minio-pool-0-0 -- ping -c 3 8.8.8.8
        
        echo ""
        echo "2. Check services:"
        kubectl get svc -n minio-tenant
        
        echo ""
        echo "3. Check network policies:"
        kubectl get networkpolicy -n minio-tenant
        
        echo ""
        echo "4. Test internal connectivity:"
        kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://minio.minio-tenant.svc.cluster.local:9000/minio/health/live
        ;;
        
    "performance")
        echo "=== Performance Issue Incident Response ==="
        echo ""
        echo "1. Check resource usage:"
        kubectl top pods -n minio-tenant
        
        echo ""
        echo "2. Run performance test:"
        mc admin speedtest local --duration=10s
        
        echo ""
        echo "3. Check for bottlenecks:"
        echo "   - CPU/Memory: kubectl describe pod minio-pool-0-0 -n minio-tenant"
        echo "   - Storage I/O: kubectl exec -n minio-tenant minio-pool-0-0 -- iostat -x 1 3"
        echo "   - Network: Check network policies and bandwidth"
        ;;
        
    "security")
        echo "=== Security Incident Response ==="
        echo ""
        echo "1. Check for unauthorized access:"
        kubectl logs -n minio-tenant minio-pool-0-0 | grep -i "access denied"
        
        echo ""
        echo "2. Review user activities:"
        mc admin user list local
        
        echo ""
        echo "3. Immediate actions:"
        echo "   - Change admin password: mc admin user add local admin <new-password>"
        echo "   - Disable suspicious users: mc admin user disable local <username>"
        echo "   - Review and update policies"
        echo "   - Enable audit logging if not already enabled"
        ;;
        
    "data-loss")
        echo "=== Data Loss Incident Response ==="
        echo ""
        echo "1. Assess the scope:"
        echo "   - Identify missing data"
        echo "   - Determine time of loss"
        echo "   - Check if versioning was enabled"
        
        echo ""
        echo "2. Check available backups:"
        mc ls backup/production-backup/
        
        echo ""
        echo "3. Recovery options:"
        echo "   - Restore from backup: ./restore-from-backup.sh"
        echo "   - Check object versions: mc ls --versions local/<bucket>/"
        echo "   - Contact support if hardware failure"
        
        echo ""
        echo "4. Prevention measures:"
        echo "   - Enable versioning: mc version enable local/<bucket>"
        echo "   - Implement object locking: mc retention set local/<bucket>"
        echo "   - Regular backup verification"
        ;;
        
    *)
        echo "Unknown incident type: $INCIDENT_TYPE"
        echo "Use '$0 help' for available options"
        exit 1
        ;;
esac
EOF

chmod +x incident-response.sh

# Test incident response help
./incident-response.sh help
```

### Step 7: Operational Runbooks

```bash
# Create operational runbooks directory structure
mkdir -p runbooks/{daily,weekly,monthly,emergency}

# Daily operations runbook
cat << 'EOF' > runbooks/daily/daily-checklist.md
# MinIO Daily Operations Checklist

## Morning Checks (Start of Business)

### 1. System Health
- [ ] Run health check: `./health-check.sh`
- [ ] Check all pods are running: `kubectl get pods -n minio-tenant`
- [ ] Verify MinIO API accessibility: `mc admin info local`

### 2. Capacity Monitoring
- [ ] Check storage usage: `./capacity-monitor.sh`
- [ ] Review growth trends
- [ ] Alert if usage > 80%

### 3. Performance Check
- [ ] Run basic performance test: `mc admin speedtest local --duration=30s`
- [ ] Check response times are within SLA
- [ ] Review any performance alerts

### 4. Security Review
- [ ] Check for failed authentication attempts
- [ ] Review audit logs for suspicious activity
- [ ] Verify backup completion

## End of Day Tasks

### 1. Backup Verification
- [ ] Verify daily backup completed successfully
- [ ] Check backup integrity
- [ ] Update backup status dashboard

### 2. Incident Review
- [ ] Review any incidents from the day
- [ ] Update incident documentation
- [ ] Plan follow-up actions

### 3. Capacity Planning
- [ ] Update capacity forecasts
- [ ] Plan any needed scaling actions
- [ ] Review storage lifecycle policies

## Escalation Contacts
- Primary: [Your Name] - [Contact Info]
- Secondary: [Backup Person] - [Contact Info]
- Emergency: [Manager] - [Contact Info]
EOF

# Weekly operations runbook
cat << 'EOF' > runbooks/weekly/weekly-maintenance.md
# MinIO Weekly Maintenance

## Weekly Tasks

### 1. System Updates
- [ ] Check for MinIO updates: `./update-procedures.sh check`
- [ ] Review security patches
- [ ] Plan update windows if needed

### 2. Performance Analysis
- [ ] Review weekly performance metrics
- [ ] Analyze capacity growth trends
- [ ] Identify optimization opportunities

### 3. Security Review
- [ ] Run security scan: `./security-scan.sh`
- [ ] Review user access and permissions
- [ ] Update security policies if needed

### 4. Backup Testing
- [ ] Test backup restoration process
- [ ] Verify backup retention policies
- [ ] Update disaster recovery procedures

### 5. Documentation Updates
- [ ] Update operational procedures
- [ ] Review and update runbooks
- [ ] Update contact information

## Monthly Planning
- [ ] Capacity planning review
- [ ] Budget planning for scaling
- [ ] Training needs assessment
EOF

# Emergency procedures runbook
cat << 'EOF' > runbooks/emergency/emergency-procedures.md
# MinIO Emergency Procedures

## Severity Levels

### P1 - Critical (Complete Service Outage)
- **Response Time**: Immediate (< 15 minutes)
- **Actions**: 
  1. Activate incident response team
  2. Run `./incident-response.sh pod-crash`
  3. Implement emergency recovery procedures
  4. Communicate with stakeholders

### P2 - High (Partial Service Degradation)
- **Response Time**: < 1 hour
- **Actions**:
  1. Assess impact scope
  2. Run appropriate incident response
  3. Implement workarounds
  4. Plan permanent fix

### P3 - Medium (Performance Issues)
- **Response Time**: < 4 hours
- **Actions**:
  1. Run `./incident-response.sh performance`
  2. Analyze root cause
  3. Implement optimization
  4. Monitor improvement

## Emergency Contacts
- On-Call Engineer: [Phone Number]
- Manager: [Phone Number]
- Infrastructure Team: [Phone Number]
- Vendor Support: [Support Number]

## Recovery Procedures
1. **Complete Cluster Failure**: Follow disaster recovery plan
2. **Data Corruption**: Restore from backup
3. **Security Breach**: Follow security incident response
4. **Network Outage**: Coordinate with network team
EOF

echo "Operational runbooks created in runbooks/ directory"
```

This completes the first part of Module 11. Let me continue with the remaining sections.
