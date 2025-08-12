# Module 8: Monitoring & Observability

## 🎯 Learning Objectives

By the end of this module, you will:
- Set up Prometheus monitoring for MinIO
- Configure Grafana dashboards for visualization
- Understand key MinIO metrics and alerts
- Implement health checks and monitoring best practices
- Create custom alerts for production scenarios

## 📚 Key Concepts

### Observability Pillars
- **Metrics**: Quantitative data about system performance
- **Logs**: Event records for debugging and auditing
- **Traces**: Request flow through distributed systems

### MinIO Metrics
MinIO exposes Prometheus-compatible metrics for comprehensive monitoring of storage operations, performance, and health.

## 📋 Step-by-Step Instructions

### Step 1: Enable MinIO Metrics

```bash
# First, let's enable metrics collection on our existing tenant
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"prometheusOperator":true}}'

# Verify the tenant configuration
kubectl describe tenant minio -n minio-tenant | grep -i prometheus

# Check if metrics endpoint is available
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
curl http://localhost:9000/minio/v2/metrics/cluster
```

### Step 2: Install Prometheus Operator

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus Operator using the community operator
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available deployment/prometheus-operator -n default --timeout=300s

# Verify operator is running
kubectl get pods -l app.kubernetes.io/name=prometheus-operator
```

### Step 3: Deploy Prometheus Instance

```bash
# Create Prometheus instance
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: minio-prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      app: minio
  resources:
    requests:
      memory: 400Mi
      cpu: 100m
    limits:
      memory: 800Mi
      cpu: 200m
  retention: 24h
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
EOF

# Create service account and RBAC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF
```

### Step 4: Create ServiceMonitor for MinIO

```bash
# Create ServiceMonitor to scrape MinIO metrics
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio-servicemonitor
  namespace: monitoring
  labels:
    app: minio
spec:
  selector:
    matchLabels:
      v1.min.io/tenant: minio
  namespaceSelector:
    matchNames:
    - minio-tenant
  endpoints:
  - port: minio
    path: /minio/v2/metrics/cluster
    interval: 30s
    scrapeTimeout: 10s
EOF

# Verify ServiceMonitor is created
kubectl get servicemonitor -n monitoring
```

### Step 5: Deploy Grafana

```bash
# Create Grafana deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        resources:
          requests:
            memory: 200Mi
            cpu: 100m
          limits:
            memory: 400Mi
            cpu: 200m
      volumes:
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF

# Wait for Grafana to be ready
kubectl wait --for=condition=available deployment/grafana -n monitoring --timeout=300s
```

### Step 6: Configure Grafana Data Source

```bash
# Port forward to Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000 &

# Wait for Grafana to be accessible
sleep 10

# Get Prometheus service URL
PROMETHEUS_URL="http://minio-prometheus.monitoring.svc.cluster.local:9090"

# Configure Prometheus data source in Grafana
cat << EOF > grafana-datasource.json
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "$PROMETHEUS_URL",
  "access": "proxy",
  "isDefault": true
}
EOF

# Add data source via API
curl -X POST \
  -H "Content-Type: application/json" \
  -d @grafana-datasource.json \
  http://admin:admin123@localhost:3000/api/datasources

echo "Grafana data source configured"
```

### Step 7: Import MinIO Dashboard

```bash
# Download MinIO Grafana dashboard
curl -o minio-dashboard.json https://raw.githubusercontent.com/minio/minio/master/docs/metrics/prometheus/grafana/minio-dashboard.json

# Import dashboard via API
curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat minio-dashboard.json), \"overwrite\": true}" \
  http://admin:admin123@localhost:3000/api/dashboards/db

echo "MinIO dashboard imported"
```

### Step 8: Create Custom Alerts

```bash
# Create PrometheusRule for MinIO alerts
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: minio-alerts
  namespace: monitoring
  labels:
    app: minio
