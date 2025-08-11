# MinIO Kubernetes Lab - 다중 노드 환경 가이드

## 📋 개요

이 가이드는 **다중 노드 Kubernetes 클러스터** 환경에서 MinIO를 배포하고 운영하는 방법을 다룹니다. 프로덕션 환경에 적합한 고가용성 및 확장성을 제공합니다.

### 환경 요구사항
- 3개 이상의 워커 노드 (권장: 4개 이상)
- 각 노드당 최소 8GB RAM, 4 CPU 코어
- 각 노드당 100GB 이상 디스크 여유 공간
- 고성능 네트워크 (10GbE 권장)
- 분산 스토리지 시스템 (Ceph, GlusterFS 등) 또는 클라우드 스토리지

## 🏗️ 아키텍처 설계

### 권장 클러스터 구성
```
Control Plane: 1-3개 노드
Worker Nodes: 4-8개 노드 (MinIO 전용)
Storage: 분산 스토리지 또는 각 노드별 로컬 스토리지
Network: 10GbE 이상, 전용 스토리지 네트워크
```

### MinIO 배포 전략
```
Erasure Coding: EC:4 (8개 드라이브 중 4개 패리티)
Server Pool: 4개 서버 × 2개 드라이브 = 8개 드라이브
Replica: 고가용성을 위한 다중 Operator
```

## 🚀 빠른 시작

### 1단계: 환경 사전 검증

```bash
# 환경 감지 및 검증
./detect-environment.sh
```

### 2단계: 자동 설치 (권장)

```bash
# 다중 노드 환경 자동 설정
./setup-environment.sh
```

### 3단계: 실습 메뉴 실행

```bash
# 통합 실습 메뉴 (다중 노드 환경 자동 감지)
# Lab Guide를 순서대로 따라하며 실습 진행
docs/LAB-00-GUIDE.md  # 환경 사전 검증부터 시작
```

## 📚 단계별 상세 가이드

### Step 1: 클러스터 준비

#### 1-1. 노드 라벨링
```bash
# MinIO 전용 노드 라벨링
kubectl label nodes worker1 worker2 worker3 worker4 minio-node=true

# 라벨 확인
kubectl get nodes --show-labels | grep minio-node
```

#### 1-2. 스토리지 클래스 설정
```bash
# 분산 스토리지 클래스 생성 (예: Ceph RBD)
cat > distributed-storage.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: ceph-cluster
  pool: kubernetes
  imageFeatures: layering
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

kubectl apply -f distributed-storage.yaml
```

#### 1-3. 네트워크 정책 설정
```bash
# MinIO 전용 네트워크 정책
cat > minio-network-policy.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: minio-network-policy
  namespace: minio-tenant
spec:
  podSelector:
    matchLabels:
      app: minio
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: minio
    - namespaceSelector:
        matchLabels:
          name: minio-operator
    ports:
    - protocol: TCP
      port: 9000
    - protocol: TCP
      port: 9001
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: minio
    ports:
    - protocol: TCP
      port: 9000
EOF

kubectl apply -f minio-network-policy.yaml
```

### Step 2: MinIO Operator 설치 (고가용성)

#### 2-1. Operator 설치
```bash
kubectl apply -k "github.com/minio/operator?ref=v5.0.10"
```

#### 2-2. 고가용성 설정
```bash
# Operator를 3개 replica로 설정
kubectl scale deployment minio-operator -n minio-operator --replicas=3

# Anti-Affinity 확인
kubectl get deployment minio-operator -n minio-operator -o yaml | grep -A 10 affinity
```

### Step 3: MinIO Tenant 배포 (분산 모드)

#### 3-1. 네임스페이스 생성
```bash
kubectl create namespace minio-tenant
```

#### 3-2. 인증 시크릿 생성
```bash
# 강력한 비밀번호 사용
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)" \
  -n minio-tenant
```

#### 3-3. Tenant YAML 생성 (다중 노드용)
```yaml
# multi-node-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
  - servers: 4
    name: pool-0
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: fast-ssd
    # 노드 선택 및 분산 배치
    nodeSelector:
      minio-node: "true"
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: v1.min.io/tenant
              operator: In
              values:
              - minio-tenant
          topologyKey: kubernetes.io/hostname
    # 리소스 할당
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
  mountPath: /export
  configuration:
    name: minio-creds-secret
  requestAutoCert: false
  # 보안 설정
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  # 서비스 설정
  services:
    api:
      type: LoadBalancer
    console:
      type: LoadBalancer
  # 모니터링 설정
  prometheusOperator: true
  logging:
    anonymous: false
    json: true
    quiet: false
```

#### 3-4. Tenant 배포
```bash
kubectl apply -f multi-node-tenant.yaml

# 배포 상태 확인
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant -o wide
```

### Step 4: 로드 밸런서 및 Ingress 설정

#### 4-1. LoadBalancer 서비스 확인
```bash
kubectl get svc -n minio-tenant
```

#### 4-2. Ingress 설정 (선택사항)
```yaml
# minio-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minio-ingress
  namespace: minio-tenant
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - minio.example.com
    - console.minio.example.com
    secretName: minio-tls
  rules:
  - host: minio.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 80
  - host: console.minio.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio-tenant-console
            port:
              number: 9001
```

### Step 5: 모니터링 및 알림 설정

#### 5-1. Prometheus 모니터링
```yaml
# minio-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  selector:
    matchLabels:
      app: minio
  endpoints:
  - port: http-minio
    path: /minio/v2/metrics/cluster
    interval: 30s
```

#### 5-2. Grafana 대시보드
```bash
# MinIO 공식 Grafana 대시보드 import
# Dashboard ID: 13502
```

#### 5-3. AlertManager 규칙
```yaml
# minio-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: minio-alerts
  namespace: minio-tenant
spec:
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
```

