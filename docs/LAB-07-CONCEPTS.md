# Lab 7: 모니터링 설정 - 핵심 개념 상세 설명

## 📚 개요

Lab 7에서는 MinIO 클러스터의 모니터링 시스템을 구축하면서 Prometheus 메트릭 수집, Grafana 시각화, 그리고 알림 시스템의 핵심 개념을 학습합니다.

## 🏷️ 공식 GitHub 기준 모니터링 정보

### MinIO Operator v7.1.1 모니터링 기능
- **내장 Prometheus 지원**: prometheusOperator 필드 지원
- **공식 메트릭 엔드포인트**: /minio/v2/metrics/cluster
- **공식 어노테이션**: 자동 서비스 디스커버리 지원
- **Grafana 대시보드**: 공식 MinIO 대시보드 제공

### 공식 모니터링 설정 (v7.1.1)
```yaml
# 공식 GitHub 예제의 모니터링 어노테이션
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  annotations:
    prometheus.io/path: /minio/v2/metrics/cluster
    prometheus.io/port: "9000"
    prometheus.io/scrape: "true"
spec:
  # Prometheus Operator 통합 (v7.1.1 신규 기능)
  prometheusOperator: true
```

### 지원하는 메트릭 버전
- **MinIO 서버**: RELEASE.2025-04-08T15-41-24Z 메트릭
- **Prometheus**: v2.40+ 권장
- **Grafana**: v9.0+ 권장

## 🔍 핵심 개념 1: Prometheus 기반 모니터링

### Prometheus 아키텍처

#### 1. Pull 기반 메트릭 수집
```
Prometheus Server → HTTP GET → MinIO /metrics → 메트릭 데이터 수집
```

**전통적인 Push 방식과의 차이:**
```
Push 방식: 애플리케이션 → 메트릭 전송 → 모니터링 서버
Pull 방식: 모니터링 서버 → 메트릭 요청 → 애플리케이션
```

**Pull 방식의 장점:**
- ✅ **중앙 집중식 제어**: Prometheus가 수집 주기와 대상 관리
- ✅ **네트워크 효율성**: 필요한 메트릭만 선택적 수집
- ✅ **장애 격리**: 애플리케이션 장애가 모니터링에 영향 최소화
- ✅ **스케일링 용이**: 새로운 타겟 자동 발견 및 추가

#### 2. 시계열 데이터베이스 (TSDB)
```
메트릭 데이터 구조:
metric_name{label1="value1", label2="value2"} value timestamp

예시:
minio_cluster_nodes_online_total{server="minio-tenant-pool-0-0"} 1 1640995200
```

**시계열 데이터의 특징:**
- **시간 기반 인덱싱**: 시간순으로 데이터 저장
- **압축 효율성**: 유사한 값들의 효율적 압축
- **빠른 범위 쿼리**: 특정 시간 범위 데이터 빠른 조회
- **자동 데이터 보존**: 설정된 기간 후 자동 삭제

### MinIO 메트릭 엔드포인트

#### 1. 클러스터 레벨 메트릭 (/minio/v2/metrics/cluster)
```bash
# 주요 클러스터 메트릭
minio_cluster_nodes_online_total          # 온라인 노드 수
minio_cluster_nodes_offline_total         # 오프라인 노드 수
minio_cluster_capacity_usable_total_bytes # 총 사용 가능 용량
minio_cluster_capacity_usable_free_bytes  # 여유 용량
minio_cluster_read_total                  # 총 읽기 작업 수
minio_cluster_write_total                 # 총 쓰기 작업 수
```

#### 2. 노드 레벨 메트릭 (/minio/v2/metrics/node)
```bash
# 주요 노드 메트릭
minio_node_disk_used_bytes               # 노드별 디스크 사용량
minio_node_disk_total_bytes              # 노드별 총 디스크 용량
minio_node_disk_free_bytes               # 노드별 여유 디스크
minio_node_process_cpu_total_seconds     # CPU 사용 시간
minio_node_process_resident_memory_bytes # 메모리 사용량
```

#### 3. 버킷 레벨 메트릭 (/minio/v2/metrics/bucket)
```bash
# 주요 버킷 메트릭
minio_bucket_usage_total_bytes{bucket="bucket-name"}  # 버킷별 사용량
minio_bucket_objects_count{bucket="bucket-name"}     # 버킷별 객체 수
minio_bucket_requests_total{bucket="bucket-name"}    # 버킷별 요청 수
```

