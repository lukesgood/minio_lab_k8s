# Lab 7: 모니터링 설정

## 📚 학습 목표

이 실습에서는 MinIO 클러스터의 종합적인 모니터링 시스템을 구축합니다:

- **Prometheus 메트릭 수집**: MinIO 성능 지표 수집
- **Grafana 대시보드**: 시각적 모니터링 구성
- **알림 시스템**: 임계값 기반 알림 설정
- **로그 수집**: 중앙화된 로그 관리
- **헬스 체크**: 서비스 상태 모니터링
- **성능 분석**: 실시간 성능 추적

## 🎯 핵심 개념

### 모니터링 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MinIO Pods    │───▶│   Prometheus    │───▶│    Grafana      │
│   (메트릭 생성)  │    │   (메트릭 수집)  │    │   (시각화)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Log Files     │    │   AlertManager  │    │   Notification  │
│   (로그 수집)    │    │   (알림 관리)    │    │   (알림 전송)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 주요 메트릭 카테고리

| 카테고리 | 메트릭 예시 | 설명 |
|----------|-------------|------|
| **시스템** | CPU, Memory, Disk | 리소스 사용량 |
| **네트워크** | Bandwidth, Latency | 네트워크 성능 |
| **스토리지** | IOPS, Throughput | 스토리지 성능 |
| **API** | Request Rate, Error Rate | API 호출 통계 |
| **비즈니스** | Object Count, Bucket Size | 비즈니스 메트릭 |

## 🚀 실습 시작

### 1단계: 모니터링 네임스페이스 준비

```bash
# 모니터링 네임스페이스 생성
kubectl create namespace monitoring

# 네임스페이스 확인
kubectl get namespaces
```

### 2단계: Prometheus 설치

#### Prometheus 설정 파일 생성

```bash
# Prometheus 설정 파일 생성
cat > prometheus-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "minio_rules.yml"
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'minio'
        static_configs:
          - targets: ['minio.minio-tenant.svc.cluster.local:9000']
        metrics_path: /minio/v2/metrics/cluster
        scheme: http
        scrape_interval: 30s
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - minio-tenant
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
  
  minio_rules.yml: |
    groups:
      - name: minio_alerts
        rules:
          - alert: MinIOHighCPUUsage
            expr: rate(minio_node_cpu_total_seconds[5m]) > 0.8
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "MinIO high CPU usage"
              description: "MinIO CPU usage is above 80% for more than 5 minutes"
          
          - alert: MinIOHighMemoryUsage
            expr: minio_node_memory_used_bytes / minio_node_memory_total_bytes > 0.9
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "MinIO high memory usage"
              description: "MinIO memory usage is above 90%"
          
          - alert: MinIODiskSpaceLow
            expr: minio_node_disk_free_bytes / minio_node_disk_total_bytes < 0.1
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: "MinIO disk space low"
              description: "MinIO disk space is below 10%"
EOF

kubectl apply -f prometheus-config.yaml

# 📋 예상 결과:
# configmap/prometheus-config created
# 
# 💡 설명:
# - Prometheus 설정이 ConfigMap으로 생성됨
# - MinIO 메트릭 수집을 위한 scrape 설정 포함
# - 알림 규칙이 함께 설정됨
```

#### Prometheus 배포

```bash
# Prometheus 배포 파일 생성
cat > prometheus-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config-volume
          mountPath: /etc/prometheus
        - name: storage-volume
          mountPath: /prometheus
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=15d'
          - '--web.enable-lifecycle'
      volumes:
      - name: config-volume
        configMap:
          name: prometheus-config
      - name: storage-volume
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
  type: ClusterIP
EOF

kubectl apply -f prometheus-deployment.yaml

# 📋 예상 결과:
# deployment.apps/prometheus created
# service/prometheus created
# 
# 💡 설명:
# - Prometheus 서버가 monitoring 네임스페이스에 배포됨
# - ClusterIP 서비스로 내부 접근 가능
# - 15일간 메트릭 데이터 보존 설정
```

### 3단계: Grafana 설치

#### Grafana 설정 및 배포

```bash
# Grafana 배포 파일 생성
cat > grafana-deployment.yaml << 'EOF'
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
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
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
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: ClusterIP
EOF

kubectl apply -f grafana-deployment.yaml

# 📋 예상 결과:
# deployment.apps/grafana created
# service/grafana created
# 
# 💡 설명:
# - Grafana가 monitoring 네임스페이스에 배포됨
# - 기본 관리자 계정: admin/admin123
# - 포트 3000으로 웹 인터페이스 제공
```

