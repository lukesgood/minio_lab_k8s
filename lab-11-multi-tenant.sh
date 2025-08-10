#!/bin/bash

# Lab 11: MinIO Multi-Tenant 관리
# 학습 목표: 다중 테넌트 환경 구성, 테넌트 간 격리, 리소스 관리

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로깅 함수
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_concept() {
    echo -e "${CYAN}[CONCEPT]${NC} $1"
}

# 사용자 입력 대기 함수
wait_for_user() {
    echo -e "${YELLOW}계속하려면 Enter를 누르세요...${NC}"
    read -r
}

# 체크포인트 함수
checkpoint() {
    echo -e "\n${GREEN}=== 체크포인트: $1 ===${NC}"
    wait_for_user
}

# 실습 환경 확인
check_prerequisites() {
    log_step "실습 환경 사전 확인"
    
    log_concept "이 실습에서는 다음을 학습합니다:"
    echo "  • 다중 테넌트 아키텍처 이해"
    echo "  • 테넌트별 리소스 격리"
    echo "  • 네임스페이스 기반 분리"
    echo "  • 테넌트별 사용자 및 정책 관리"
    echo "  • 리소스 할당 및 모니터링"
    echo ""
    
    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # MinIO Client 확인
    if ! command -v mc &> /dev/null; then
        log_error "MinIO Client (mc)가 설치되지 않았습니다."
        log_info "Lab 3을 먼저 완료해주세요."
        exit 1
    fi
    
    # MinIO Operator 확인
    if ! kubectl get pods -n minio-operator | grep -q "minio-operator"; then
        log_error "MinIO Operator가 설치되지 않았습니다."
        log_info "Lab 1을 먼저 완료해주세요."
        exit 1
    fi
    
    # 클러스터 리소스 확인
    log_info "클러스터 리소스 확인 중..."
    kubectl top nodes 2>/dev/null || log_warning "메트릭 서버가 설치되지 않았습니다."
    
    log_success "사전 요구사항 확인 완료"
    checkpoint "환경 확인 완료"
}

# Multi-Tenant 아키텍처 설명
explain_multitenant_architecture() {
    log_step "Multi-Tenant 아키텍처 이해"
    
    log_concept "MinIO Multi-Tenant 아키텍처의 핵심 개념:"
    echo "  • 테넌트: 독립적인 MinIO 인스턴스"
    echo "  • 네임스페이스: Kubernetes 리소스 격리"
    echo "  • 리소스 할당: CPU, 메모리, 스토리지 분리"
    echo "  • 네트워크 격리: 테넌트 간 통신 제어"
    echo ""
    
    echo -e "${YELLOW}=== Multi-Tenant 아키텍처 다이어그램 ===${NC}"
    cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Namespace:    │  │   Namespace:    │  │ Namespace:  │ │
│  │   tenant-dev    │  │  tenant-prod    │  │tenant-stage │ │
│  │                 │  │                 │  │             │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │┌──────────┐ │ │
│  │ │MinIO Tenant │ │  │ │MinIO Tenant │ │  ││MinIO     │ │ │
│  │ │   (Dev)     │ │  │ │   (Prod)    │ │  ││Tenant    │ │ │
│  │ │             │ │  │ │             │ │  ││(Staging) │ │ │
│  │ │• 2GB RAM    │ │  │ │• 8GB RAM    │ │  ││• 4GB RAM │ │ │
│  │ │• 1 CPU      │ │  │ │• 4 CPU      │ │  ││• 2 CPU   │ │ │
│  │ │• 10GB Disk  │ │  │ │• 100GB Disk │ │  ││• 50GB    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │└──────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│           │                     │                  │       │
│           ▼                     ▼                  ▼       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Dev Users     │  │   Prod Users    │  │Stage Users  │ │
│  │   & Apps        │  │   & Apps        │  │  & Apps     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
EOF
    
    echo ""
    log_concept "Multi-Tenant의 장점:"
    echo "  • 리소스 효율성: 하드웨어 공유로 비용 절감"
    echo "  • 격리성: 테넌트 간 완전한 데이터 분리"
    echo "  • 확장성: 필요에 따른 테넌트 추가/제거"
    echo "  • 관리 효율성: 중앙 집중식 운영 관리"
    echo ""
    
    checkpoint "Multi-Tenant 아키텍처 이해 완료"
}

