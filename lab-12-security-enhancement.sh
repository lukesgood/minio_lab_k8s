#!/bin/bash

# Lab 12: MinIO 보안 강화
# 학습 목표: TLS/SSL 설정, 인증서 관리, 고급 보안 정책

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
    echo "  • TLS/SSL 인증서 생성 및 관리"
    echo "  • MinIO HTTPS 설정"
    echo "  • 고급 인증 및 권한 관리"
    echo "  • 보안 정책 및 감사 로그"
    echo "  • 네트워크 보안 강화"
    echo ""
    
    # 필수 도구 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        log_error "openssl이 설치되지 않았습니다."
        exit 1
    fi
    
    if ! command -v mc &> /dev/null; then
        log_error "MinIO Client (mc)가 설치되지 않았습니다."
        exit 1
    fi
    
    # MinIO Operator 확인
    if ! kubectl get pods -n minio-operator | grep -q "minio-operator"; then
        log_error "MinIO Operator가 설치되지 않았습니다."
        log_info "Lab 1을 먼저 완료해주세요."
        exit 1
    fi
    
    log_success "사전 요구사항 확인 완료"
    checkpoint "환경 확인 완료"
}

# 보안 아키텍처 설명
explain_security_architecture() {
    log_step "MinIO 보안 아키텍처 이해"
    
    log_concept "MinIO 보안의 핵심 구성 요소:"
    echo "  • 전송 계층 보안 (TLS/SSL)"
    echo "  • 인증 및 권한 관리 (IAM)"
    echo "  • 데이터 암호화 (저장 시/전송 시)"
    echo "  • 감사 로그 및 모니터링"
    echo "  • 네트워크 보안 정책"
    echo ""
    
    echo -e "${YELLOW}=== MinIO 보안 아키텍처 다이어그램 ===${NC}"
    cat << 'EOF'
┌─────────────────────────────────────────────────────────────┐
│                    보안 계층 구조                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Application Layer                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Client    │  │    Web      │  │   Admin     │     │ │
│  │  │    Apps     │  │  Console    │  │   Tools     │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Network Security Layer                     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │    TLS      │  │  Network    │  │  Firewall   │     │ │
│  │  │ Encryption  │  │  Policies   │  │   Rules     │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Authentication & Authorization               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │    IAM      │  │   RBAC      │  │   Policies  │     │ │
│  │  │   Users     │  │   Roles     │  │   & ACLs    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Data Protection Layer                      │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │ Encryption  │  │   Audit     │  │   Backup    │     │ │
│  │  │  at Rest    │  │   Logs      │  │ & Recovery  │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
EOF
    
    echo ""
    log_concept "보안 강화의 핵심 원칙:"
    echo "  • 최소 권한 원칙 (Principle of Least Privilege)"
    echo "  • 심층 방어 (Defense in Depth)"
    echo "  • 제로 트러스트 (Zero Trust)"
    echo "  • 지속적인 모니터링 (Continuous Monitoring)"
    echo ""
    
    checkpoint "보안 아키텍처 이해 완료"
}