### 4단계: 서비스 상태 확인

```bash
# 모니터링 서비스 상태 확인
echo "=== 모니터링 서비스 상태 ==="
kubectl get pods -n monitoring
kubectl get services -n monitoring

# 📋 예상 결과:
# NAME                          READY   STATUS    RESTARTS   AGE
# grafana-7c6b4b8f9d-x7k2m     1/1     Running   0          2m
# prometheus-6f8d7c9b5d-h4n8j  1/1     Running   0          3m
# 
# NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# grafana      ClusterIP   10.96.123.45    <none>        3000/TCP   2m
# prometheus   ClusterIP   10.96.234.56    <none>        9090/TCP   3m
# 
# 💡 설명:
# - 모든 Pod가 Running 상태여야 함
# - ClusterIP로 내부 통신 가능
# - 포트 포워딩으로 외부 접근 설정

# 포트 포워딩 설정
echo "포트 포워딩 설정 중..."
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

sleep 5
echo "서비스 접근 URL:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin123)"
```

### 5단계: MinIO 메트릭 활성화

#### MinIO에서 Prometheus 메트릭 활성화

```bash
# MinIO Prometheus 메트릭 확인
echo "=== MinIO 메트릭 확인 ==="

# MinIO 포트 포워딩 (필요시)
kubectl port-forward -n minio-tenant svc/minio 9000:80 &

# 메트릭 엔드포인트 확인
curl -s http://localhost:9000/minio/v2/metrics/cluster | head -20

# MinIO 서버 정보 확인
mc admin info local
```

### 6단계: Grafana 대시보드 설정

#### Prometheus 데이터소스 추가

```bash
# Grafana 데이터소스 설정 파일 생성
cat > grafana-datasource.json << 'EOF'
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://prometheus:9090",
  "access": "proxy",
  "isDefault": true
}
EOF

echo "Grafana 웹 인터페이스에서 다음 단계를 수행하세요:"
echo "1. http://localhost:3000 접속"
echo "2. admin/admin123으로 로그인"
echo "3. Configuration > Data Sources > Add data source"
echo "4. Prometheus 선택"
echo "5. URL: http://prometheus:9090 입력"
echo "6. Save & Test 클릭"
```

#### MinIO 대시보드 생성

```bash
# MinIO 대시보드 JSON 생성
cat > minio-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "MinIO Monitoring Dashboard",
    "tags": ["minio"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "MinIO Uptime",
        "type": "stat",
        "targets": [
          {
            "expr": "minio_node_uptime_seconds",
            "legendFormat": "Uptime"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Total Objects",
        "type": "stat",
        "targets": [
          {
            "expr": "minio_bucket_objects_count",
            "legendFormat": "Objects"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "API Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(minio_s3_requests_total[5m])",
            "legendFormat": "{{method}} {{api}}"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Network I/O",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(minio_network_received_bytes_total[5m])",
            "legendFormat": "Received"
          },
          {
            "expr": "rate(minio_network_sent_bytes_total[5m])",
            "legendFormat": "Sent"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
      },
      {
        "id": 5,
        "title": "Disk Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "minio_node_disk_used_bytes",
            "legendFormat": "Used"
          },
          {
            "expr": "minio_node_disk_total_bytes",
            "legendFormat": "Total"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

echo "대시보드 JSON 파일이 생성되었습니다."
echo "Grafana에서 Import Dashboard를 통해 minio-dashboard.json을 가져오세요."
```

### 7단계: AlertManager 설정

#### AlertManager 배포

```bash
# AlertManager 설정 파일 생성
cat > alertmanager-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alertmanager@example.com'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true
    
    - name: 'email'
      email_configs:
      - to: 'admin@example.com'
        subject: 'MinIO Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:latest
        ports:
        - containerPort: 9093
        volumeMounts:
        - name: config-volume
          mountPath: /etc/alertmanager
        args:
          - '--config.file=/etc/alertmanager/alertmanager.yml'
          - '--storage.path=/alertmanager'
      volumes:
      - name: config-volume
        configMap:
          name: alertmanager-config
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector:
    app: alertmanager
  ports:
    - protocol: TCP
      port: 9093
      targetPort: 9093
  type: ClusterIP
EOF

kubectl apply -f alertmanager-config.yaml
```