# 개발 환경 테넌트 생성
create_dev_tenant() {
    log_step "개발 환경 테넌트 생성"
    
    log_concept "개발 환경용 테넌트 특성:"
    echo "  • 낮은 리소스 할당 (개발/테스트용)"
    echo "  • 빠른 배포 및 삭제 가능"
    echo "  • 개발자 친화적 설정"
    echo ""
    
    # 개발 환경 네임스페이스 생성
    log_info "개발 환경 네임스페이스 생성 중..."
    kubectl create namespace tenant-dev 2>/dev/null || log_warning "네임스페이스가 이미 존재합니다."
    
    # 개발 환경용 시크릿 생성
    log_info "개발 환경용 인증 시크릿 생성 중..."
    kubectl create secret generic dev-minio-creds-secret \
        --from-literal=config.env="export MINIO_ROOT_USER=devadmin
export MINIO_ROOT_PASSWORD=devpassword123" \
        -n tenant-dev 2>/dev/null || log_warning "시크릿이 이미 존재합니다."
    
    # 개발 환경 테넌트 YAML 생성
    log_info "개발 환경 테넌트 설정 파일 생성 중..."
    cat > dev-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: dev-tenant
  namespace: tenant-dev
spec:
  image: quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z
  credsSecret:
    name: dev-minio-creds-secret
  pools:
  - servers: 1
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
            storage: 5Gi
        storageClassName: local-path
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
  requestAutoCert: false
  console:
    image: quay.io/minio/console:v0.22.5
    replicas: 1
    resources:
      requests:
        memory: 256Mi
        cpu: 250m
      limits:
        memory: 512Mi
        cpu: 500m
EOF
    
    # 개발 환경 테넌트 배포
    log_info "개발 환경 테넌트 배포 중..."
    kubectl apply -f dev-tenant.yaml
    
    log_success "개발 환경 테넌트 생성 완료"
    
    # 배포 상태 확인
    log_info "개발 환경 테넌트 배포 상태 확인 중..."
    kubectl get tenant -n tenant-dev
    
    checkpoint "개발 환경 테넌트 생성 완료"
}

# 프로덕션 환경 테넌트 생성
create_prod_tenant() {
    log_step "프로덕션 환경 테넌트 생성"
    
    log_concept "프로덕션 환경용 테넌트 특성:"
    echo "  • 높은 리소스 할당 (안정성 우선)"
    echo "  • 고가용성 설정"
    echo "  • 보안 강화 설정"
    echo "  • 모니터링 및 알림 설정"
    echo ""
    
    # 프로덕션 환경 네임스페이스 생성
    log_info "프로덕션 환경 네임스페이스 생성 중..."
    kubectl create namespace tenant-prod 2>/dev/null || log_warning "네임스페이스가 이미 존재합니다."
    
    # 프로덕션 환경용 시크릿 생성 (강력한 패스워드)
    log_info "프로덕션 환경용 인증 시크릿 생성 중..."
    kubectl create secret generic prod-minio-creds-secret \
        --from-literal=config.env="export MINIO_ROOT_USER=prodadmin
export MINIO_ROOT_PASSWORD=ProdSecurePass2024!" \
        -n tenant-prod 2>/dev/null || log_warning "시크릿이 이미 존재합니다."
    
    # 프로덕션 환경 테넌트 YAML 생성
    log_info "프로덕션 환경 테넌트 설정 파일 생성 중..."
    cat > prod-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: prod-tenant
  namespace: tenant-prod
spec:
  image: quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z
  credsSecret:
    name: prod-minio-creds-secret
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
            storage: 25Gi
        storageClassName: local-path
    resources:
      requests:
        memory: 4Gi
        cpu: 2000m
      limits:
        memory: 8Gi
        cpu: 4000m
  requestAutoCert: false
  console:
    image: quay.io/minio/console:v0.22.5
    replicas: 1
    resources:
      requests:
        memory: 512Mi
        cpu: 500m
      limits:
        memory: 1Gi
        cpu: 1000m
  # 프로덕션 환경 추가 설정
  env:
  - name: MINIO_BROWSER_REDIRECT_URL
    value: "https://prod-console.example.com"
  - name: MINIO_SERVER_URL
    value: "https://prod-api.example.com"
EOF
    
    # 프로덕션 환경 테넌트 배포
    log_info "프로덕션 환경 테넌트 배포 중..."
    kubectl apply -f prod-tenant.yaml
    
    log_success "프로덕션 환경 테넌트 생성 완료"
    
    # 배포 상태 확인
    log_info "프로덕션 환경 테넌트 배포 상태 확인 중..."
    kubectl get tenant -n tenant-prod
    
    checkpoint "프로덕션 환경 테넌트 생성 완료"
}