## 🔍 핵심 개념 2: PromQL (Prometheus Query Language)

### 기본 쿼리 구문

#### 1. 즉시 벡터 (Instant Vector)
```promql
# 현재 시점의 메트릭 값
minio_cluster_nodes_online_total

# 레이블 필터링
minio_bucket_usage_total_bytes{bucket="test-bucket"}

# 레이블 매칭 연산자
minio_node_disk_used_bytes{instance=~"minio-.*"}  # 정규식 매칭
```

#### 2. 범위 벡터 (Range Vector)
```promql
# 지난 5분간의 메트릭 데이터
minio_http_requests_total[5m]

# 지난 1시간간의 데이터
minio_cluster_capacity_usable_free_bytes[1h]
```

#### 3. 집계 함수
```promql
# 평균값
avg(minio_node_disk_used_bytes)

# 합계
sum(minio_bucket_usage_total_bytes)

# 최대값
max(minio_http_requests_duration_seconds)

# 그룹별 집계
sum by (bucket) (minio_bucket_usage_total_bytes)
```

### 실용적인 MinIO 쿼리 예시

#### 1. 스토리지 사용률 계산
```promql
# 전체 스토리지 사용률 (%)
(
  minio_cluster_capacity_usable_total_bytes - 
  minio_cluster_capacity_usable_free_bytes
) / minio_cluster_capacity_usable_total_bytes * 100
```

#### 2. 요청 처리율 계산
```promql
# 초당 HTTP 요청 수
rate(minio_http_requests_total[5m])

# 메서드별 요청 처리율
sum by (method) (rate(minio_http_requests_total[5m]))
```

#### 3. 응답 시간 분석
```promql
# 99th 백분위수 응답 시간
histogram_quantile(0.99, 
  rate(minio_http_requests_duration_seconds_bucket[5m])
)

# 평균 응답 시간
rate(minio_http_requests_duration_seconds_sum[5m]) /
rate(minio_http_requests_duration_seconds_count[5m])
```

## 🔍 핵심 개념 3: Grafana 시각화

### 대시보드 구성 요소

#### 1. 패널 타입별 활용

##### Stat 패널 (단일 값 표시)
```json
{
  "type": "stat",
  "targets": [
    {
      "expr": "minio_cluster_nodes_online_total",
      "legendFormat": "Online Nodes"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "color": {
        "mode": "thresholds"
      },
      "thresholds": {
        "steps": [
          {"color": "red", "value": 0},
          {"color": "green", "value": 1}
        ]
      }
    }
  }
}
```

**사용 사례:**
- 현재 온라인 노드 수
- 전체 스토리지 사용률
- 활성 연결 수

##### Graph 패널 (시계열 그래프)
```json
{
  "type": "graph",
  "targets": [
    {
      "expr": "rate(minio_http_requests_total[5m])",
      "legendFormat": "{{method}} requests/sec"
    }
  ],
  "yAxes": [
    {
      "label": "Requests per second",
      "min": 0
    }
  ]
}
```

**사용 사례:**
- 시간별 요청 처리량
- 스토리지 사용량 추이
- 응답 시간 변화

##### Heatmap 패널 (분포 시각화)
```json
{
  "type": "heatmap",
  "targets": [
    {
      "expr": "rate(minio_http_requests_duration_seconds_bucket[5m])",
      "format": "heatmap",
      "legendFormat": "{{le}}"
    }
  ]
}
```

**사용 사례:**
- 응답 시간 분포
- 요청 크기 분포
- 에러율 분포

#### 2. 변수 (Variables) 활용
```json
{
  "templating": {
    "list": [
      {
        "name": "instance",
        "type": "query",
        "query": "label_values(minio_cluster_nodes_online_total, instance)",
        "refresh": 1
      },
      {
        "name": "bucket",
        "type": "query", 
        "query": "label_values(minio_bucket_usage_total_bytes, bucket)",
        "refresh": 2
      }
    ]
  }
}
```

**변수 사용 예시:**
```promql
# 선택된 인스턴스의 메트릭
minio_node_disk_used_bytes{instance="$instance"}

# 선택된 버킷의 메트릭
minio_bucket_usage_total_bytes{bucket="$bucket"}
```