### 8단계: 로그 수집 설정

#### Fluent Bit 로그 수집기 설치

```bash
# Fluent Bit 설정 생성
cat > fluent-bit-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: monitoring
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
    
    [INPUT]
        Name              tail
        Path              /var/log/containers/*minio*.log
        Parser            docker
        Tag               minio.*
        Refresh_Interval  5
    
    [OUTPUT]
        Name  stdout
        Match *
  
  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep   On
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: monitoring
spec:
  selector:
    matchLabels:
      name: fluent-bit
  template:
    metadata:
      labels:
        name: fluent-bit
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
EOF

kubectl apply -f fluent-bit-config.yaml
```

### 9단계: 헬스 체크 설정

#### MinIO 헬스 체크 스크립트

```bash
# 헬스 체크 스크립트 생성
cat > health_check.sh << 'EOF'
#!/bin/bash

echo "=== MinIO 헬스 체크 ==="

# MinIO 서비스 상태 확인
echo "1. MinIO 서비스 상태:"
kubectl get pods -n minio-tenant

# MinIO API 응답 확인
echo -e "\n2. MinIO API 헬스 체크:"
curl -s http://localhost:9000/minio/health/live && echo "✅ Live" || echo "❌ Not Live"
curl -s http://localhost:9000/minio/health/ready && echo "✅ Ready" || echo "❌ Not Ready"

# 스토리지 상태 확인
echo -e "\n3. 스토리지 상태:"
mc admin info local

# 메트릭 엔드포인트 확인
echo -e "\n4. 메트릭 수집 상태:"
curl -s http://localhost:9000/minio/v2/metrics/cluster | grep -c "minio_" && echo "✅ 메트릭 수집 정상" || echo "❌ 메트릭 수집 실패"

# 모니터링 서비스 상태
echo -e "\n5. 모니터링 서비스 상태:"
kubectl get pods -n monitoring

echo -e "\n=== 헬스 체크 완료 ==="
EOF

chmod +x health_check.sh
./health_check.sh
```

### 10단계: 성능 모니터링 테스트

#### 부하 생성 및 모니터링

```bash
# 부하 테스트 스크립트 생성
cat > load_test_monitoring.sh << 'EOF'
#!/bin/bash

echo "=== 부하 테스트 및 모니터링 ==="

# 테스트 파일 생성
echo "테스트 파일 생성 중..."
for i in {1..10}; do
    dd if=/dev/zero of=load_test_${i}.dat bs=1M count=10 2>/dev/null
done

# 부하 생성 (백그라운드)
echo "부하 생성 시작..."
for i in {1..10}; do
    (
        while true; do
            mc cp load_test_${i}.dat local/test-bucket/load_${i}_$(date +%s).dat 2>/dev/null
            mc rm local/test-bucket/load_${i}_$(date +%s).dat 2>/dev/null
            sleep 1
        done
    ) &
done

LOAD_PIDS=$!

echo "부하 테스트 실행 중... (30초간)"
echo "Grafana 대시보드에서 실시간 메트릭을 확인하세요:"
echo "- http://localhost:3000"

# 30초 대기
sleep 30

# 부하 중지
echo "부하 테스트 중지..."
pkill -f "load_test"

# 정리
rm -f load_test_*.dat

echo "부하 테스트 완료"
EOF

chmod +x load_test_monitoring.sh
./load_test_monitoring.sh
```

### 11단계: 알림 테스트

#### 임계값 초과 시뮬레이션

