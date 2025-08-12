#!/bin/bash

# MinIO 권장사항 기반 멀티노드 배포 자동화 스크립트
# 이 스크립트는 MinIO 공식 권장사항을 완전히 준수합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 헤더 출력
print_header() {
    echo "=================================================================="
    echo "  MinIO 권장사항 기반 멀티노드 배포 자동화 스크립트"
    echo "  MinIO Official Recommendations Compliant Deployment"
    echo "=================================================================="
    echo ""
}

# Step 1: 환경 검증
validate_environment() {
    log_info "Step 1: 멀티노드 환경 검증 중..."
    
    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # 클러스터 연결 확인
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes 클러스터에 연결할 수 없습니다."
        exit 1
    fi
    
    # 워커 노드 수 확인
    WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)
    log_info "워커 노드 수: $WORKER_COUNT"
    
    if [ $WORKER_COUNT -lt 2 ]; then
        log_error "MinIO 멀티노드 배포를 위해서는 최소 2개의 워커 노드가 필요합니다."
        exit 1
    fi
    
    # 워커 노드 목록 저장
    WORKER_NODES=($(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=":metadata.name"))
    
    log_success "환경 검증 완료 - 워커 노드: ${WORKER_NODES[*]}"
}

# Step 2: MinIO Operator 설치
install_minio_operator() {
    log_info "Step 2: MinIO Operator 설치 중..."
    
    if kubectl get namespace minio-operator &>/dev/null; then
        log_warning "MinIO Operator가 이미 설치되어 있습니다."
    else
        log_info "MinIO Operator 설치 중..."
        kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
        
        log_info "Operator 준비 대기 중... (최대 5분)"
        kubectl wait --for=condition=ready pod -l name=minio-operator -n minio-operator --timeout=300s
        
        log_success "MinIO Operator 설치 완료"
    fi
}

# Step 3: 로컬 스토리지 구성
setup_local_storage() {
    log_info "Step 3: MinIO 권장 로컬 스토리지 구성 중..."
    
    # 워커 노드별 스토리지 디렉토리 생성
    for node in "${WORKER_NODES[@]}"; do
        log_info "노드 $node 스토리지 설정 중..."
        
        if multipass list 2>/dev/null | grep -q "$node"; then
            multipass exec "$node" -- sudo mkdir -p /mnt/minio-storage/disk1 /mnt/minio-storage/disk2
            multipass exec "$node" -- sudo chown -R 1000:1000 /mnt/minio-storage/
            log_success "노드 $node 스토리지 설정 완료"
        else
            log_warning "노드 $node에 직접 접근할 수 없습니다. 수동으로 설정하세요:"
            echo "  sudo mkdir -p /mnt/minio-storage/disk1 /mnt/minio-storage/disk2"
            echo "  sudo chown -R 1000:1000 /mnt/minio-storage/"
        fi
    done
    
    # MinIO 최적화 스토리지 클래스 생성
    log_info "MinIO 최적화 스토리지 클래스 생성 중..."
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    minio.min.io/optimized: "true"
    minio.min.io/storage-type: "local-attached"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: false
parameters:
  fsType: "ext4"
EOF
    
    # Local PV 생성
    log_info "워커 노드별 Local PV 생성 중..."
    for node in "${WORKER_NODES[@]}"; do
        for disk in 1 2; do
            cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-local-pv-${node}-disk${disk}
  labels:
    minio.min.io/node: "${node}"
    minio.min.io/disk: "disk${disk}"
    minio.min.io/storage-type: "local-attached"
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: minio-local-storage
  local:
    path: /mnt/minio-storage/disk${disk}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${node}
EOF
        done
    done
    
    log_success "로컬 스토리지 구성 완료"
}