# TLS 인증서 생성
create_tls_certificates() {
    log_step "TLS 인증서 생성"
    
    log_concept "TLS 인증서의 역할:"
    echo "  • 데이터 전송 암호화"
    echo "  • 서버 신원 확인"
    echo "  • 중간자 공격 방지"
    echo "  • 클라이언트-서버 간 신뢰 구축"
    echo ""
    
    # 인증서 디렉토리 생성
    mkdir -p tls-certs
    cd tls-certs
    
    # CA (Certificate Authority) 생성
    log_info "CA (Certificate Authority) 생성 중..."
    
    # CA 개인키 생성
    openssl genrsa -out ca-key.pem 4096
    
    # CA 인증서 생성
    cat > ca-config.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = KR
ST = Seoul
L = Seoul
O = MinIO Lab
OU = IT Department
CN = MinIO Lab CA

[v3_ca]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
EOF
    
    openssl req -new -x509 -days 365 -key ca-key.pem -out ca-cert.pem -config ca-config.conf
    
    log_success "CA 인증서 생성 완료"
    
    # MinIO 서버 인증서 생성
    log_info "MinIO 서버 인증서 생성 중..."
    
    # 서버 개인키 생성
    openssl genrsa -out server-key.pem 4096
    
    # 서버 인증서 요청 생성
    cat > server-config.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = KR
ST = Seoul
L = Seoul
O = MinIO Lab
OU = IT Department
CN = minio.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = minio.local
DNS.2 = *.minio.local
DNS.3 = localhost
DNS.4 = *.minio-tenant.svc.cluster.local
DNS.5 = minio-tenant-hl.minio-tenant.svc.cluster.local
IP.1 = 127.0.0.1
IP.2 = 10.96.0.1
EOF
    
    openssl req -new -key server-key.pem -out server-csr.pem -config server-config.conf
    
    # CA로 서버 인증서 서명
    openssl x509 -req -in server-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365 -extensions v3_req -extfile server-config.conf
    
    log_success "MinIO 서버 인증서 생성 완료"
    
    # 클라이언트 인증서 생성 (상호 TLS용)
    log_info "클라이언트 인증서 생성 중..."
    
    # 클라이언트 개인키 생성
    openssl genrsa -out client-key.pem 4096
    
    # 클라이언트 인증서 요청 생성
    cat > client-config.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = KR
ST = Seoul
L = Seoul
O = MinIO Lab
OU = IT Department
CN = minio-client

[v3_req]
basicConstraints = CA:FALSE
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = clientAuth
EOF
    
    openssl req -new -key client-key.pem -out client-csr.pem -config client-config.conf
    
    # CA로 클라이언트 인증서 서명
    openssl x509 -req -in client-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365 -extensions v3_req -extfile client-config.conf
    
    log_success "클라이언트 인증서 생성 완료"
    
    # 인증서 정보 확인
    log_info "생성된 인증서 정보:"
    echo "CA 인증서:"
    openssl x509 -in ca-cert.pem -text -noout | grep -E "(Subject:|Not After)"
    echo ""
    echo "서버 인증서:"
    openssl x509 -in server-cert.pem -text -noout | grep -E "(Subject:|Not After|DNS:|IP Address)"
    echo ""
    echo "클라이언트 인증서:"
    openssl x509 -in client-cert.pem -text -noout | grep -E "(Subject:|Not After)"
    
    cd ..
    
    checkpoint "TLS 인증서 생성 완료"
}