# 스테이징 환경 테넌트 생성
create_staging_tenant() {
    log_step "스테이징 환경 테넌트 생성"
    
    log_concept "스테이징 환경용 테넌트 특성:"
    echo "  • 중간 수준 리소스 할당"
    echo "  • 프로덕션 환경 시뮬레이션"
    echo "  • 성능 테스트 및 검증용"
    echo ""
    
    # 스테이징 환경 네임스페이스 생성
    log_info "스테이징 환경 네임스페이스 생성 중..."
    kubectl create namespace tenant-staging 2>/dev/null || log_warning "네임스페이스가 이미 존재합니다."
    
    # 스테이징 환경용 시크릿 생성
    log_info "스테이징 환경용 인증 시크릿 생성 중..."
    kubectl create secret generic staging-minio-creds-secret \
        --from-literal=config.env="export MINIO_ROOT_USER=stagingadmin
export MINIO_ROOT_PASSWORD=stagingpass123" \
        -n tenant-staging 2>/dev/null || log_warning "시크릿이 이미 존재합니다."
    
    # 스테이징 환경 테넌트 YAML 생성
    log_info "스테이징 환경 테넌트 설정 파일 생성 중..."
    cat > staging-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: staging-tenant
  namespace: tenant-staging
spec:
  image: quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z
  credsSecret:
    name: staging-minio-creds-secret
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 3
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 15Gi
        storageClassName: local-path
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
  requestAutoCert: false
  console:
    image: quay.io/minio/console:v0.22.5
    replicas: 1
    resources:
      requests:
        memory: 384Mi
        cpu: 375m
      limits:
        memory: 768Mi
        cpu: 750m
EOF
    
    # 스테이징 환경 테넌트 배포
    log_info "스테이징 환경 테넌트 배포 중..."
    kubectl apply -f staging-tenant.yaml
    
    log_success "스테이징 환경 테넌트 생성 완료"
    
    # 배포 상태 확인
    log_info "스테이징 환경 테넌트 배포 상태 확인 중..."
    kubectl get tenant -n tenant-staging
    
# 테넌트 상태 모니터링
monitor_tenants() {
    log_step "테넌트 상태 모니터링"
    
    log_concept "다중 테넌트 환경에서의 모니터링 요소:"
    echo "  • 각 테넌트별 리소스 사용량"
    echo "  • 테넌트 상태 및 가용성"
    echo "  • 네트워크 트래픽 분석"
    echo "  • 스토리지 사용량 추적"
    echo ""
    
    echo -e "${YELLOW}=== 전체 테넌트 현황 ===${NC}"
    
    # 모든 네임스페이스의 테넌트 조회
    log_info "전체 테넌트 목록:"
    kubectl get tenants --all-namespaces
    
    echo ""
    log_info "네임스페이스별 리소스 사용량:"
    
    # 각 테넌트 네임스페이스별 상세 정보
    for namespace in tenant-dev tenant-prod tenant-staging; do
        if kubectl get namespace "$namespace" &>/dev/null; then
            echo ""
            echo -e "${CYAN}=== $namespace 상세 정보 ===${NC}"
            
            # Pod 상태
            echo "Pod 상태:"
            kubectl get pods -n "$namespace" -o wide
            
            # 서비스 상태
            echo ""
            echo "서비스 상태:"
            kubectl get svc -n "$namespace"
            
            # PVC 상태
            echo ""
            echo "스토리지 상태:"
            kubectl get pvc -n "$namespace"
            
            # 리소스 사용량 (메트릭 서버가 있는 경우)
            echo ""
            echo "리소스 사용량:"
            kubectl top pods -n "$namespace" 2>/dev/null || echo "메트릭 서버가 설치되지 않았습니다."
        fi
    done
    
    checkpoint "테넌트 모니터링 완료"
}

# 테넌트별 사용자 및 정책 설정
setup_tenant_users() {
    log_step "테넌트별 사용자 및 정책 설정"
    
    log_concept "테넌트별 사용자 관리 전략:"
    echo "  • 환경별 사용자 분리"
    echo "  • 역할 기반 접근 제어"
    echo "  • 테넌트별 정책 적용"
    echo ""
    
    # 각 테넌트에 대한 포트 포워딩 설정 및 사용자 생성
    log_info "=== 개발 환경 사용자 설정 ==="
    
    # 개발 환경 포트 포워딩 (백그라운드)
    kubectl port-forward svc/dev-tenant-hl -n tenant-dev 9001:9000 > /dev/null 2>&1 &
    DEV_PF_PID=$!
    sleep 3
    
    # 개발 환경 MinIO 클라이언트 설정
    mc alias set dev-minio http://localhost:9001 devadmin devpassword123 2>/dev/null || true
    
    if mc admin info dev-minio > /dev/null 2>&1; then
        log_success "개발 환경 연결 성공"
        
        # 개발 환경 사용자 생성
        log_info "개발 환경 사용자 생성 중..."
        mc admin user add dev-minio developer devpass123 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        mc admin user add dev-minio tester testpass123 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        
        # 개발 환경 정책 생성
        cat > dev-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::dev-*",
        "arn:aws:s3:::dev-*/*"
      ]
    }
  ]
}
EOF
        
        mc admin policy create dev-minio dev-policy dev-policy.json 2>/dev/null || log_warning "정책이 이미 존재합니다."
        mc admin policy attach dev-minio dev-policy --user developer 2>/dev/null || true
        
        # 개발 환경 버킷 생성
        mc mb dev-minio/dev-bucket 2>/dev/null || log_warning "버킷이 이미 존재합니다."
        mc mb dev-minio/dev-test-bucket 2>/dev/null || log_warning "버킷이 이미 존재합니다."
        
        log_success "개발 환경 사용자 설정 완료"
    else
        log_warning "개발 환경 연결 실패"
    fi
    
    # 포트 포워딩 종료
    kill $DEV_PF_PID 2>/dev/null || true
    
    echo ""
    log_info "=== 프로덕션 환경 사용자 설정 ==="
    
    # 프로덕션 환경 포트 포워딩
    kubectl port-forward svc/prod-tenant-hl -n tenant-prod 9002:9000 > /dev/null 2>&1 &
    PROD_PF_PID=$!
    sleep 3
    
    # 프로덕션 환경 MinIO 클라이언트 설정
    mc alias set prod-minio http://localhost:9002 prodadmin 'ProdSecurePass2024!' 2>/dev/null || true
    
    if mc admin info prod-minio > /dev/null 2>&1; then
        log_success "프로덕션 환경 연결 성공"
        
        # 프로덕션 환경 사용자 생성 (더 제한적인 권한)
        log_info "프로덕션 환경 사용자 생성 중..."
        mc admin user add prod-minio produser 'ProdUserPass2024!' 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        mc admin user add prod-minio readonly 'ReadOnlyPass2024!' 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        
        # 프로덕션 환경 정책 생성 (읽기 전용)
        cat > prod-readonly-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::prod-*",
        "arn:aws:s3:::prod-*/*"
      ]
    }
  ]
}
EOF
        
        mc admin policy create prod-minio prod-readonly prod-readonly-policy.json 2>/dev/null || log_warning "정책이 이미 존재합니다."
        mc admin policy attach prod-minio prod-readonly --user readonly 2>/dev/null || true
        
        # 프로덕션 환경 버킷 생성
        mc mb prod-minio/prod-data 2>/dev/null || log_warning "버킷이 이미 존재합니다."
        mc mb prod-minio/prod-backup 2>/dev/null || log_warning "버킷이 이미 존재합니다."
        
        log_success "프로덕션 환경 사용자 설정 완료"
    else
        log_warning "프로덕션 환경 연결 실패"
    fi
    
    # 포트 포워딩 종료
    kill $PROD_PF_PID 2>/dev/null || true
    
    checkpoint "테넌트별 사용자 설정 완료"
}