# Step 4: MinIO Tenant 배포
deploy_minio_tenant() {
    log_info "Step 4: MinIO Tenant 배포 중..."
    
    # 네임스페이스 생성
    kubectl create namespace minio-tenant --dry-run=client -o yaml | kubectl apply -f -
    
    # 인증 시크릿 생성
    MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
    kubectl create secret generic minio-creds-secret \
      --from-literal=config.env="export MINIO_ROOT_USER=minio-admin
export MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
      -n minio-tenant --dry-run=client -o yaml | kubectl apply -f -
    
    # Erasure Coding 설정 계산
    if [ $WORKER_COUNT -ge 6 ]; then
        EC_SETTING="EC:3"
    elif [ $WORKER_COUNT -ge 4 ]; then
        EC_SETTING="EC:2"
    else
        EC_SETTING="EC:1"
    fi
    
    log_info "Erasure Coding 설정: $EC_SETTING"
    
    # MinIO Tenant YAML 생성 및 배포
    cat << EOF | kubectl apply -f -
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
  labels:
    app: minio
    environment: production
    storage-type: local-attached
  annotations:
    minio.min.io/storage-type: "locally-attached"
    minio.min.io/deployment-type: "distributed"
    minio.min.io/erasure-coding: "${EC_SETTING}"
spec:
  configuration:
    name: minio-creds-secret
  
  features:
    bucketDNS: false
    domains: {}
  
  users:
    - name: minio-user
  
  podManagementPolicy: Parallel
  
  pools:
  - name: pool-0
    servers: ${WORKER_COUNT}
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
        labels:
          minio.min.io/storage-type: "local-attached"
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: minio-local-storage
    
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node-role.kubernetes.io/control-plane
              operator: DoesNotExist
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: v1.min.io/tenant
              operator: In
              values:
              - minio-tenant
          topologyKey: kubernetes.io/hostname
    
    resources:
      requests:
        memory: 4Gi
        cpu: 2000m
      limits:
        memory: 8Gi
        cpu: 4000m
    
    env:
    - name: MINIO_STORAGE_CLASS_STANDARD
      value: "${EC_SETTING}"
    - name: MINIO_API_REQUESTS_MAX
      value: "3200"
  
  mountPath: /export
  subPath: /data
  requestAutoCert: false
EOF
    
    log_success "MinIO Tenant 배포 완료"
    
    # 인증 정보 저장
    echo "minio-admin" > /tmp/minio-username
    echo "$MINIO_ROOT_PASSWORD" > /tmp/minio-password
    log_info "인증 정보가 /tmp/minio-username, /tmp/minio-password에 저장되었습니다."
}

# Step 5: 배포 상태 확인
verify_deployment() {
    log_info "Step 5: 배포 상태 확인 중..."
    
    log_info "StatefulSet 준비 대기 중... (최대 10분)"
    kubectl wait --for=condition=ready statefulset/minio-tenant-pool-0 -n minio-tenant --timeout=600s
    
    log_info "모든 Pod 실행 대기 중..."
    kubectl wait --for=condition=ready pod -l v1.min.io/tenant=minio-tenant -n minio-tenant --timeout=600s
    
    log_success "배포 완료!"
    
    # 상태 요약
    echo ""
    echo "=== 배포 상태 요약 ==="
    kubectl get tenant -n minio-tenant
    echo ""
    kubectl get pods -n minio-tenant -o wide
    echo ""
    kubectl get services -n minio-tenant
}

# Step 6: 접근 설정
setup_access() {
    log_info "Step 6: 서비스 접근 설정 중..."
    
    # 포트 포워딩 설정
    kubectl port-forward -n minio-tenant svc/minio-tenant-hl 9000:9000 &
    kubectl port-forward -n minio-tenant svc/minio-tenant-console 9001:9090 &
    
    sleep 5
    
    log_success "포트 포워딩 설정 완료"
    
    # 접근 정보 출력
    echo ""
    echo "=================================================================="
    echo "  MinIO 클러스터 배포 완료!"
    echo "=================================================================="
    echo ""
    echo "🌐 접근 정보:"
    echo "  MinIO API:     http://localhost:9000"
    echo "  MinIO Console: http://localhost:9001"
    echo ""
    echo "🔑 인증 정보:"
    echo "  사용자명: $(cat /tmp/minio-username)"
    echo "  패스워드: $(cat /tmp/minio-password)"
    echo ""
    echo "📊 클러스터 정보:"
    echo "  워커 노드 수: $WORKER_COUNT"
    echo "  총 드라이브: $((WORKER_COUNT * 2))개"
    echo "  Erasure Coding: $EC_SETTING"
    echo "  총 용량: $((WORKER_COUNT * 2 * 100))Gi"
    echo "  사용 가능 용량: $((WORKER_COUNT * 100))Gi (50% 효율)"
    echo ""
    echo "🚀 다음 단계:"
    echo "  1. 웹 브라우저에서 http://localhost:9001 접속"
    echo "  2. 위의 인증 정보로 로그인"
    echo "  3. 버킷 생성 및 데이터 업로드 테스트"
    echo ""
    echo "=================================================================="
}

# 메인 실행 함수
main() {
    print_header
    
    validate_environment
    install_minio_operator
    setup_local_storage
    deploy_minio_tenant
    verify_deployment
    setup_access
    
    log_success "MinIO 권장사항 기반 멀티노드 클러스터 배포 완료!"
}

# 스크립트 실행
main "$@"