# Kubernetes Secret으로 인증서 저장
create_tls_secrets() {
    log_step "Kubernetes Secret으로 인증서 저장"
    
    log_concept "Kubernetes Secret을 통한 인증서 관리:"
    echo "  • 안전한 인증서 저장"
    echo "  • Pod에 자동 마운트"
    echo "  • 인증서 로테이션 지원"
    echo ""
    
    # 보안 네임스페이스 생성
    kubectl create namespace minio-secure 2>/dev/null || log_warning "네임스페이스가 이미 존재합니다."
    
    # TLS 인증서 Secret 생성
    log_info "TLS 인증서 Secret 생성 중..."
    kubectl create secret tls minio-tls-secret \
        --cert=tls-certs/server-cert.pem \
        --key=tls-certs/server-key.pem \
        -n minio-secure 2>/dev/null || log_warning "Secret이 이미 존재합니다."
    
    # CA 인증서 Secret 생성
    log_info "CA 인증서 Secret 생성 중..."
    kubectl create secret generic minio-ca-secret \
        --from-file=ca.crt=tls-certs/ca-cert.pem \
        -n minio-secure 2>/dev/null || log_warning "Secret이 이미 존재합니다."
    
    # 클라이언트 인증서 Secret 생성
    log_info "클라이언트 인증서 Secret 생성 중..."
    kubectl create secret generic minio-client-secret \
        --from-file=client.crt=tls-certs/client-cert.pem \
        --from-file=client.key=tls-certs/client-key.pem \
        -n minio-secure 2>/dev/null || log_warning "Secret이 이미 존재합니다."
    
    # MinIO 인증 정보 Secret 생성
    log_info "MinIO 인증 정보 Secret 생성 중..."
    kubectl create secret generic secure-minio-creds-secret \
        --from-literal=config.env="export MINIO_ROOT_USER=secureadmin
export MINIO_ROOT_PASSWORD=SecurePassword2024!" \
        -n minio-secure 2>/dev/null || log_warning "Secret이 이미 존재합니다."
    
    log_success "Kubernetes Secret 생성 완료"
    
    # Secret 확인
    log_info "생성된 Secret 목록:"
    kubectl get secrets -n minio-secure
    
# 보안 강화된 MinIO 테넌트 배포
deploy_secure_tenant() {
    log_step "보안 강화된 MinIO 테넌트 배포"
    
    log_concept "보안 강화 테넌트의 특징:"
    echo "  • TLS/SSL 암호화 활성화"
    echo "  • 강력한 인증 정책"
    echo "  • 네트워크 보안 정책 적용"
    echo "  • 감사 로그 활성화"
    echo ""
    
    # 보안 강화 테넌트 YAML 생성
    log_info "보안 강화 테넌트 설정 파일 생성 중..."
    cat > secure-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: secure-tenant
  namespace: minio-secure
spec:
  image: quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z
  credsSecret:
    name: secure-minio-creds-secret
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
            storage: 10Gi
        storageClassName: local-path
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
  # TLS 설정
  requestAutoCert: false
  externalCertSecret:
  - name: minio-tls-secret
    type: kubernetes.io/tls
  # Console 설정
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
    externalCertSecret:
      name: minio-tls-secret
      type: kubernetes.io/tls
  # 보안 환경 변수
  env:
  - name: MINIO_AUDIT_WEBHOOK_ENABLE_target1
    value: "on"
  - name: MINIO_AUDIT_WEBHOOK_ENDPOINT_target1
    value: "http://audit-service:8080/audit"
  - name: MINIO_AUDIT_WEBHOOK_AUTH_TOKEN_target1
    value: "audit-token-123"
  - name: MINIO_API_SECURE
    value: "true"
  - name: MINIO_CONSOLE_SECURE
    value: "true"
  # 보안 정책
  - name: MINIO_IDENTITY_OPENID_CONFIG_URL
    value: ""
  - name: MINIO_IDENTITY_OPENID_CLIENT_ID
    value: ""
  # 암호화 설정
  - name: MINIO_KMS_AUTO_ENCRYPTION
    value: "on"
EOF
    
    # 보안 테넌트 배포
    log_info "보안 강화 테넌트 배포 중..."
    kubectl apply -f secure-tenant.yaml
    
    log_success "보안 강화 테넌트 배포 완료"
    
    # 배포 상태 확인
    log_info "보안 테넌트 배포 상태 확인 중..."
    kubectl get tenant -n minio-secure
    
    checkpoint "보안 테넌트 배포 완료"
}

# 고급 인증 및 권한 관리
setup_advanced_auth() {
    log_step "고급 인증 및 권한 관리 설정"
    
    log_concept "고급 인증 메커니즘:"
    echo "  • 다단계 인증 (MFA)"
    echo "  • LDAP/Active Directory 연동"
    echo "  • OpenID Connect (OIDC) 연동"
    echo "  • 세밀한 권한 제어"
    echo ""
    
    # 테넌트 배포 완료 대기
    log_info "테넌트 배포 완료 대기 중..."
    sleep 30
    
    # HTTPS 포트 포워딩 설정
    log_info "HTTPS 포트 포워딩 설정 중..."
    kubectl port-forward svc/secure-tenant-hl -n minio-secure 9443:9000 > /dev/null 2>&1 &
    SECURE_PF_PID=$!
    sleep 5
    
    # 보안 MinIO 클라이언트 설정 (TLS 사용)
    log_info "보안 MinIO 클라이언트 설정 중..."
    
    # CA 인증서를 사용한 연결 설정
    mc alias set secure-minio https://localhost:9443 secureadmin SecurePassword2024! \
        --api S3v4 \
        --path auto 2>/dev/null || log_warning "연결 설정 실패"
    
    # 연결 테스트
    if mc admin info secure-minio > /dev/null 2>&1; then
        log_success "보안 MinIO 연결 성공"
        
        # 고급 사용자 생성
        log_info "고급 사용자 생성 중..."
        
        # 관리자 사용자
        mc admin user add secure-minio admin-user 'AdminPass2024!' 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        
        # 읽기 전용 사용자
        mc admin user add secure-minio readonly-user 'ReadOnlyPass2024!' 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        
        # 개발자 사용자
        mc admin user add secure-minio developer-user 'DevPass2024!' 2>/dev/null || log_warning "사용자가 이미 존재합니다."
        
        # 고급 정책 생성
        log_info "고급 보안 정책 생성 중..."
        
        # 관리자 정책
        cat > admin-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "admin:*"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    }
  ]
}
EOF
        
        # 읽기 전용 정책
        cat > readonly-policy.json << 'EOF'
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
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    }
  ]
}
EOF
        
        # 개발자 정책 (특정 버킷만 접근)
        cat > developer-policy.json << 'EOF'
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
        "arn:aws:s3:::dev-*/*",
        "arn:aws:s3:::test-*",
        "arn:aws:s3:::test-*/*"
      ]
    }
  ]
}
EOF
        
        # 정책 적용
        mc admin policy create secure-minio admin-policy admin-policy.json 2>/dev/null || log_warning "정책이 이미 존재합니다."
        mc admin policy create secure-minio readonly-policy readonly-policy.json 2>/dev/null || log_warning "정책이 이미 존재합니다."
        mc admin policy create secure-minio developer-policy developer-policy.json 2>/dev/null || log_warning "정책이 이미 존재합니다."
        
        # 사용자에게 정책 할당
        mc admin policy attach secure-minio admin-policy --user admin-user 2>/dev/null || true
        mc admin policy attach secure-minio readonly-policy --user readonly-user 2>/dev/null || true
        mc admin policy attach secure-minio developer-policy --user developer-user 2>/dev/null || true
        
        log_success "고급 인증 및 권한 설정 완료"
        
        # 사용자 목록 확인
        log_info "생성된 사용자 목록:"
        mc admin user list secure-minio
        
        # 정책 목록 확인
        log_info "생성된 정책 목록:"
        mc admin policy list secure-minio
        
    else
        log_warning "보안 MinIO 연결 실패"
    fi
    
    # 포트 포워딩 종료
    kill $SECURE_PF_PID 2>/dev/null || true
    
    checkpoint "고급 인증 설정 완료"
}