# 리소스 할당 및 제한 관리
manage_resource_quotas() {
    log_step "리소스 할당 및 제한 관리"
    
    log_concept "Kubernetes ResourceQuota를 통한 테넌트별 리소스 제한:"
    echo "  • CPU 및 메모리 제한"
    echo "  • 스토리지 용량 제한"
    echo "  • Pod 개수 제한"
    echo "  • 서비스 개수 제한"
    echo ""
    
    # 개발 환경 리소스 쿼터
    log_info "개발 환경 리소스 쿼터 설정 중..."
    cat > dev-resource-quota.yaml << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-resource-quota
  namespace: tenant-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    requests.storage: 50Gi
    persistentvolumeclaims: "10"
    pods: "20"
    services: "10"
    secrets: "20"
    configmaps: "20"
EOF
    
    kubectl apply -f dev-resource-quota.yaml
    
    # 프로덕션 환경 리소스 쿼터
    log_info "프로덕션 환경 리소스 쿼터 설정 중..."
    cat > prod-resource-quota.yaml << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-resource-quota
  namespace: tenant-prod
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    requests.storage: 500Gi
    persistentvolumeclaims: "50"
    pods: "100"
    services: "50"
    secrets: "100"
    configmaps: "100"
EOF
    
    kubectl apply -f prod-resource-quota.yaml
    
    # 스테이징 환경 리소스 쿼터
    log_info "스테이징 환경 리소스 쿼터 설정 중..."
    cat > staging-resource-quota.yaml << 'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-resource-quota
  namespace: tenant-staging
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    requests.storage: 200Gi
    persistentvolumeclaims: "30"
    pods: "50"
    services: "30"
    secrets: "50"
    configmaps: "50"
EOF
    
    kubectl apply -f staging-resource-quota.yaml
    
    log_success "리소스 쿼터 설정 완료"
    
    # 리소스 쿼터 상태 확인
    echo ""
    log_info "설정된 리소스 쿼터 확인:"
    for namespace in tenant-dev tenant-prod tenant-staging; do
        echo ""
        echo -e "${CYAN}=== $namespace 리소스 쿼터 ===${NC}"
        kubectl get resourcequota -n "$namespace" -o wide
        kubectl describe resourcequota -n "$namespace"
    done
    
    checkpoint "리소스 할당 관리 완료"
}