### 대시보드 설계 모범 사례

#### 1. 계층적 정보 구성
```
상단: 전체 클러스터 상태 (Stat 패널)
├── 온라인 노드 수
├── 전체 스토리지 사용률
└── 현재 활성 연결 수

중간: 시계열 트렌드 (Graph 패널)
├── 요청 처리량 추이
├── 응답 시간 추이
└── 스토리지 사용량 추이

하단: 상세 분석 (Table, Heatmap 패널)
├── 노드별 상세 메트릭
├── 버킷별 사용량 분석
└── 에러율 분석
```

#### 2. 색상 및 임계값 설정
```json
{
  "thresholds": {
    "steps": [
      {"color": "green", "value": null},      // 정상 (0-80%)
      {"color": "yellow", "value": 80},       // 주의 (80-90%)
      {"color": "red", "value": 90}           // 위험 (90%+)
    ]
  }
}
```

## 🔍 핵심 개념 4: 알림 시스템 (Alerting)

### Prometheus 알림 규칙

#### 1. 알림 규칙 구조
```yaml
groups:
- name: minio-alerts
  rules:
  - alert: MinIONodeDown
    expr: minio_cluster_nodes_offline_total > 0
    for: 5m
    labels:
      severity: critical
      service: minio
    annotations:
      summary: "MinIO node is down"
      description: "{{ $value }} MinIO nodes are offline for more than 5 minutes"
```

**구성 요소 설명:**
- **alert**: 알림 규칙 이름
- **expr**: PromQL 표현식 (조건)
- **for**: 조건 지속 시간
- **labels**: 알림 분류용 레이블
- **annotations**: 알림 메시지 템플릿

#### 2. 실용적인 MinIO 알림 규칙

##### 노드 장애 감지
```yaml
- alert: MinIONodeDown
  expr: minio_cluster_nodes_offline_total > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "MinIO cluster has offline nodes"
    description: "{{ $value }} nodes have been offline for more than 5 minutes"
```

##### 스토리지 용량 경고
```yaml
- alert: MinIODiskUsageHigh
  expr: |
    (
      minio_cluster_capacity_usable_total_bytes - 
      minio_cluster_capacity_usable_free_bytes
    ) / minio_cluster_capacity_usable_total_bytes > 0.8
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "MinIO disk usage is high"
    description: "Disk usage is {{ $value | humanizePercentage }} (>80%)"
```

##### 높은 응답 지연시간
```yaml
- alert: MinIOHighLatency
  expr: |
    histogram_quantile(0.99, 
      rate(minio_http_requests_duration_seconds_bucket[5m])
    ) > 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "MinIO high request latency"
    description: "99th percentile latency is {{ $value }}s (>1s)"
```

##### 에러율 증가
```yaml
- alert: MinIOHighErrorRate
  expr: |
    rate(minio_http_requests_total{code!~"2.."}[5m]) /
    rate(minio_http_requests_total[5m]) > 0.05
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "MinIO high error rate"
    description: "Error rate is {{ $value | humanizePercentage }} (>5%)"
```

### 알림 라우팅 및 억제

#### 1. Alertmanager 설정
```yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@company.com'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
  - match:
      severity: warning
    receiver: 'warning-alerts'

receivers:
- name: 'default'
  email_configs:
  - to: 'admin@company.com'
    subject: 'MinIO Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}

- name: 'critical-alerts'
  email_configs:
  - to: 'oncall@company.com'
    subject: 'CRITICAL: MinIO Alert'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/...'
    channel: '#alerts'
    title: 'Critical MinIO Alert'
```

#### 2. 알림 억제 (Inhibition)
```yaml
inhibit_rules:
- source_match:
    alertname: 'MinIONodeDown'
  target_match:
    alertname: 'MinIODiskUsageHigh'
  equal: ['instance']
```

**억제 규칙의 목적:**
- 근본 원인 알림이 발생하면 관련 증상 알림 억제
- 알림 폭주 방지
- 운영자의 집중도 향상

## 🔍 핵심 개념 5: 메트릭 기반 운영

### SLI/SLO 정의