spec:
  groups:
  - name: minio.rules
    rules:
    - alert: MinIOClusterDiskOffline
      expr: minio_cluster_disk_offline_total > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "MinIO cluster has offline disk(s)"
        description: "MinIO cluster {{ \$labels.instance }} has {{ \$value }} offline disk(s)"
    
    - alert: MinIODiskSpaceUsage
      expr: (minio_cluster_capacity_usable_free_bytes / minio_cluster_capacity_usable_total_bytes) * 100 < 10
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "MinIO cluster disk space usage is above 90%"
        description: "MinIO cluster {{ \$labels.instance }} disk space usage is {{ \$value }}%"
    
    - alert: MinIOHighRequestLatency
      expr: histogram_quantile(0.99, rate(minio_s3_requests_ttfb_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "MinIO high request latency"
        description: "MinIO 99th percentile latency is {{ \$value }}s"
    
    - alert: MinIOHighErrorRate
      expr: rate(minio_s3_requests_errors_total[5m]) > 0.1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "MinIO high error rate"
        description: "MinIO error rate is {{ \$value }} errors/sec"
EOF

# Verify PrometheusRule is created
kubectl get prometheusrule -n monitoring
```

### Step 9: Test Monitoring Setup

```bash
# Generate some load to see metrics
echo "Generating test load for monitoring..."

# Create test data
for i in {1..20}; do
  dd if=/dev/zero of=monitor-test-${i}.dat bs=1M count=5
  mc cp monitor-test-${i}.dat local/test-bucket/monitoring/
done

# Perform various operations to generate metrics
mc ls local/test-bucket/monitoring/
mc stat local/test-bucket/monitoring/monitor-test-1.dat
mc cp local/test-bucket/monitoring/monitor-test-1.dat downloaded-monitor-test.dat

# Check metrics are being collected
echo "Checking MinIO metrics..."
curl -s http://localhost:9000/minio/v2/metrics/cluster | grep -E "(minio_s3_requests_total|minio_cluster_capacity)"

# Clean up test files
rm -f monitor-test-*.dat downloaded-monitor-test.dat
mc rm --recursive --force local/test-bucket/monitoring/ 2>/dev/null || true
```

### Step 10: Access Monitoring Dashboards

```bash
# Ensure port forwards are running
pkill -f "kubectl port-forward.*grafana" 2>/dev/null || true
pkill -f "kubectl port-forward.*prometheus" 2>/dev/null || true

# Start port forwards
kubectl port-forward svc/grafana -n monitoring 3000:3000 &
kubectl port-forward svc/minio-prometheus -n monitoring 9090:9090 &

echo "Access URLs:"
echo "- Grafana: http://localhost:3000 (admin/admin123)"
echo "- Prometheus: http://localhost:9090"
echo ""
echo "In Grafana:"
echo "1. Go to Dashboards"
echo "2. Look for MinIO dashboard"
echo "3. Explore metrics and create custom panels"
```

## 🔍 Understanding MinIO Metrics

### Key Metrics Categories

#### Cluster Health
- `minio_cluster_nodes_online_total`: Online nodes count
- `minio_cluster_nodes_offline_total`: Offline nodes count
- `minio_cluster_disk_online_total`: Online disks count
- `minio_cluster_disk_offline_total`: Offline disks count

#### Storage Capacity
- `minio_cluster_capacity_usable_total_bytes`: Total usable capacity
- `minio_cluster_capacity_usable_free_bytes`: Free capacity
- `minio_bucket_usage_total_bytes`: Per-bucket usage

#### Performance
- `minio_s3_requests_total`: Total S3 requests
- `minio_s3_requests_current`: Current active requests
- `minio_s3_requests_ttfb_seconds`: Time to first byte
- `minio_s3_traffic_sent_bytes`: Outbound traffic
- `minio_s3_traffic_received_bytes`: Inbound traffic

#### Errors
- `minio_s3_requests_errors_total`: Total request errors
- `minio_inter_node_traffic_errors_total`: Inter-node communication errors

### Dashboard Panels to Create

```bash
# Example queries for custom Grafana panels

# 1. Request Rate
rate(minio_s3_requests_total[5m])

# 2. Error Rate
rate(minio_s3_requests_errors_total[5m])

# 3. Storage Usage Percentage
(1 - (minio_cluster_capacity_usable_free_bytes / minio_cluster_capacity_usable_total_bytes)) * 100

# 4. Average Request Latency
histogram_quantile(0.50, rate(minio_s3_requests_ttfb_seconds_bucket[5m]))

# 5. Throughput (MB/s)
rate(minio_s3_traffic_sent_bytes[5m]) / 1024 / 1024
```

## ✅ Validation Checklist

Before proceeding to Module 9, ensure:

- [ ] Prometheus Operator is installed and running
- [ ] Prometheus instance is collecting MinIO metrics
- [ ] Grafana is accessible and configured with Prometheus data source
- [ ] MinIO dashboard is imported and showing data
- [ ] Custom alerts are configured and active
- [ ] Test load generated visible metrics
- [ ] Understanding of key MinIO metrics

## 🚨 Common Issues & Solutions

### Issue: Prometheus Not Scraping MinIO

```bash
# Check ServiceMonitor configuration
kubectl describe servicemonitor minio-servicemonitor -n monitoring

# Verify MinIO service labels
kubectl get svc minio -n minio-tenant --show-labels

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="minio-tenant/minio-servicemonitor")'
```

### Issue: Grafana Dashboard Shows No Data

```bash
# Verify data source connection
curl http://admin:admin123@localhost:3000/api/datasources

# Test Prometheus query directly
curl "http://localhost:9090/api/v1/query?query=minio_cluster_capacity_usable_total_bytes"

# Check Grafana logs
kubectl logs deployment/grafana -n monitoring
```

### Issue: Alerts Not Firing

```bash
# Check PrometheusRule status
kubectl describe prometheusrule minio-alerts -n monitoring

# Verify alert rules in Prometheus
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name | contains("MinIO"))'
```

## 🔧 Advanced Monitoring (Optional)

### Custom Metrics Collection

```bash
# Add custom labels to metrics
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"env":[{"name":"MINIO_PROMETHEUS_JOB_ID","value":"production-minio"}]}}'
```

### Log Aggregation

```bash
# Configure structured logging
kubectl patch tenant minio -n minio-tenant --type='merge' -p='{"spec":{"logging":{"json":true,"quiet":false}}}'