# 네트워크 정책 설정 (테넌트 간 격리)
setup_network_policies() {
    log_step "네트워크 정책 설정 (테넌트 간 격리)"
    
    log_concept "네트워크 정책을 통한 테넌트 격리:"
    echo "  • 테넌트 간 네트워크 트래픽 차단"
    echo "  • 필요한 통신만 허용"
    echo "  • 보안 강화"
    echo ""
    
    log_warning "네트워크 정책은 CNI 플러그인이 지원해야 합니다."
    log_info "Calico, Cilium, Weave Net 등에서 지원됩니다."
    
    # 개발 환경 네트워크 정책
    log_info "개발 환경 네트워크 정책 생성 중..."
    cat > dev-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-tenant-isolation
  namespace: tenant-dev
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: tenant-dev
  - from: []
    ports:
    - protocol: TCP
      port: 9000
    - protocol: TCP
      port: 9090
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: tenant-dev
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF
    
    kubectl apply -f dev-network-policy.yaml 2>/dev/null || log_warning "네트워크 정책 적용 실패 (CNI 미지원)"
    
    # 프로덕션 환경 네트워크 정책 (더 엄격)
    log_info "프로덕션 환경 네트워크 정책 생성 중..."
    cat > prod-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prod-tenant-isolation
  namespace: tenant-prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: tenant-prod
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: tenant-prod
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
EOF
    
    kubectl apply -f prod-network-policy.yaml 2>/dev/null || log_warning "네트워크 정책 적용 실패 (CNI 미지원)"
    
    log_success "네트워크 정책 설정 완료"
    checkpoint "네트워크 격리 설정 완료"
}

