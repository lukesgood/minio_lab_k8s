## Step 3: MinIO 권장사항 기반 Tenant 배포

### 💡 개념 설명

MinIO 공식 권장사항을 완전히 준수한 프로덕션급 Tenant를 배포합니다.

### 🔑 네임스페이스 및 인증 설정

```bash
echo "=== MinIO Tenant 네임스페이스 및 인증 설정 ==="

# 전용 네임스페이스 생성
kubectl create namespace minio-tenant

# 강력한 인증 정보 설정 (프로덕션 환경)
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=minio-admin
export MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)" \
  -n minio-tenant

echo "✅ 네임스페이스 및 인증 설정 완료"
```

### 🏗️ MinIO 권장사항 기반 Tenant YAML 생성

```bash
echo "=== MinIO 권장사항 기반 Tenant 설정 생성 ==="

# 워커 노드 수 확인
WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)

# Erasure Coding 설정 계산
if [ $WORKER_COUNT -ge 6 ]; then
    EC_SETTING="EC:3"
    echo "6개 이상 노드: EC:3 설정 (고가용성)"
elif [ $WORKER_COUNT -ge 4 ]; then
    EC_SETTING="EC:2"
    echo "4-5개 노드: EC:2 설정 (균형)"
else
    EC_SETTING="EC:1"
    echo "3개 노드: EC:1 설정 (최소)"
fi

cat << EOF > minio-tenant-production.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
  labels:
    app: minio
    environment: production
    storage-type: local-attached
    deployment-type: distributed
  annotations:
    # MinIO 권장사항 준수 어노테이션
    minio.min.io/storage-type: "locally-attached"
    minio.min.io/deployment-type: "distributed"
    minio.min.io/performance-tier: "high"
    minio.min.io/erasure-coding: "${EC_SETTING}"
    prometheus.io/path: /minio/v2/metrics/cluster
    prometheus.io/port: "9000"
    prometheus.io/scrape: "true"
spec:
  ## 인증 설정
  configuration:
    name: minio-creds-secret
  
  ## 기능 설정
  features:
    bucketDNS: false
    domains: {}
    enableSFTP: false
  
  ## 사용자 설정
  users:
    - name: minio-user
  
  ## Pod 관리 정책
  podManagementPolicy: Parallel
  
  ## 프로덕션 풀 설정
  pools:
  - name: pool-0
    servers: ${WORKER_COUNT}              # 워커 노드 수와 일치
    volumesPerServer: 2                   # 노드당 2개 볼륨 (MinIO 권장)
    volumeClaimTemplate:
      metadata:
        name: data
        labels:
          minio.min.io/storage-type: "local-attached"
          minio.min.io/performance-tier: "high"
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi              # Local PV 크기와 일치
        storageClassName: minio-local-storage
    
    ## MinIO 권장: 워커 노드 전용 배포
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            # Control Plane 노드 제외
            - key: node-role.kubernetes.io/control-plane
              operator: DoesNotExist
      ## MinIO 권장: 노드별 분산 배치 (고가용성)
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: v1.min.io/tenant
              operator: In
              values:
              - minio-tenant
          topologyKey: kubernetes.io/hostname
    
    ## 프로덕션 리소스 설정 (MinIO 권장)
    resources:
      requests:
        memory: 8Gi                     # 최소 8GB
        cpu: 4000m                      # 최소 4 코어
      limits:
        memory: 16Gi                    # 최대 16GB
        cpu: 8000m                      # 최대 8 코어
    
    ## MinIO 성능 최적화 환경 변수
    env:
    - name: MINIO_STORAGE_CLASS_STANDARD
      value: "${EC_SETTING}"
    - name: MINIO_API_REQUESTS_MAX
      value: "3200"                     # 고성능 설정
    - name: MINIO_API_REQUESTS_DEADLINE
      value: "10s"
    - name: MINIO_CACHE_DRIVES
      value: "2"                        # 캐시 드라이브 수
    - name: MINIO_CACHE_EXCLUDE
      value: "*.tmp"
    # 성능 최적화 설정
    - name: MINIO_API_CORS_ALLOW_ORIGIN
      value: "*"
    - name: MINIO_PROMETHEUS_AUTH_TYPE
      value: "public"
  
  ## 마운트 경로 설정
  mountPath: /export
  subPath: /data
  
  ## 보안 설정 (내부 네트워크)
  requestAutoCert: false
  
  ## 서비스 메타데이터 (모니터링 및 관리)
  serviceMetadata:
    minioServiceLabels:
      minio.min.io/storage-type: "local-attached"
      minio.min.io/performance-tier: "high"
      minio.min.io/deployment-type: "production"
    minioServiceAnnotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    consoleServiceLabels:
      minio.min.io/storage-type: "local-attached"
      minio.min.io/performance-tier: "high"
    consoleServiceAnnotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  
  ## 로그 설정
  logging:
    anonymous: false
    json: true
    quiet: false
  
  ## 추가 보안 설정
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    fsGroup: 1000
EOF

echo "✅ MinIO 권장사항 기반 Tenant 설정 생성 완료"
echo "설정 파일: minio-tenant-production.yaml"
echo "워커 노드 수: ${WORKER_COUNT}"
echo "Erasure Coding: ${EC_SETTING}"
```

### 🔍 배포 전 설정 검증

```bash
echo "=== 배포 전 설정 검증 ==="

# 1. YAML 파일 구문 검증
echo "1. YAML 구문 검증:"
kubectl apply --dry-run=client -f minio-tenant-production.yaml

# 2. 리소스 요구사항 확인
echo -e "\n2. 리소스 요구사항:"
echo "총 CPU 요청: $((WORKER_COUNT * 4)) 코어"
echo "총 메모리 요청: $((WORKER_COUNT * 8))Gi"
echo "총 스토리지: $((WORKER_COUNT * 2 * 100))Gi"

# 3. 네임스페이스 및 시크릿 확인
echo -e "\n3. 사전 요구사항 확인:"
kubectl get namespace minio-tenant
kubectl get secret minio-creds-secret -n minio-tenant

# 4. 사용 가능한 PV 확인
echo -e "\n4. 사용 가능한 PV:"
available_pvs=$(kubectl get pv -l minio.min.io/storage-type=local-attached --no-headers | grep Available | wc -l)
required_pvs=$((WORKER_COUNT * 2))
echo "필요한 PV: ${required_pvs}개"
echo "사용 가능한 PV: ${available_pvs}개"

if [ $available_pvs -ge $required_pvs ]; then
    echo "✅ 충분한 PV 사용 가능"
else
    echo "❌ PV 부족: $((required_pvs - available_pvs))개 추가 필요"
fi
```

### 🛑 체크포인트
- [ ] 네임스페이스 및 인증 시크릿 생성
- [ ] MinIO 권장사항 기반 Tenant YAML 생성
- [ ] 리소스 요구사항 확인
- [ ] 충분한 PV 사용 가능 확인