# View structured logs
kubectl logs minio-pool-0-0 -n minio-tenant | jq .
```

### Health Check Endpoints

```bash
# Test health endpoints
curl http://localhost:9000/minio/health/live
curl http://localhost:9000/minio/health/ready
curl http://localhost:9000/minio/health/cluster
```

## 📊 Monitoring Best Practices

### Alert Thresholds
- **Disk Usage**: Alert at 80%, critical at 90%
- **Error Rate**: Alert at 1%, critical at 5%
- **Latency**: Alert at 500ms, critical at 1s
- **Availability**: Alert on any node/disk offline

### Dashboard Organization
1. **Overview**: High-level cluster health
2. **Performance**: Throughput, latency, IOPS
3. **Capacity**: Storage usage and growth trends
4. **Errors**: Error rates and types
5. **Operations**: Request patterns and user activity

### Retention Policies
- **Metrics**: 30 days for detailed, 1 year for aggregated
- **Logs**: 7 days for debug, 30 days for audit
- **Alerts**: 90 days for historical analysis

## 📖 Additional Reading

- [MinIO Monitoring Guide](https://docs.min.io/minio/baremetal/operations/monitoring.html)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)

## ➡️ Next Steps

Now that you have comprehensive monitoring in place:

```bash
cd ../09-backup-recovery
cat README.md
```

---

**🎉 Excellent!** You've successfully implemented a complete monitoring and observability stack for MinIO. You can now track performance, identify issues proactively, and maintain visibility into your storage infrastructure. In the next module, we'll explore backup and disaster recovery strategies to protect your data.