# 테넌트 간 데이터 이동 테스트
test_tenant_isolation() {
    log_step "테넌트 간 격리 테스트"
    
    log_concept "테넌트 격리 검증 항목:"
    echo "  • 네트워크 접근 제한 확인"
    echo "  • 데이터 접근 권한 확인"
    echo "  • 리소스 사용량 제한 확인"
    echo ""
    
    log_info "=== 테넌트 격리 테스트 시작 ==="
    
    # 각 테넌트에 테스트 데이터 생성
    echo "테스트 데이터 생성 중..."
    echo "Development test data" > dev-test.txt
    echo "Production test data" > prod-test.txt
    echo "Staging test data" > staging-test.txt
    
    # 개발 환경 테스트
    kubectl port-forward svc/dev-tenant-hl -n tenant-dev 9001:9000 > /dev/null 2>&1 &
    DEV_PF_PID=$!
    sleep 3
    
    mc alias set dev-test http://localhost:9001 devadmin devpassword123 2>/dev/null || true
    if mc admin info dev-test > /dev/null 2>&1; then
        mc cp dev-test.txt dev-test/dev-bucket/ 2>/dev/null || true
        log_success "개발 환경 데이터 업로드 성공"
    fi
    kill $DEV_PF_PID 2>/dev/null || true
    
    # 프로덕션 환경 테스트
    kubectl port-forward svc/prod-tenant-hl -n tenant-prod 9002:9000 > /dev/null 2>&1 &
    PROD_PF_PID=$!
    sleep 3
    
    mc alias set prod-test http://localhost:9002 prodadmin 'ProdSecurePass2024!' 2>/dev/null || true
    if mc admin info prod-test > /dev/null 2>&1; then
        mc cp prod-test.txt prod-test/prod-data/ 2>/dev/null || true
        log_success "프로덕션 환경 데이터 업로드 성공"
    fi
    kill $PROD_PF_PID 2>/dev/null || true
    
    # 크로스 테넌트 접근 테스트 (실패해야 정상)
    log_info "크로스 테넌트 접근 테스트 (실패가 정상):"
    
    kubectl port-forward svc/dev-tenant-hl -n tenant-dev 9001:9000 > /dev/null 2>&1 &
    DEV_PF_PID=$!
    sleep 3
    
    # 개발 환경에서 프로덕션 데이터 접근 시도 (실패해야 함)
    if ! mc ls prod-test/prod-data/ 2>/dev/null; then
        log_success "✓ 테넌트 간 격리가 정상적으로 작동합니다"
    else
        log_warning "⚠ 테넌트 간 격리에 문제가 있을 수 있습니다"
    fi
    
    kill $DEV_PF_PID 2>/dev/null || true
    
    # 정리
    rm -f dev-test.txt prod-test.txt staging-test.txt
    
    log_success "테넌트 격리 테스트 완료"
# 실습 정리
cleanup_lab() {
    log_step "실습 환경 정리"
    
    log_concept "Multi-Tenant 실습에서 생성된 리소스들을 정리합니다:"
    echo "  • 테넌트 리소스"
    echo "  • 네임스페이스"
    echo "  • 설정 파일"
    echo ""
    
    read -p "모든 테넌트를 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "테넌트 삭제 중..."
        
        # 각 테넌트 삭제
        kubectl delete tenant dev-tenant -n tenant-dev 2>/dev/null || true
        kubectl delete tenant prod-tenant -n tenant-prod 2>/dev/null || true
        kubectl delete tenant staging-tenant -n tenant-staging 2>/dev/null || true
        
        log_info "네임스페이스 삭제 대기 중..."
        sleep 10
        
        # 네임스페이스 삭제
        kubectl delete namespace tenant-dev 2>/dev/null || true
        kubectl delete namespace tenant-prod 2>/dev/null || true
        kubectl delete namespace tenant-staging 2>/dev/null || true
        
        log_success "테넌트 삭제 완료"
    fi
    
    read -p "생성된 설정 파일들을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "설정 파일 정리 중..."
        rm -f dev-tenant.yaml prod-tenant.yaml staging-tenant.yaml
        rm -f dev-resource-quota.yaml prod-resource-quota.yaml staging-resource-quota.yaml
        rm -f dev-network-policy.yaml prod-network-policy.yaml
        rm -f dev-policy.json prod-readonly-policy.json
        log_success "설정 파일 정리 완료"
    fi
    
    log_success "실습 정리 완료"
}

# Multi-Tenant 관리 스크립트 생성
create_management_scripts() {
    log_step "Multi-Tenant 관리 스크립트 생성"
    
    log_concept "운영 환경에서 사용할 수 있는 관리 스크립트들을 생성합니다:"
    echo "  • 테넌트 상태 모니터링 스크립트"
    echo "  • 리소스 사용량 체크 스크립트"
    echo "  • 테넌트 백업 스크립트"
    echo ""
    
    # 테넌트 모니터링 스크립트
    log_info "테넌트 모니터링 스크립트 생성 중..."
    cat > monitor-tenants.sh << 'EOF'
#!/bin/bash

# MinIO Multi-Tenant 모니터링 스크립트

echo "=== MinIO Multi-Tenant 상태 모니터링 ==="
echo "실행 시간: $(date)"
echo ""

# 전체 테넌트 목록
echo "1. 전체 테넌트 목록:"
kubectl get tenants --all-namespaces -o wide

echo ""
echo "2. 네임스페이스별 상세 정보:"

for namespace in tenant-dev tenant-prod tenant-staging; do
    if kubectl get namespace "$namespace" &>/dev/null; then
        echo ""
        echo "=== $namespace ==="
        
        # Pod 상태
        echo "Pod 상태:"
        kubectl get pods -n "$namespace" --no-headers | while read line; do
            echo "  $line"
        done
        
        # 리소스 사용량
        echo "리소스 사용량:"
        kubectl top pods -n "$namespace" --no-headers 2>/dev/null | while read line; do
            echo "  $line"
        done || echo "  메트릭 서버 없음"
        
        # 스토리지 사용량
        echo "스토리지 사용량:"
        kubectl get pvc -n "$namespace" --no-headers | while read line; do
            echo "  $line"
        done
        
        # 리소스 쿼터 상태
        echo "리소스 쿼터:"
        kubectl get resourcequota -n "$namespace" --no-headers | while read line; do
            echo "  $line"
        done
    fi
done

echo ""
echo "모니터링 완료: $(date)"
EOF
    
    chmod +x monitor-tenants.sh
    
    # 리소스 체크 스크립트
    log_info "리소스 체크 스크립트 생성 중..."
    cat > check-resources.sh << 'EOF'
#!/bin/bash

# MinIO Multi-Tenant 리소스 체크 스크립트

echo "=== MinIO Multi-Tenant 리소스 체크 ==="
echo ""

# 클러스터 전체 리소스
echo "1. 클러스터 전체 리소스:"
kubectl top nodes 2>/dev/null || echo "메트릭 서버가 설치되지 않았습니다."

echo ""
echo "2. 테넌트별 리소스 사용량:"

total_cpu_requests=0
total_memory_requests=0

for namespace in tenant-dev tenant-prod tenant-staging; do
    if kubectl get namespace "$namespace" &>/dev/null; then
        echo ""
        echo "=== $namespace ==="
        
        # 리소스 쿼터 상태
        kubectl describe resourcequota -n "$namespace" 2>/dev/null | grep -E "(Used|Hard)" || echo "리소스 쿼터 없음"
        
        # CPU/메모리 요청량 계산
        cpu_requests=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.containers[*].resources.requests.cpu}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | sed 's/m$//' | awk '{sum+=$1} END {print sum}')
        memory_requests=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].spec.containers[*].resources.requests.memory}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | sed 's/Gi$//' | awk '{sum+=$1} END {print sum}')
        
        echo "CPU 요청량: ${cpu_requests:-0}m"
        echo "메모리 요청량: ${memory_requests:-0}Gi"
    fi