# 감사 로그 및 모니터링 설정
setup_audit_logging() {
    log_step "감사 로그 및 모니터링 설정"
    
    log_concept "감사 로그의 중요성:"
    echo "  • 모든 API 호출 추적"
    echo "  • 보안 이벤트 모니터링"
    echo "  • 규정 준수 지원"
    echo "  • 포렌식 분석 지원"
    echo ""
    
    # 감사 로그 수집 서비스 생성
    log_info "감사 로그 수집 서비스 생성 중..."
    
    cat > audit-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-service
  namespace: minio-secure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audit-service
  template:
    metadata:
      labels:
        app: audit-service
    spec:
      containers:
      - name: audit-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: audit-config
          mountPath: /etc/nginx/conf.d
        - name: audit-logs
          mountPath: /var/log/audit
      volumes:
      - name: audit-config
        configMap:
          name: audit-nginx-config
      - name: audit-logs
        emptyDir: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-nginx-config
  namespace: minio-secure
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location /audit {
            access_log /var/log/audit/minio-audit.log;
            return 200 "Audit log received\n";
            add_header Content-Type text/plain;
        }
        
        location /health {
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: audit-service
  namespace: minio-secure
spec:
  selector:
    app: audit-service
  ports:
  - port: 8080
    targetPort: 80
  type: ClusterIP
EOF
    
    kubectl apply -f audit-service.yaml
    
    log_success "감사 로그 수집 서비스 생성 완료"
    
    # 로그 모니터링 스크립트 생성
    log_info "로그 모니터링 스크립트 생성 중..."
    
    cat > monitor-audit-logs.sh << 'EOF'
#!/bin/bash

# MinIO 감사 로그 모니터링 스크립트

echo "=== MinIO 감사 로그 모니터링 ==="
echo "시작 시간: $(date)"
echo ""

# 감사 서비스 상태 확인
echo "1. 감사 서비스 상태:"
kubectl get pods -n minio-secure -l app=audit-service

echo ""
echo "2. 최근 감사 로그 (실시간 모니터링):"
echo "Ctrl+C로 중단할 수 있습니다."
echo ""

# 감사 로그 실시간 모니터링
kubectl logs -f -n minio-secure -l app=audit-service --tail=10 2>/dev/null || {
    echo "감사 로그를 가져올 수 없습니다."
    echo "감사 서비스가 실행 중인지 확인하세요."
}
EOF
    
    chmod +x monitor-audit-logs.sh
    
    # 보안 이벤트 알림 스크립트 생성
    cat > security-alerts.sh << 'EOF'
#!/bin/bash

# MinIO 보안 이벤트 알림 스크립트

ALERT_LOG="security-alerts.log"

check_security_events() {
    echo "[$(date)] 보안 이벤트 검사 시작" >> "$ALERT_LOG"
    
    # 실패한 로그인 시도 확인
    failed_logins=$(kubectl logs -n minio-secure -l app=minio --tail=100 | grep -c "authentication failed" || echo "0")
    
    if [ "$failed_logins" -gt 5 ]; then
        echo "[$(date)] 경고: 실패한 로그인 시도가 $failed_logins 회 감지됨" >> "$ALERT_LOG"
        echo "보안 경고: 실패한 로그인 시도가 많습니다 ($failed_logins 회)"
    fi
    
    # 비정상적인 API 호출 확인
    api_errors=$(kubectl logs -n minio-secure -l app=minio --tail=100 | grep -c "HTTP/1.1\" 40[0-9]" || echo "0")
    
    if [ "$api_errors" -gt 20 ]; then
        echo "[$(date)] 경고: 비정상적인 API 호출이 $api_errors 회 감지됨" >> "$ALERT_LOG"
        echo "보안 경고: 비정상적인 API 호출이 많습니다 ($api_errors 회)"
    fi
    
    echo "[$(date)] 보안 이벤트 검사 완료" >> "$ALERT_LOG"
}

# 보안 이벤트 검사 실행
check_security_events

# 알림 로그 표시
if [ -f "$ALERT_LOG" ]; then
    echo "=== 보안 알림 로그 ==="
    tail -20 "$ALERT_LOG"
fi
EOF
    
    chmod +x security-alerts.sh
    
    log_success "감사 로그 및 모니터링 설정 완료"
    
    checkpoint "감사 로그 설정 완료"
}
# 보안 테스트 및 검증
test_security_features() {
    log_step "보안 기능 테스트 및 검증"
    
    log_concept "보안 테스트 항목:"
    echo "  • TLS/SSL 연결 테스트"
    echo "  • 인증 및 권한 테스트"
    echo "  • 네트워크 보안 테스트"
    echo "  • 감사 로그 기능 테스트"
    echo ""
    
    log_info "=== 보안 기능 테스트 시작 ==="
    
    # TLS 연결 테스트
    log_info "1. TLS/SSL 연결 테스트"
    
    # HTTPS 포트 포워딩
    kubectl port-forward svc/secure-tenant-hl -n minio-secure 9443:9000 > /dev/null 2>&1 &
    SECURE_PF_PID=$!
    sleep 5
    
    # TLS 연결 테스트
    if openssl s_client -connect localhost:9443 -servername minio.local < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        log_success "✓ TLS 연결 성공"
    else
        log_warning "⚠ TLS 연결에 문제가 있을 수 있습니다"
    fi
    
    # 인증 테스트
    log_info "2. 사용자 인증 테스트"
    
    # 올바른 인증 정보로 연결 테스트
    if mc admin info secure-minio > /dev/null 2>&1; then
        log_success "✓ 관리자 인증 성공"
    else
        log_warning "⚠ 관리자 인증 실패"
    fi
    
    # 잘못된 인증 정보로 연결 테스트 (실패해야 정상)
    mc alias set test-wrong https://localhost:9443 wronguser wrongpass 2>/dev/null || true
    if ! mc admin info test-wrong > /dev/null 2>&1; then
        log_success "✓ 잘못된 인증 정보 차단 성공"
    else
        log_warning "⚠ 보안 문제: 잘못된 인증 정보로 접근 가능"
    fi
    
    # 권한 테스트
    log_info "3. 권한 제어 테스트"
    
    # 테스트 버킷 생성 (관리자 권한)
    mc mb secure-minio/security-test-bucket 2>/dev/null || log_warning "버킷이 이미 존재합니다."
    
    # 테스트 파일 업로드
    echo "Security test data" > security-test.txt
    mc cp security-test.txt secure-minio/security-test-bucket/ 2>/dev/null || true
    
    if mc ls secure-minio/security-test-bucket/ | grep -q "security-test.txt"; then
        log_success "✓ 관리자 권한으로 파일 업로드 성공"
    else
        log_warning "⚠ 파일 업로드 실패"
    fi
    
    # 네트워크 보안 테스트
    log_info "4. 네트워크 보안 테스트"
    
    # HTTP 연결 시도 (실패해야 정상)
    if ! curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "✓ HTTP 연결 차단 성공 (HTTPS만 허용)"
    else
        log_warning "⚠ HTTP 연결이 허용됨 (보안 위험)"
    fi
    
    # 감사 로그 테스트
    log_info "5. 감사 로그 기능 테스트"
    
    # 감사 서비스 상태 확인
    if kubectl get pods -n minio-secure -l app=audit-service | grep -q "Running"; then
        log_success "✓ 감사 로그 서비스 실행 중"
        
        # 감사 로그 생성을 위한 API 호출
        mc ls secure-minio/ > /dev/null 2>&1 || true
        
        # 감사 로그 확인
        sleep 3
        if kubectl logs -n minio-secure -l app=audit-service --tail=5 | grep -q "audit"; then
            log_success "✓ 감사 로그 기록 확인"
        else
            log_warning "⚠ 감사 로그 기록을 확인할 수 없습니다"
        fi
    else
        log_warning "⚠ 감사 로그 서비스가 실행되지 않았습니다"
    fi
    
    # 정리
    rm -f security-test.txt
    kill $SECURE_PF_PID 2>/dev/null || true
    
    log_success "보안 기능 테스트 완료"
    checkpoint "보안 테스트 완료"
}

# 보안 체크리스트 생성
create_security_checklist() {
    log_step "보안 체크리스트 생성"
    
    log_concept "운영 환경 보안 체크리스트를 생성합니다:"
    echo "  • 일일 보안 점검 항목"
    echo "  • 주기적 보안 감사 항목"
    echo "  • 보안 사고 대응 절차"
    echo ""
    
    # 보안 체크리스트 생성
    cat > security-checklist.md << 'EOF'
# MinIO 보안 체크리스트

## 일일 보안 점검 (Daily Security Checks)

### 1. 인증 및 접근 제어
- [ ] 실패한 로그인 시도 확인
- [ ] 비정상적인 사용자 활동 모니터링
- [ ] 권한 변경 사항 검토
- [ ] 새로운 사용자 계정 검토

### 2. 네트워크 보안
- [ ] TLS/SSL 인증서 유효성 확인
- [ ] 비정상적인 네트워크 트래픽 확인
- [ ] 방화벽 규칙 점검
- [ ] VPN 연결 상태 확인

### 3. 시스템 보안
- [ ] 시스템 로그 검토
- [ ] 보안 패치 상태 확인
- [ ] 백업 상태 확인
- [ ] 디스크 사용량 모니터링

## 주간 보안 감사 (Weekly Security Audit)

### 1. 사용자 관리
- [ ] 비활성 사용자 계정 정리
- [ ] 권한 재검토 및 최소 권한 원칙 적용
- [ ] 패스워드 정책 준수 확인
- [ ] 다단계 인증 설정 확인

### 2. 데이터 보호
- [ ] 암호화 상태 확인
- [ ] 백업 무결성 검증
- [ ] 데이터 분류 및 라벨링 확인
- [ ] 데이터 보존 정책 준수 확인

### 3. 모니터링 및 로깅
- [ ] 감사 로그 검토
- [ ] 보안 이벤트 분석
- [ ] 알림 시스템 테스트
- [ ] 로그 보존 정책 확인

## 보안 사고 대응 절차

### 1. 사고 감지
1. 자동 알림 시스템 확인
2. 로그 분석 및 이상 징후 파악
3. 사고 심각도 평가
4. 초기 대응팀 소집

### 2. 사고 대응
1. 영향 범위 파악
2. 즉시 조치 실행 (격리, 차단 등)
3. 증거 보전
4. 관련 부서 및 고객 통보

### 3. 사고 복구
1. 시스템 복구 계획 수립
2. 백업에서 데이터 복구
3. 보안 패치 적용
4. 서비스 재개

### 4. 사후 분석
1. 사고 원인 분석
2. 대응 과정 검토
3. 개선 방안 도출
4. 정책 및 절차 업데이트
EOF
    
    log_success "보안 체크리스트 생성 완료: security-checklist.md"
    
    # 보안 자동화 스크립트 생성
    cat > automated-security-check.sh << 'EOF'
#!/bin/bash

# MinIO 자동화된 보안 점검 스크립트

REPORT_FILE="security-report-$(date +%Y%m%d-%H%M%S).txt"

echo "=== MinIO 자동화된 보안 점검 ===" > "$REPORT_FILE"
echo "실행 시간: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. TLS 인증서 확인
echo "1. TLS 인증서 상태:" >> "$REPORT_FILE"
if kubectl get secret minio-tls-secret -n minio-secure &>/dev/null; then
    cert_expiry=$(kubectl get secret minio-tls-secret -n minio-secure -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate | cut -d= -f2)
    echo "   인증서 만료일: $cert_expiry" >> "$REPORT_FILE"
    
    # 만료일까지 남은 일수 계산
    expiry_epoch=$(date -d "$cert_expiry" +%s)
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_left -lt 30 ]; then
        echo "   ⚠ 경고: 인증서가 $days_left 일 후 만료됩니다" >> "$REPORT_FILE"
    else
        echo "   ✓ 인증서 상태 양호 ($days_left 일 남음)" >> "$REPORT_FILE"
    fi
else
    echo "   ✗ TLS 인증서를 찾을 수 없습니다" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "보안 점검 완료: $(date)" >> "$REPORT_FILE"

# 보고서 출력
cat "$REPORT_FILE"
EOF
    
    chmod +x automated-security-check.sh
    
    log_success "보안 자동화 스크립트 생성 완료"
    checkpoint "보안 체크리스트 생성 완료"
}