#### 1. Service Level Indicators (SLI)
```promql
# 가용성 SLI
sum(rate(minio_http_requests_total{code=~"2.."}[5m])) /
sum(rate(minio_http_requests_total[5m]))

# 지연시간 SLI  
histogram_quantile(0.95, 
  rate(minio_http_requests_duration_seconds_bucket[5m])
)

# 처리량 SLI
sum(rate(minio_http_requests_total[5m]))
```

#### 2. Service Level Objectives (SLO)
```yaml
# SLO 정의 예시
slos:
  availability:
    target: 99.9%    # 99.9% 가용성
    window: 30d      # 30일 기준
  
  latency:
    target: 95%      # 95%의 요청이
    threshold: 500ms # 500ms 이내 응답
    window: 7d       # 7일 기준
  
  throughput:
    target: 1000     # 초당 1000 요청 처리
    window: 1h       # 1시간 기준
```

### 용량 계획 (Capacity Planning)

#### 1. 성장 추세 분석
```promql
# 스토리지 사용량 증가율 (일일)
increase(minio_cluster_capacity_usable_total_bytes - 
         minio_cluster_capacity_usable_free_bytes[1d])

# 요청량 증가율 (주간)
increase(minio_http_requests_total[7d])
```

#### 2. 예측 모델링
```promql
# 선형 회귀를 통한 용량 예측
predict_linear(
  minio_cluster_capacity_usable_total_bytes - 
  minio_cluster_capacity_usable_free_bytes[7d], 
  86400 * 30  # 30일 후 예측
)
```

### 성능 최적화 지표

#### 1. 병목 지점 식별
```promql
# CPU 사용률
rate(minio_node_process_cpu_total_seconds[5m]) * 100

# 메모리 사용률
minio_node_process_resident_memory_bytes / 
minio_node_process_virtual_memory_max_bytes * 100

# 디스크 I/O 대기시간
rate(minio_node_disk_io_time_seconds_total[5m])
```

#### 2. 캐시 효율성
```promql
# 캐시 히트율
minio_cache_hits_total / 
(minio_cache_hits_total + minio_cache_misses_total) * 100
```

## 🎯 실습에서 확인할 수 있는 것들

### 1. Prometheus 메트릭 수집 확인
```bash
# MinIO 메트릭 엔드포인트 직접 확인
curl http://localhost:9000/minio/v2/metrics/cluster

# Prometheus에서 메트릭 쿼리
curl "http://localhost:9090/api/v1/query?query=minio_cluster_nodes_online_total"
```

### 2. Grafana 대시보드 구성
- 실시간 메트릭 시각화
- 커스텀 패널 생성
- 알림 임계값 설정
- 변수를 통한 동적 필터링

### 3. 알림 규칙 테스트
```bash
# 의도적으로 높은 부하 생성하여 알림 트리거
for i in {1..100}; do
  mc cp large-file.dat local/test-bucket/file-$i.dat &
done
```

## 🚨 일반적인 문제와 해결 방법

### 1. 메트릭 수집 실패
**원인:** MinIO 메트릭 엔드포인트 접근 불가
```bash
# 해결 방법: 포트 포워딩 확인
kubectl port-forward svc/minio -n minio-tenant 9000:80

# 메트릭 엔드포인트 테스트
curl http://localhost:9000/minio/v2/metrics/cluster
```

### 2. Grafana 대시보드 데이터 없음
**원인:** Prometheus 데이터소스 설정 오류
```bash
# Prometheus 연결 확인
curl http://localhost:9090/-/healthy

# Grafana 데이터소스 테스트
curl -u admin:admin http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up
```

### 3. 알림이 발생하지 않음
**원인:** 알림 규칙 문법 오류 또는 조건 미충족
```bash
# 알림 규칙 상태 확인
curl http://localhost:9090/api/v1/rules

# 활성 알림 확인
curl http://localhost:9090/api/v1/alerts
```

## 📖 추가 학습 자료

### 공식 문서
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [MinIO Monitoring Guide](https://min.io/docs/minio/linux/operations/monitoring.html)

### 실습 명령어
```bash
# 모니터링 설정 실행
./lab-07-monitoring.sh

# Prometheus 쿼리 테스트
curl "http://localhost:9090/api/v1/query?query=minio_cluster_nodes_online_total"

# Grafana API 테스트
curl -u admin:admin http://localhost:3000/api/health
```

이 개념들을 이해하면 MinIO 클러스터의 완전한 모니터링 시스템을 구축하고 운영할 수 있습니다.