done

echo ""
echo "리소스 체크 완료: $(date)"
EOF
    
    chmod +x check-resources.sh
    
    # 테넌트 백업 스크립트
    log_info "테넌트 백업 스크립트 생성 중..."
    cat > backup-tenants.sh << 'EOF'
#!/bin/bash

# MinIO Multi-Tenant 백업 스크립트

BACKUP_DIR="tenant-backups-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== MinIO Multi-Tenant 백업 ==="
echo "백업 디렉토리: $BACKUP_DIR"
echo ""

# 각 테넌트의 설정 백업
for namespace in tenant-dev tenant-prod tenant-staging; do
    if kubectl get namespace "$namespace" &>/dev/null; then
        echo "백업 중: $namespace"
        
        # 테넌트 리소스 백업
        kubectl get tenant -n "$namespace" -o yaml > "$BACKUP_DIR/${namespace}-tenant.yaml" 2>/dev/null
        
        # 시크릿 백업
        kubectl get secrets -n "$namespace" -o yaml > "$BACKUP_DIR/${namespace}-secrets.yaml" 2>/dev/null
        
        # 서비스 백업
        kubectl get services -n "$namespace" -o yaml > "$BACKUP_DIR/${namespace}-services.yaml" 2>/dev/null
        
        # PVC 백업
        kubectl get pvc -n "$namespace" -o yaml > "$BACKUP_DIR/${namespace}-pvc.yaml" 2>/dev/null
        
        # 리소스 쿼터 백업
        kubectl get resourcequota -n "$namespace" -o yaml > "$BACKUP_DIR/${namespace}-resourcequota.yaml" 2>/dev/null
        
        echo "  ✓ $namespace 백업 완료"
    fi
done

echo ""
echo "백업 완료: $BACKUP_DIR"
echo "백업 파일 목록:"
ls -la "$BACKUP_DIR/"
EOF
    
    chmod +x backup-tenants.sh
    
    log_success "관리 스크립트 생성 완료"
    
    log_info "생성된 관리 스크립트:"
    echo "  • monitor-tenants.sh: 테넌트 상태 모니터링"
    echo "  • check-resources.sh: 리소스 사용량 체크"
    echo "  • backup-tenants.sh: 테넌트 설정 백업"
    
    checkpoint "관리 스크립트 생성 완료"
}