## 🔧 다중 노드 환경 특화 설정

### 고가용성 설정

#### Erasure Coding 최적화
```yaml
# 8개 드라이브로 EC:4 설정
servers: 4
volumesPerServer: 2
# 총 8개 드라이브, 4개까지 장애 허용
```

#### Pod 분산 배치
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: v1.min.io/tenant
          operator: In
          values:
          - minio-tenant
      topologyKey: kubernetes.io/hostname
```

### 성능 최적화

#### 네트워크 최적화
```yaml
# 전용 네트워크 인터페이스 사용
annotations:
  k8s.v1.cni.cncf.io/networks: storage-network
```

#### 리소스 할당 최적화
```yaml
resources:
  requests:
    memory: "4Gi"      # 메타데이터 캐싱용
    cpu: "2000m"       # 암호화/압축 처리용
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### 보안 강화

#### TLS 설정
```yaml
requestAutoCert: true
externalCertSecret:
  name: minio-tls-secret
  type: kubernetes.io/tls
```

#### RBAC 설정
```yaml
# minio-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: minio-tenant-sa
  namespace: minio-tenant
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: minio-tenant-role
  namespace: minio-tenant
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: minio-tenant-binding
  namespace: minio-tenant
subjects:
- kind: ServiceAccount
  name: minio-tenant-sa
  namespace: minio-tenant
roleRef:
  kind: Role
  name: minio-tenant-role
  apiGroup: rbac.authorization.k8s.io
```

## 📊 성능 테스트 및 벤치마킹

### 대규모 성능 테스트
```bash
# MinIO Client 설치
curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
chmod +x mc

# 클러스터 설정
./mc alias set cluster https://minio.example.com minioadmin <password>

# 대용량 성능 테스트
./mc speed test cluster --size 1GB --duration 300s --concurrent 10

# 다중 클라이언트 테스트
for i in {1..10}; do
  ./mc speed test cluster --size 100MB --duration 60s &
done
wait
```

### 벤치마킹 도구
```bash
# S3 벤치마킹 도구 사용
git clone https://github.com/wasabi-tech/s3-benchmark.git
cd s3-benchmark
go build

# 벤치마크 실행
./s3-benchmark -a minioadmin -s <password> -u https://minio.example.com -b test-bucket -d 300 -t 10 -z 1M
```

## 🔄 운영 및 유지보수

### 확장 (Scale Out)
```bash
# 새로운 서버 풀 추가
kubectl patch tenant minio-tenant -n minio-tenant --type='merge' -p='
{
  "spec": {
    "pools": [
      {
        "servers": 4,
        "name": "pool-1",
        "volumesPerServer": 2,
        "volumeClaimTemplate": {
          "spec": {
            "accessModes": ["ReadWriteOnce"],
            "resources": {"requests": {"storage": "100Gi"}},
            "storageClassName": "fast-ssd"
          }
        }
      }
    ]
  }
}'
```

### 업그레이드
```bash
# 롤링 업데이트
kubectl patch tenant minio-tenant -n minio-tenant --type='merge' -p='
{
  "spec": {
    "image": "minio/minio:RELEASE.2024-03-01T00-00-00Z"
  }
}'

# 업그레이드 상태 확인
kubectl rollout status statefulset/minio-tenant-pool-0 -n minio-tenant
```

### 백업 및 복구
```bash
# 설정 백업
kubectl get tenant minio-tenant -n minio-tenant -o yaml > tenant-backup.yaml
kubectl get secret -n minio-tenant -o yaml > secrets-backup.yaml

# 데이터 백업 (MinIO to MinIO)
./mc mirror cluster/source-bucket backup-cluster/backup-bucket --overwrite
```

## 🚨 장애 대응

### 노드 장애 시나리오
```bash
# 장애 노드 확인
kubectl get nodes
kubectl describe node <failed-node>

# Pod 재스케줄링 확인
kubectl get pods -n minio-tenant -o wide

# 데이터 힐링 상태 확인
./mc admin heal cluster --verbose
```

### 스토리지 장애 시나리오
```bash
# PVC 상태 확인
kubectl get pvc -n minio-tenant

# 스토리지 교체 후 데이터 복구
kubectl delete pvc <failed-pvc> -n minio-tenant
# 새 PVC 자동 생성 후 데이터 자동 복구
```

## 📈 용량 계획

### 스토리지 용량 계산
```
총 스토리지 = 서버 수 × 서버당 볼륨 수 × 볼륨 크기
사용 가능 용량 = 총 스토리지 × 0.5 (EC:4 기준)

예시: 4서버 × 2볼륨 × 100GB = 800GB 총 용량
     사용 가능: 400GB (50% 효율)
```

### 성능 용량 계획
```
예상 IOPS = 서버 수 × 서버당 드라이브 IOPS
예상 처리량 = min(네트워크 대역폭, 스토리지 처리량)
동시 연결 수 = 서버 수 × 서버당 연결 수
```

## 🗑️ 정리

### 단계별 정리
```bash
# 1. Tenant 삭제
kubectl delete tenant minio-tenant -n minio-tenant

# 2. PVC 정리 (데이터 삭제됨 주의!)
kubectl delete pvc --all -n minio-tenant

# 3. 네임스페이스 삭제
kubectl delete namespace minio-tenant

# 4. Operator 삭제
kubectl delete -k "github.com/minio/operator?ref=v5.0.10"

# 5. 스토리지 클래스 정리 (선택사항)
kubectl delete storageclass fast-ssd
```

---

**참고:** 이 가이드는 프로덕션 환경을 위한 설정을 포함합니다. 실제 배포 전에 보안, 네트워크, 스토리지 요구사항을 검토하시기 바랍니다.