# 실습 정리
cleanup_lab() {
    log_step "실습 환경 정리"
    
    read -p "보안 테넌트를 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "보안 테넌트 삭제 중..."
        kubectl delete tenant secure-tenant -n minio-secure 2>/dev/null || true
        kubectl delete deployment audit-service -n minio-secure 2>/dev/null || true
        kubectl delete namespace minio-secure 2>/dev/null || true
        log_success "보안 테넌트 삭제 완료"
    fi
    
    read -p "생성된 인증서와 설정 파일들을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "파일 정리 중..."
        rm -rf tls-certs/
        rm -f secure-tenant.yaml audit-service.yaml
        rm -f admin-policy.json readonly-policy.json developer-policy.json
        log_success "파일 정리 완료"
    fi
    
    log_success "실습 정리 완료"
}

# 실습 요약
lab_summary() {
    log_step "Lab 12 실습 요약"
    
    echo -e "${GREEN}=== 학습 완료 내용 ===${NC}"
    echo "✅ TLS/SSL 보안 설정"
    echo "✅ 고급 인증 및 권한 관리"
    echo "✅ 감사 로그 및 모니터링"
    echo "✅ 보안 테스트 및 검증"
    echo ""
    
    log_success "Lab 12: Security Enhancement 실습 완료!"
}

# 메인 함수
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Lab 12: MinIO Security                      ║"
    echo "║                    Enhancement                               ║"
    echo "║                                                              ║"
    echo "║  학습 목표:                                                  ║"
    echo "║  • TLS/SSL 인증서 생성 및 관리                              ║"
    echo "║  • 고급 인증 및 권한 관리 시스템                            ║"
    echo "║  • 감사 로그 및 보안 모니터링                               ║"
    echo "║  • 보안 테스트 및 검증 절차                                 ║"
    echo "║                                                              ║"
    echo "║  예상 소요시간: 35-45분                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    wait_for_user
    
    # 실습 단계별 실행
    check_prerequisites
    explain_security_architecture
    create_tls_certificates
    create_tls_secrets
    deploy_secure_tenant
    
    # 테넌트 배포 완료 대기
    log_info "보안 테넌트 배포 완료 대기 중..."
    sleep 45
    
    setup_advanced_auth
    setup_audit_logging
    test_security_features
    create_security_checklist
    
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
    fi
}

# 스크립트 실행
if [ "$1" = "cleanup" ]; then
    cleanup_lab
else
    main
fi
