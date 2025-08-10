#!/bin/bash

echo "=== Lab 7: 모니터링 설정 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- Prometheus 메트릭 수집 설정"
echo "- Grafana 대시보드 구성"
echo "- MinIO 모니터링 지표 이해"
echo "- 알림 규칙 설정"
echo ""

# MinIO Client 명령어 확인
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    if [ -f "./mc" ]; then
        MC_CMD="./mc"
    else
        echo -e "${RED}❌ MinIO Client가 설치되지 않았습니다.${NC}"
        echo "먼저 Lab 3을 실행하여 MinIO Client를 설치하세요."
        exit 1
    fi
fi

# MinIO 연결 확인
echo -e "${GREEN}1. MinIO 서버 연결 확인${NC}"
echo "명령어: mc admin info local"
echo "목적: MinIO 서버 상태 및 메트릭 엔드포인트 확인"
echo ""

if ! $MC_CMD admin info local &>/dev/null; then
    echo -e "${RED}❌ MinIO 서버에 연결할 수 없습니다.${NC}"
    echo "먼저 Lab 3을 실행하여 포트 포워딩을 설정하세요."
    exit 1
fi
echo -e "${GREEN}✅ MinIO 서버 연결 확인${NC}"

# Prometheus 설치 확인
echo ""
echo -e "${GREEN}2. Prometheus 설치 확인${NC}"
echo "목적: 메트릭 수집을 위한 Prometheus 설치 상태 확인"
echo ""

if kubectl get namespace monitoring &>/dev/null; then
    echo -e "${GREEN}✅ monitoring 네임스페이스가 이미 존재합니다${NC}"
else
    echo "monitoring 네임스페이스 생성 중..."
    kubectl create namespace monitoring
fi

# Prometheus 설치 (간단한 버전)
echo ""
echo -e "${GREEN}3. Prometheus 설치${NC}"
echo "목적: MinIO 메트릭 수집을 위한 Prometheus 배포"
echo ""

if kubectl get deployment prometheus -n monitoring &>/dev/null; then
    echo -e "${GREEN}✅ Prometheus가 이미 설치되어 있습니다${NC}"