# 실습 요약 및 다음 단계
lab_summary() {
    log_step "Lab 11 실습 요약"
    
    echo -e "${GREEN}=== 학습 완료 내용 ===${NC}"
    echo "✅ Multi-Tenant 아키텍처 이해"
    echo "   • 테넌트별 네임스페이스 분리"
    echo "   • 환경별 리소스 할당 전략"
    echo "   • 테넌트 간 격리 메커니즘"
    echo ""
    echo "✅ 환경별 테넌트 구성"
    echo "   • 개발 환경: 낮은 리소스, 빠른 배포"
    echo "   • 프로덕션 환경: 높은 리소스, 보안 강화"
    echo "   • 스테이징 환경: 중간 수준, 테스트 최적화"
    echo ""
    echo "✅ 리소스 관리 및 제한"
    echo "   • ResourceQuota를 통한 리소스 제한"
    echo "   • 네임스페이스별 격리"
    echo "   • 사용량 모니터링"
    echo ""
    echo "✅ 보안 및 네트워크 격리"
    echo "   • 테넌트별 사용자 관리"
    echo "   • 네트워크 정책 적용"
    echo "   • 접근 권한 제어"
    echo ""
    
    echo -e "${BLUE}=== 핵심 개념 정리 ===${NC}"
    echo "• Multi-Tenancy: 하나의 클러스터에서 여러 독립적인 환경 운영"
    echo "• 리소스 격리: CPU, 메모리, 스토리지, 네트워크 분리"
    echo "• 네임스페이스: Kubernetes 리소스 논리적 분리"
    echo "• ResourceQuota: 리소스 사용량 제한 및 관리"
    echo "• 네트워크 정책: 테넌트 간 네트워크 트래픽 제어"
    echo ""
    
    echo -e "${YELLOW}=== 실무 활용 팁 ===${NC}"
    echo "• 환경별 리소스 할당 전략 수립"
    echo "• 테넌트별 모니터링 및 알림 설정"
    echo "• 자동화된 테넌트 프로비저닝"
    echo "• 비용 추적 및 차지백 시스템"
    echo "• 재해 복구 계획 수립"
    echo ""
    
    echo -e "${PURPLE}=== 다음 단계 권장사항 ===${NC}"
    echo "• 실제 운영 환경에 Multi-Tenant 적용"
    echo "• 고급 보안 설정 (Lab 12)"
    echo "• 고가용성 구성 (Lab 13)"
    echo "• 자동화 및 GitOps 연동"
    echo "• 성능 최적화 및 튜닝"
    echo ""
    
    log_success "Lab 11: Multi-Tenant Management 실습 완료!"
    echo ""
    echo "생성된 관리 스크립트를 활용하여 실제 운영 환경에서"
    echo "효율적인 Multi-Tenant MinIO 클러스터를 운영해보세요."
}

# 메인 함수
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  Lab 11: MinIO Multi-Tenant                 ║"
    echo "║                     Management                               ║"
    echo "║                                                              ║"
    echo "║  학습 목표:                                                  ║"
    echo "║  • 다중 테넌트 아키텍처 구성                                ║"
    echo "║  • 테넌트별 리소스 격리 및 관리                             ║"
    echo "║  • 환경별 사용자 및 정책 설정                               ║"
    echo "║  • 네트워크 격리 및 보안 강화                               ║"
    echo "║                                                              ║"
    echo "║  예상 소요시간: 30-40분                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    wait_for_user
    
    # 실습 단계별 실행
    check_prerequisites
    explain_multitenant_architecture
    create_dev_tenant
    create_prod_tenant
    create_staging_tenant
    
    # 테넌트 배포 완료 대기
    log_info "테넌트 배포 완료 대기 중..."
    sleep 30
    
    monitor_tenants
    setup_tenant_users
    manage_resource_quotas
    setup_network_policies
    test_tenant_isolation
    create_management_scripts
    
    # 실습 완료
    lab_summary
    
    # 정리 옵션
    echo ""
    read -p "실습 환경을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_lab
    else
        log_info "실습 환경이 보존되었습니다."
        log_info "나중에 정리하려면 다음 명령어를 실행하세요:"
        echo "  ./lab-11-multi-tenant.sh cleanup"
    fi
}

# 스크립트 실행
if [ "$1" = "cleanup" ]; then
    cleanup_lab
else
    main
fi