```bash
# 알림 테스트 스크립트
cat > alert_test.sh << 'EOF'
#!/bin/bash

echo "=== 알림 시스템 테스트 ==="

# 대용량 파일로 디스크 사용량 증가 시뮬레이션
echo "디스크 사용량 증가 시뮬레이션..."
dd if=/dev/zero of=large_file_for_alert.dat bs=1M count=500 2>/dev/null
mc cp large_file_for_alert.dat local/test-bucket/

# CPU 부하 생성
echo "CPU 부하 생성..."
stress --cpu 2 --timeout 60s &

# 메모리 부하 생성 (주의: 시스템 리소스 고려)
echo "메모리 부하 생성..."
stress --vm 1 --vm-bytes 512M --timeout 60s &

echo "알림 테스트 실행 중..."
echo "Prometheus Alerts 페이지에서 알림 상태를 확인하세요:"
echo "- http://localhost:9090/alerts"
echo "- AlertManager: http://localhost:9093"

# 1분 대기
sleep 60

# 정리
rm -f large_file_for_alert.dat
mc rm local/test-bucket/large_file_for_alert.dat 2>/dev/null

echo "알림 테스트 완료"
EOF

chmod +x alert_test.sh

# stress 도구 설치 확인
if ! command -v stress &> /dev/null; then
    echo "stress 도구가 설치되지 않았습니다. 다음 명령으로 설치하세요:"
    echo "sudo apt-get install stress  # Ubuntu/Debian"
    echo "sudo yum install stress      # CentOS/RHEL"
else
    ./alert_test.sh
fi
```

### 12단계: 모니터링 대시보드 최적화

#### 커스텀 메트릭 추가

```bash
# 커스텀 메트릭 수집 스크립트
cat > custom_metrics.sh << 'EOF'
#!/bin/bash

echo "=== 커스텀 메트릭 수집 ==="

# 버킷별 객체 수 계산
echo "버킷별 통계:"
mc ls local | while read line; do
    bucket=$(echo $line | awk '{print $5}')
    if [ -n "$bucket" ]; then
        count=$(mc ls local/$bucket --recursive | wc -l)
        size=$(mc du local/$bucket | awk '{print $1}')
        echo "  $bucket: $count objects, $size bytes"
    fi
done

# API 호출 통계 (로그 기반)
echo -e "\n최근 API 호출 통계:"
kubectl logs -n minio-tenant -l app=minio --tail=100 | grep -E "(GET|PUT|DELETE)" | \
    awk '{print $7}' | sort | uniq -c | sort -nr | head -10

# 에러율 계산
echo -e "\n에러율 분석:"
total_requests=$(kubectl logs -n minio-tenant -l app=minio --tail=1000 | grep -c "HTTP")
error_requests=$(kubectl logs -n minio-tenant -l app=minio --tail=1000 | grep -c "HTTP.*[45][0-9][0-9]")

if [ $total_requests -gt 0 ]; then
    error_rate=$(echo "scale=2; $error_requests * 100 / $total_requests" | bc -l)
    echo "  총 요청: $total_requests"
    echo "  에러 요청: $error_requests"
    echo "  에러율: ${error_rate}%"
else
    echo "  요청 데이터 없음"
fi
EOF

chmod +x custom_metrics.sh
./custom_metrics.sh
```

## 🎯 실습 완료 체크리스트

- [ ] Prometheus 설치 및 설정 완료
- [ ] Grafana 대시보드 구성 완료
- [ ] AlertManager 알림 시스템 설정 완료
- [ ] 로그 수집 시스템 구축 완료
- [ ] 헬스 체크 시스템 구현 완료
- [ ] 부하 테스트 및 모니터링 완료
- [ ] 알림 시스템 테스트 완료
- [ ] 커스텀 메트릭 수집 완료

## 🧹 정리

실습이 완료되면 모니터링 리소스를 정리합니다:

```bash
# 모니터링 네임스페이스 삭제
kubectl delete namespace monitoring

# 테스트 스크립트 정리
rm -f *.sh *.json *.yaml

# 포트 포워딩 프로세스 종료
pkill -f "kubectl port-forward"

echo "모니터링 시스템 정리 완료"
```

## 📚 다음 단계

이제 **Lab 8: Helm Chart 실습**으로 진행하여 전통적인 Helm 배포 방식을 학습해보세요.

## 💡 핵심 포인트

1. **종합적 모니터링**: 시스템, 애플리케이션, 비즈니스 메트릭 모두 수집
2. **실시간 알림**: 임계값 기반 자동 알림으로 신속한 대응
3. **시각화**: Grafana 대시보드로 직관적인 상태 파악
4. **로그 중앙화**: 모든 로그를 중앙에서 수집 및 분석
5. **정기적 점검**: 헬스 체크를 통한 지속적인 상태 모니터링

---

**🔗 관련 문서:**
- [LAB-07-CONCEPTS.md](LAB-07-CONCEPTS.md) - 모니터링 시스템 상세 개념
- [LAB-08-GUIDE.md](LAB-08-GUIDE.md) - 다음 실습: Helm Chart 실습