else
    echo "Prometheus 설치 중..."
    
    # Prometheus ConfigMap 생성
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
      - "minio_alerts.yml"
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'minio-cluster'
        metrics_path: /minio/v2/metrics/cluster
        static_configs:
          - targets: ['minio.minio-tenant.svc.cluster.local']
        scrape_interval: 30s
      
      - job_name: 'minio-node'
        metrics_path: /minio/v2/metrics/node
        static_configs:
          - targets: ['minio.minio-tenant.svc.cluster.local']
        scrape_interval: 30s
      
      - job_name: 'minio-bucket'
        metrics_path: /minio/v2/metrics/bucket
        static_configs:
          - targets: ['minio.minio-tenant.svc.cluster.local']
        scrape_interval: 60s

  minio_alerts.yml: |
    groups:
    - name: minio
      rules:
      - alert: MinIONodeDown
        expr: minio_cluster_nodes_offline_total > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "MinIO node is down"
          description: "{{ $value }} MinIO nodes are offline"
      
      - alert: MinIODiskUsageHigh
        expr: (minio_cluster_capacity_usable_total_bytes - minio_cluster_capacity_usable_free_bytes) / minio_cluster_capacity_usable_total_bytes > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "MinIO disk usage is high"
          description: "MinIO disk usage is above 80%"
      
      - alert: MinIOHighRequestLatency
        expr: histogram_quantile(0.99, rate(minio_http_requests_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MinIO high request latency"
          description: "99th percentile latency is {{ $value }}s"
EOF

    kubectl apply -f prometheus-config.yaml
    
    # Prometheus Deployment 생성
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
        image: prom/prometheus:v2.40.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=200h'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config-volume
          mountPath: /etc/prometheus/
        - name: prometheus-storage-volume
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config-volume
        configMap:
          defaultMode: 420
          name: prometheus-config
      - name: prometheus-storage-volume
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
EOF

    kubectl apply -f prometheus-deployment.yaml
    
    echo "Prometheus 배포 완료 대기 중..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    
    echo -e "${GREEN}✅ Prometheus 설치 완료${NC}"
fi

# Grafana 설치
echo ""
echo -e "${GREEN}4. Grafana 설치${NC}"
echo "목적: MinIO 메트릭 시각화를 위한 Grafana 대시보드 구성"
echo ""

if kubectl get deployment grafana -n monitoring &>/dev/null; then
    echo -e "${GREEN}✅ Grafana가 이미 설치되어 있습니다${NC}"
else
    echo "Grafana 설치 중..."
    
    # Grafana ConfigMap 생성
    cat > grafana-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |-
    {
        "apiVersion": 1,
        "datasources": [
            {
               "access":"proxy",
                "editable": true,
                "name": "prometheus",
                "orgId": 1,
                "type": "prometheus",
                "url": "http://prometheus:9090",
                "version": 1
            }
        ]
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
data:
  minio-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "MinIO Dashboard",
        "tags": ["minio"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "MinIO Cluster Status",
            "type": "stat",
            "targets": [
              {
                "expr": "minio_cluster_nodes_online_total",
                "legendFormat": "Online Nodes"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Storage Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "(minio_cluster_capacity_usable_total_bytes - minio_cluster_capacity_usable_free_bytes) / minio_cluster_capacity_usable_total_bytes * 100",
                "legendFormat": "Usage %"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(minio_http_requests_total[5m])",
                "legendFormat": "Requests/sec"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "30s"
      }
    }
EOF

    kubectl apply -f grafana-config.yaml
    
    # Grafana Deployment 생성
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
        image: grafana/grafana:9.3.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        volumeMounts:
        - mountPath: /etc/grafana/provisioning/datasources
          name: grafana-datasources
          readOnly: false
        - mountPath: /var/lib/grafana/dashboards
          name: grafana-dashboards
          readOnly: false
      volumes:
      - name: grafana-datasources
        configMap:
          defaultMode: 420
          name: grafana-datasources
      - name: grafana-dashboards
        configMap:
          defaultMode: 420
          name: grafana-dashboards
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
EOF

    kubectl apply -f grafana-deployment.yaml
    
    echo "Grafana 배포 완료 대기 중..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    
    echo -e "${GREEN}✅ Grafana 설치 완료${NC}"
fi

# MinIO 메트릭 활성화
echo ""
echo -e "${GREEN}5. MinIO 메트릭 활성화${NC}"
echo "목적: MinIO 서버에서 Prometheus 메트릭 노출 활성화"
echo ""

echo "MinIO 메트릭 엔드포인트 확인..."
if curl -s http://localhost:9000/minio/v2/metrics/cluster | head -5; then
    echo -e "${GREEN}✅ MinIO 메트릭이 이미 활성화되어 있습니다${NC}"
else
    echo -e "${YELLOW}⚠️  MinIO 메트릭 엔드포인트에 접근할 수 없습니다${NC}"
    echo "포트 포워딩이 설정되어 있는지 확인하세요."
fi

# 포트 포워딩 설정
echo ""
echo -e "${GREEN}6. 모니터링 서비스 포트 포워딩 설정${NC}"
echo "목적: 로컬에서 Prometheus와 Grafana에 접근하기 위한 포트 포워딩"
echo ""

echo "기존 모니터링 포트 포워딩 정리..."
pkill -f "kubectl port-forward.*prometheus" 2>/dev/null || true
pkill -f "kubectl port-forward.*grafana" 2>/dev/null || true

echo "새로운 포트 포워딩 설정..."
kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
PROMETHEUS_PF_PID=$!

kubectl port-forward svc/grafana -n monitoring 3000:3000 &
GRAFANA_PF_PID=$!

echo "포트 포워딩 설정 완료 (Prometheus PID: $PROMETHEUS_PF_PID, Grafana PID: $GRAFANA_PF_PID)"
echo "연결 대기 중..."
sleep 10

# 연결 테스트
echo ""
echo -e "${GREEN}7. 모니터링 시스템 연결 테스트${NC}"
echo ""

echo -e "${BLUE}7-1. Prometheus 연결 테스트${NC}"
echo "URL: http://localhost:9090"
if curl -s http://localhost:9090/-/healthy | grep -q "Prometheus is Healthy"; then
    echo -e "${GREEN}✅ Prometheus 연결 성공${NC}"
else
    echo -e "${YELLOW}⚠️  Prometheus 연결 확인 중... (시간이 더 필요할 수 있습니다)${NC}"
fi

echo ""
echo -e "${BLUE}7-2. Grafana 연결 테스트${NC}"
echo "URL: http://localhost:3000"
echo "Username: admin"
echo "Password: admin"
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo -e "${GREEN}✅ Grafana 연결 성공${NC}"
else
    echo -e "${YELLOW}⚠️  Grafana 연결 확인 중... (시간이 더 필요할 수 있습니다)${NC}"
fi

# MinIO 메트릭 수집 확인
echo ""
echo -e "${GREEN}8. MinIO 메트릭 수집 확인${NC}"
echo ""

echo "Prometheus에서 MinIO 메트릭 수집 상태 확인..."
sleep 5

# 기본 MinIO 메트릭 확인
echo -e "${BLUE}8-1. 기본 MinIO 메트릭 확인${NC}"
if curl -s "http://localhost:9090/api/v1/query?query=minio_cluster_nodes_online_total" | grep -q "success"; then
    echo -e "${GREEN}✅ MinIO 클러스터 메트릭 수집 중${NC}"
    
    # 메트릭 값 표시
    ONLINE_NODES=$(curl -s "http://localhost:9090/api/v1/query?query=minio_cluster_nodes_online_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    echo "   온라인 노드 수: $ONLINE_NODES"
else
    echo -e "${YELLOW}⚠️  MinIO 메트릭 수집이 아직 시작되지 않았습니다${NC}"
    echo "   몇 분 후에 다시 확인해보세요."
fi

# 스토리지 메트릭 확인
echo ""
echo -e "${BLUE}8-2. 스토리지 메트릭 확인${NC}"
if curl -s "http://localhost:9090/api/v1/query?query=minio_cluster_capacity_usable_total_bytes" | grep -q "success"; then
    echo -e "${GREEN}✅ MinIO 스토리지 메트릭 수집 중${NC}"
    
    # 스토리지 정보 표시
    TOTAL_BYTES=$(curl -s "http://localhost:9090/api/v1/query?query=minio_cluster_capacity_usable_total_bytes" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    FREE_BYTES=$(curl -s "http://localhost:9090/api/v1/query?query=minio_cluster_capacity_usable_free_bytes" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    
    if [[ "$TOTAL_BYTES" != "N/A" && "$FREE_BYTES" != "N/A" ]]; then
        USED_BYTES=$((TOTAL_BYTES - FREE_BYTES))
        USAGE_PERCENT=$((USED_BYTES * 100 / TOTAL_BYTES))
        echo "   총 용량: $(numfmt --to=iec $TOTAL_BYTES 2>/dev/null || echo $TOTAL_BYTES bytes)"
        echo "   사용량: $(numfmt --to=iec $USED_BYTES 2>/dev/null || echo $USED_BYTES bytes) (${USAGE_PERCENT}%)"
    fi
else
    echo -e "${YELLOW}⚠️  스토리지 메트릭이 아직 수집되지 않았습니다${NC}"
fi

# 알림 규칙 확인
echo ""
echo -e "${GREEN}9. 알림 규칙 확인${NC}"
echo ""

echo "Prometheus 알림 규칙 상태 확인..."
if curl -s "http://localhost:9090/api/v1/rules" | grep -q "minio"; then
    echo -e "${GREEN}✅ MinIO 알림 규칙이 로드되었습니다${NC}"
    
    # 활성 알림 확인
    ACTIVE_ALERTS=$(curl -s "http://localhost:9090/api/v1/alerts" | jq -r '.data.alerts | length' 2>/dev/null || echo "0")
    echo "   현재 활성 알림: $ACTIVE_ALERTS개"
else
    echo -e "${YELLOW}⚠️  알림 규칙 로드 확인 중...${NC}"
fi

# 대시보드 접근 가이드
echo ""
echo -e "${GREEN}10. 모니터링 대시보드 접근 가이드${NC}"
echo ""

echo -e "${BLUE}📊 Prometheus (메트릭 쿼리 및 알림)${NC}"
echo "   URL: http://localhost:9090"
echo "   주요 기능:"
echo "   - 메트릭 쿼리 및 그래프"
echo "   - 알림 규칙 상태 확인"
echo "   - 타겟 상태 모니터링"
echo ""

echo -e "${BLUE}📈 Grafana (시각화 대시보드)${NC}"
echo "   URL: http://localhost:3000"
echo "   Username: admin"
echo "   Password: admin"
echo "   주요 기능:"
echo "   - MinIO 대시보드 시각화"
echo "   - 실시간 메트릭 모니터링"
echo "   - 알림 설정 및 관리"
echo ""

echo -e "${BLUE}🔍 주요 MinIO 메트릭:${NC}"
echo "   - minio_cluster_nodes_online_total: 온라인 노드 수"
echo "   - minio_cluster_capacity_usable_total_bytes: 총 사용 가능 용량"
echo "   - minio_cluster_capacity_usable_free_bytes: 여유 용량"
echo "   - minio_http_requests_total: HTTP 요청 수"
echo "   - minio_http_requests_duration_seconds: 요청 지연시간"
echo ""

# 정리
echo -e "${GREEN}11. 임시 파일 정리${NC}"
rm -f prometheus-config.yaml prometheus-deployment.yaml grafana-config.yaml grafana-deployment.yaml

echo ""
echo -e "${GREEN}✅ Lab 7 완료${NC}"
echo "MinIO 모니터링 설정이 완료되었습니다."
echo ""
echo -e "${BLUE}📋 완료된 작업 요약:${NC}"
echo "   - ✅ Prometheus 설치 및 MinIO 메트릭 수집 설정"
echo "   - ✅ Grafana 설치 및 대시보드 구성"
echo "   - ✅ MinIO 알림 규칙 설정"
echo "   - ✅ 포트 포워딩으로 모니터링 도구 접근 설정"
echo "   - ✅ 메트릭 수집 상태 확인"
echo ""
echo -e "${BLUE}💡 학습 포인트:${NC}"
echo "   - Prometheus를 통한 메트릭 기반 모니터링"
echo "   - Grafana를 통한 시각화 및 대시보드 구성"
echo "   - MinIO 특화 메트릭 이해 및 활용"
echo "   - 알림 규칙을 통한 사전 장애 감지"
echo ""
echo -e "${GREEN}🚀 다음 단계: Helm Chart 실습 (Lab 8)${NC}"
echo "   명령어: ./lab-08-helm-chart.sh"
echo ""
echo -e "${YELLOW}💡 팁:${NC}"
echo "   - 모니터링 포트 포워딩을 중단하려면: pkill -f 'kubectl port-forward.*prometheus\\|kubectl port-forward.*grafana'"
echo "   - Grafana에서 MinIO 대시보드를 커스터마이징할 수 있습니다"
echo "   - Prometheus에서 PromQL을 사용하여 복잡한 쿼리를 작성할 수 있습니다"
