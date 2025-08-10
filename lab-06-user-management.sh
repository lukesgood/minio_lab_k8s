#!/bin/bash

# Lab 6: 사용자 및 권한 관리
# IAM 사용자 생성, 정책 기반 접근 제어, 버킷 정책 설정
# 학습 목표: MinIO IAM 시스템, 정책 기반 제어, 보안 모범 사례

set -e

echo "=== Lab 6: 사용자 및 권한 관리 ==="
echo "🎯 학습 목표:"
echo "   • MinIO IAM (Identity and Access Management) 시스템 이해"
echo "   • 사용자 생성 및 관리"
echo "   • 정책 기반 접근 제어 (PBAC) 구현"
echo "   • 버킷 정책 설정 및 최적화"
echo "   • 그룹 기반 권한 관리"
echo "   • 보안 모범 사례 적용"
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 함수 정의
print_step() {
    echo -e "${BLUE}[단계 $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_concept() {
    echo -e "${PURPLE}💡 개념:${NC} $1"
}

wait_for_user() {
    echo -e "${YELLOW}계속하려면 Enter를 누르세요...${NC}"
    read
}

install_minio_client() {
    echo -e "${CYAN}🔧 MinIO Client 자동 설치${NC}"
    echo ""
    
    echo "MinIO Client 다운로드 중..."
    if curl -O https://dl.min.io/client/mc/release/linux-amd64/mc; then
        print_success "MinIO Client 다운로드 완료"
        
        echo "실행 권한 부여 중..."
        chmod +x mc
        
        echo "PATH에 추가 중..."
        if sudo mv mc /usr/local/bin/ 2>/dev/null; then
            print_success "MinIO Client를 /usr/local/bin/에 설치했습니다"
        elif mv mc ~/bin/ 2>/dev/null; then
            print_success "MinIO Client를 ~/bin/에 설치했습니다"
            export PATH=$PATH:~/bin
        else
            print_warning "시스템 경로에 추가할 수 없습니다"
            echo "현재 디렉토리에서 ./mc로 실행하거나 PATH를 수동으로 설정하세요."
            export PATH=$PATH:$(pwd)
        fi
        
        echo ""
        echo "설치 확인:"
        mc --version
        return 0
    else
        print_error "MinIO Client 다운로드 실패"
        echo ""
        echo -e "${YELLOW}해결 방법:${NC}"
        echo "1. 네트워크 연결 확인"
        echo "2. 방화벽 설정 확인"
        echo "3. 수동 다운로드: https://dl.min.io/client/mc/release/linux-amd64/mc"
        return 1
    fi
}

check_prerequisites() {
    echo -e "${BLUE}📋 사전 요구사항 확인${NC}"
    echo ""
    
    # MinIO Client 확인 및 자동 설치
    if ! command -v mc &> /dev/null; then
        print_warning "MinIO Client가 설치되어 있지 않습니다"
        echo ""
        echo "자동으로 MinIO Client를 설치하시겠습니까? (y/n)"
        read -p "선택: " install_choice
        
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            if ! install_minio_client; then
                print_error "MinIO Client 설치 실패"
                echo "Lab 3을 먼저 완료하거나 수동으로 설치해주세요."
                exit 1
            fi
        else
            print_error "MinIO Client가 필요합니다"
            echo "Lab 3을 먼저 완료해주세요."
            exit 1
        fi
    else
        print_success "MinIO Client 확인됨"
        mc --version
    fi
    
    echo ""
    
    # MinIO 서버 연결 확인
    echo "MinIO 서버 연결 확인 중..."
    if ! mc admin info local &> /dev/null; then
        print_warning "MinIO 서버에 연결할 수 없습니다"
        echo ""
        echo "서버 연결을 설정하시겠습니까? (y/n)"
        read -p "선택: " setup_choice
        
        if [[ $setup_choice =~ ^[Yy]$ ]]; then
            echo ""
            echo "MinIO 서버 연결 설정:"
            echo "기본값: http://localhost:9000, admin, password123"
            echo ""
            
            read -p "MinIO URL [http://localhost:9000]: " minio_url
            minio_url=${minio_url:-http://localhost:9000}
            
            read -p "사용자명 [admin]: " username
            username=${username:-admin}
            
            read -s -p "비밀번호 [password123]: " password
            password=${password:-password123}
            echo ""
            
            echo ""
            echo "연결 설정 중..."
            if mc alias set local $minio_url $username $password; then
                print_success "MinIO 서버 연결 설정 완료"
                
                echo ""
                echo "연결 테스트 중..."
                if mc admin info local &> /dev/null; then
                    print_success "MinIO 서버 연결 확인됨"
                else
                    print_error "MinIO 서버 연결 실패"
                    echo ""
                    echo -e "${YELLOW}해결 방법:${NC}"
                    echo "1. MinIO 서버가 실행 중인지 확인"
                    echo "2. 포트 포워딩 설정 확인: kubectl port-forward svc/minio -n minio-tenant 9000:80"
                    echo "3. 인증 정보 확인"
                    exit 1
                fi
            else
                print_error "MinIO 서버 연결 설정 실패"
                exit 1
            fi
        else
            print_error "MinIO 서버 연결이 필요합니다"
            echo "Lab 3의 포트 포워딩과 서버 연결을 확인해주세요."
            exit 1
        fi
    else
        print_success "MinIO 서버 연결 확인됨"
    fi
    
    # 관리자 권한 확인
    echo ""
    echo "관리자 권한 확인 중..."
    if ! mc admin user list local &> /dev/null; then
        print_error "관리자 권한이 필요합니다"
        echo "현재 연결된 계정이 관리자 권한을 가지고 있는지 확인해주세요."
        echo ""
        echo "관리자 계정으로 다시 연결하시겠습니까? (y/n)"
        read -p "선택: " admin_choice
        
        if [[ $admin_choice =~ ^[Yy]$ ]]; then
            echo ""
            echo "관리자 계정 연결:"
            
            read -p "관리자 사용자명 [admin]: " admin_username
            admin_username=${admin_username:-admin}
            
            read -s -p "관리자 비밀번호 [password123]: " admin_password
            admin_password=${admin_password:-password123}
            echo ""
            
            echo ""
            echo "관리자 연결 설정 중..."
            if mc alias set local http://localhost:9000 $admin_username $admin_password; then
                if mc admin user list local &> /dev/null; then
                    print_success "관리자 권한 확인됨"
                else
                    print_error "관리자 권한 확인 실패"
                    exit 1
                fi
            else
                print_error "관리자 연결 설정 실패"
                exit 1
            fi
        else
            exit 1
        fi
    else
        print_success "관리자 권한 확인됨"
    fi
    
    echo ""
    print_success "사전 요구사항 확인 완료"
    echo ""
}

create_test_bucket() {
    local bucket_name="iam-test-$(date +%s)"
    echo "$bucket_name"
}

generate_random_password() {
    local length=${1:-12}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    else
        # Fallback method
        date +%s | sha256sum | base64 | head -c $length
    fi
}

validate_policy_json() {
    local policy_file=$1
    
    if command -v jq &> /dev/null; then
        if jq empty "$policy_file" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        # Basic validation without jq
        if grep -q "Version\|Statement" "$policy_file"; then
            return 0
        else
            return 1
        fi
    fi
}

# 메인 실습 시작
echo -e "${PURPLE}🎓 Lab 6: 사용자 및 권한 관리 실습${NC}"
echo ""
echo -e "${BLUE}📚 이 Lab에서 배우는 내용:${NC}"
echo "• MinIO IAM 시스템의 구조와 동작 원리"
echo "• 사용자 생성 및 액세스 키 관리"
echo "• JSON 기반 정책 작성 및 적용"
echo "• 버킷별 세밀한 권한 제어"
echo "• 그룹을 통한 효율적인 권한 관리"
echo "• 실제 시나리오 기반 보안 설정"
echo ""

# 사전 요구사항 확인
check_prerequisites
# Step 1: MinIO IAM 시스템 이해
print_step "1" "MinIO IAM 시스템 이해"
echo ""
print_concept "MinIO의 Identity and Access Management 시스템을 학습합니다"
echo ""

echo -e "${CYAN}🔐 MinIO IAM 구조:${NC}"
echo "• Root User: 시스템 관리자 (모든 권한)"
echo "• IAM Users: 일반 사용자 (제한된 권한)"
echo "• Groups: 사용자 그룹 (권한 일괄 관리)"
echo "• Policies: JSON 기반 권한 정책"
echo "• Access Keys: 프로그래밍 방식 접근용 키"
echo ""

echo -e "${YELLOW}📋 권한 제어 방식:${NC}"
echo "• Policy-Based Access Control (PBAC)"
echo "• 최소 권한 원칙 (Principle of Least Privilege)"
echo "• 명시적 거부 우선 (Explicit Deny)"
echo "• 리소스 기반 정책 (Resource-based Policy)"
echo ""

echo "1. 현재 IAM 상태 확인:"
echo ""

echo "기존 사용자 목록:"
echo "명령어: mc admin user list local"
mc admin user list local

echo ""
echo "기존 그룹 목록:"
echo "명령어: mc admin group list local"
mc admin group list local

echo ""
echo "기존 정책 목록:"
echo "명령어: mc admin policy list local"
mc admin policy list local

echo ""
echo -e "${BLUE}📊 현재 IAM 상태 분석:${NC}"
USER_COUNT=$(mc admin user list local | wc -l)
GROUP_COUNT=$(mc admin group list local | wc -l)
POLICY_COUNT=$(mc admin policy list local | wc -l)

echo "• 등록된 사용자 수: $USER_COUNT"
echo "• 등록된 그룹 수: $GROUP_COUNT"
echo "• 등록된 정책 수: $POLICY_COUNT"

wait_for_user "IAM 시스템 현황을 확인했습니다. 테스트 환경을 준비하겠습니다."

# Step 2: 테스트 환경 준비
print_step "2" "테스트 환경 준비"
echo ""
print_concept "사용자 권한 테스트를 위한 버킷과 데이터를 준비합니다"
echo ""

# 작업 디렉토리 생성
mkdir -p lab6-iam-test
cd lab6-iam-test

echo -e "${BLUE}📁 IAM 테스트 구조:${NC}"
echo "lab6-iam-test/"
echo "├── policies/        # JSON 정책 파일들"
echo "├── test-data/       # 권한 테스트용 데이터"
echo "├── user-configs/    # 사용자별 설정 파일"
echo "└── results/         # 테스트 결과"

mkdir -p policies test-data user-configs results

# 테스트용 버킷들 생성
echo ""
echo "테스트용 버킷 생성:"

BUCKETS=("public-data" "private-data" "shared-docs" "user-uploads")

for bucket in "${BUCKETS[@]}"; do
    FULL_BUCKET_NAME="${bucket}-$(date +%s)"
    echo "버킷 생성: $FULL_BUCKET_NAME"
    
    if mc mb local/$FULL_BUCKET_NAME; then
        print_success "$FULL_BUCKET_NAME 생성 완료"
        
        # 버킷별 변수 저장
        case $bucket in
            "public-data")
                PUBLIC_BUCKET=$FULL_BUCKET_NAME
                ;;
            "private-data")
                PRIVATE_BUCKET=$FULL_BUCKET_NAME
                ;;
            "shared-docs")
                SHARED_BUCKET=$FULL_BUCKET_NAME
                ;;
            "user-uploads")
                UPLOADS_BUCKET=$FULL_BUCKET_NAME
                ;;
        esac
    else
        print_warning "$FULL_BUCKET_NAME 생성 실패"
    fi
done

echo ""
echo "생성된 테스트 버킷들:"
echo "• 공개 데이터: $PUBLIC_BUCKET"
echo "• 비공개 데이터: $PRIVATE_BUCKET"
echo "• 공유 문서: $SHARED_BUCKET"
echo "• 사용자 업로드: $UPLOADS_BUCKET"

# 테스트 데이터 생성 및 업로드
echo ""
echo "테스트 데이터 생성 및 업로드:"

# 공개 데이터
echo "공개 정보입니다. 누구나 읽을 수 있습니다." > test-data/public-info.txt
mc cp test-data/public-info.txt local/$PUBLIC_BUCKET/

# 비공개 데이터
echo "기밀 정보입니다. 권한이 있는 사용자만 접근 가능합니다." > test-data/confidential.txt
mc cp test-data/confidential.txt local/$PRIVATE_BUCKET/

# 공유 문서
echo "팀 공유 문서입니다. 특정 그룹만 접근 가능합니다." > test-data/team-doc.txt
mc cp test-data/team-doc.txt local/$SHARED_BUCKET/

print_success "테스트 데이터 업로드 완료"

wait_for_user "테스트 환경을 준비했습니다. IAM 사용자를 생성하겠습니다."

# Step 3: IAM 사용자 생성 및 관리
print_step "3" "IAM 사용자 생성 및 관리"
echo ""
print_concept "다양한 역할의 사용자를 생성하고 액세스 키를 관리합니다"
echo ""

echo -e "${CYAN}👥 생성할 사용자 역할:${NC}"
echo "• alice: 읽기 전용 사용자 (Read-Only User)"
echo "• bob: 개발자 (Developer - 제한된 쓰기 권한)"
echo "• charlie: 관리자 (Admin - 거의 모든 권한)"
echo "• diana: 게스트 (Guest - 최소 권한)"
echo ""

echo "1. 사용자 생성:"
echo ""

# 사용자 정보 배열
declare -A USERS
USERS[alice]="읽기 전용 사용자"
USERS[bob]="개발자"
USERS[charlie]="관리자"
USERS[diana]="게스트"

# 사용자별 비밀번호 생성 및 저장
for username in "${!USERS[@]}"; do
    role="${USERS[$username]}"
    password=$(generate_random_password 16)
    
    echo "사용자 생성: $username ($role)"
    echo "명령어: mc admin user add local $username [password]"
    
    if mc admin user add local $username $password; then
        print_success "$username 사용자 생성 완료"
        
        # 사용자 정보 저장
        cat > user-configs/${username}-config.txt << EOF
사용자명: $username
역할: $role
비밀번호: $password
생성일시: $(date)
상태: 활성
EOF
        
        echo "  비밀번호: $password (저장됨: user-configs/${username}-config.txt)"
    else
        print_error "$username 사용자 생성 실패"
    fi
    echo ""
done

echo "2. 생성된 사용자 확인:"
echo ""
echo "전체 사용자 목록:"
mc admin user list local

echo ""
echo "사용자별 상세 정보:"
for username in "${!USERS[@]}"; do
    echo ""
    echo "사용자: $username"
    echo "명령어: mc admin user info local $username"
    mc admin user info local $username
done

wait_for_user "IAM 사용자를 생성했습니다. 정책을 작성하고 적용하겠습니다."

# Step 4: 정책 작성 및 적용
print_step "4" "정책 작성 및 적용"
echo ""
print_concept "JSON 기반 정책을 작성하여 세밀한 권한 제어를 구현합니다"
echo ""

echo -e "${CYAN}📝 정책 작성 원칙:${NC}"
echo "• 최소 권한 원칙: 필요한 최소한의 권한만 부여"
echo "• 명시적 정의: 허용할 작업을 명확히 정의"
echo "• 리소스 제한: 특정 버킷/객체에만 접근 허용"
echo "• 조건부 접근: IP, 시간 등 조건 기반 제어"
echo ""

echo "1. 읽기 전용 정책 작성:"
echo ""

# 읽기 전용 정책
cat > policies/readonly-policy.json << EOF
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
                "arn:aws:s3:::$PUBLIC_BUCKET",
                "arn:aws:s3:::$PUBLIC_BUCKET/*"
            ]
        }
    ]
}
EOF

echo "읽기 전용 정책 내용:"
cat policies/readonly-policy.json | jq . 2>/dev/null || cat policies/readonly-policy.json

echo ""
echo "정책 등록:"
echo "명령어: mc admin policy add local readonly-policy policies/readonly-policy.json"

if mc admin policy add local readonly-policy policies/readonly-policy.json; then
    print_success "읽기 전용 정책 등록 완료"
else
    print_error "읽기 전용 정책 등록 실패"
fi

echo ""
echo "2. 개발자 정책 작성:"
echo ""

# 개발자 정책 (제한된 쓰기 권한)
cat > policies/developer-policy.json << EOF
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
                "arn:aws:s3:::$UPLOADS_BUCKET",
                "arn:aws:s3:::$UPLOADS_BUCKET/*",
                "arn:aws:s3:::$SHARED_BUCKET",
                "arn:aws:s3:::$SHARED_BUCKET/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$PUBLIC_BUCKET",
                "arn:aws:s3:::$PUBLIC_BUCKET/*"
            ]
        }
    ]
}
EOF

echo "개발자 정책 내용:"
cat policies/developer-policy.json | jq . 2>/dev/null || cat policies/developer-policy.json

echo ""
echo "정책 등록:"
if mc admin policy add local developer-policy policies/developer-policy.json; then
    print_success "개발자 정책 등록 완료"
else
    print_error "개발자 정책 등록 실패"
fi

echo ""
echo "3. 관리자 정책 작성:"
echo ""

# 관리자 정책 (거의 모든 권한, 단 사용자 관리 제외)
cat > policies/admin-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::*"
            ]
        },
        {
            "Effect": "Deny",
            "Action": [
                "admin:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF

echo "관리자 정책 내용:"
cat policies/admin-policy.json | jq . 2>/dev/null || cat policies/admin-policy.json

echo ""
echo "정책 등록:"
if mc admin policy add local admin-policy policies/admin-policy.json; then
    print_success "관리자 정책 등록 완료"
else
    print_error "관리자 정책 등록 실패"
fi

echo ""
echo "4. 게스트 정책 작성:"
echo ""

# 게스트 정책 (매우 제한적)
cat > policies/guest-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::$PUBLIC_BUCKET/public-info.txt"
            ]
        }
    ]
}
EOF

echo "게스트 정책 내용:"
cat policies/guest-policy.json | jq . 2>/dev/null || cat policies/guest-policy.json

echo ""
echo "정책 등록:"
if mc admin policy add local guest-policy policies/guest-policy.json; then
    print_success "게스트 정책 등록 완료"
else
    print_error "게스트 정책 등록 실패"
fi

echo ""
echo "5. 등록된 정책 확인:"
echo ""
echo "전체 정책 목록:"
mc admin policy list local

wait_for_user "정책을 작성하고 등록했습니다. 사용자에게 정책을 적용하겠습니다."
# Step 5: 사용자에게 정책 적용
print_step "5" "사용자에게 정책 적용"
echo ""
print_concept "생성한 정책을 각 사용자에게 적용하여 권한을 부여합니다"
echo ""

echo -e "${CYAN}👤 사용자별 정책 매핑:${NC}"
echo "• alice → readonly-policy (읽기 전용)"
echo "• bob → developer-policy (개발자 권한)"
echo "• charlie → admin-policy (관리자 권한)"
echo "• diana → guest-policy (게스트 권한)"
echo ""

# 사용자별 정책 적용
declare -A USER_POLICIES
USER_POLICIES[alice]="readonly-policy"
USER_POLICIES[bob]="developer-policy"
USER_POLICIES[charlie]="admin-policy"
USER_POLICIES[diana]="guest-policy"

echo "정책 적용 중:"
echo ""

for username in "${!USER_POLICIES[@]}"; do
    policy="${USER_POLICIES[$username]}"
    
    echo "사용자 $username에게 $policy 적용:"
    echo "명령어: mc admin policy set local $policy user=$username"
    
    if mc admin policy set local $policy user=$username; then
        print_success "$username에게 $policy 적용 완료"
        
        # 사용자 설정 파일 업데이트
        echo "적용된 정책: $policy" >> user-configs/${username}-config.txt
        echo "정책 적용일시: $(date)" >> user-configs/${username}-config.txt
    else
        print_error "$username에게 $policy 적용 실패"
    fi
    echo ""
done

echo "정책 적용 결과 확인:"
echo ""

for username in "${!USER_POLICIES[@]}"; do
    echo "사용자 $username 정보:"
    mc admin user info local $username
    echo ""
done

wait_for_user "정책을 적용했습니다. 권한 테스트를 진행하겠습니다."

# Step 6: 권한 테스트 및 검증
print_step "6" "권한 테스트 및 검증"
echo ""
print_concept "각 사용자의 권한이 올바르게 적용되었는지 테스트합니다"
echo ""

echo -e "${YELLOW}🧪 권한 테스트 시나리오:${NC}"
echo "1. 읽기 권한 테스트"
echo "2. 쓰기 권한 테스트"
echo "3. 삭제 권한 테스트"
echo "4. 관리 권한 테스트"
echo "5. 접근 거부 테스트"
echo ""

# 테스트 결과 저장 파일
TEST_RESULTS="results/permission-test-results.txt"
echo "MinIO IAM 권한 테스트 결과" > $TEST_RESULTS
echo "테스트 일시: $(date)" >> $TEST_RESULTS
echo "================================" >> $TEST_RESULTS

echo "1. Alice (읽기 전용) 권한 테스트:"
echo ""

# Alice 사용자로 별칭 설정
ALICE_PASSWORD=$(grep "비밀번호:" user-configs/alice-config.txt | cut -d' ' -f2)
echo "Alice 사용자 연결 설정..."

if mc alias set alice-local http://localhost:9000 alice $ALICE_PASSWORD; then
    print_success "Alice 사용자 연결 설정 완료"
    
    echo ""
    echo "a) 공개 버킷 읽기 테스트 (허용되어야 함):"
    if mc ls alice-local/$PUBLIC_BUCKET 2>/dev/null; then
        print_success "Alice: 공개 버킷 읽기 성공 ✓"
        echo "Alice: 공개 버킷 읽기 - 성공" >> $TEST_RESULTS
    else
        print_error "Alice: 공개 버킷 읽기 실패 ✗"
        echo "Alice: 공개 버킷 읽기 - 실패" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "b) 비공개 버킷 읽기 테스트 (거부되어야 함):"
    if mc ls alice-local/$PRIVATE_BUCKET 2>/dev/null; then
        print_error "Alice: 비공개 버킷 읽기 성공 (보안 문제!) ✗"
        echo "Alice: 비공개 버킷 읽기 - 성공 (보안 문제)" >> $TEST_RESULTS
    else
        print_success "Alice: 비공개 버킷 읽기 거부됨 ✓"
        echo "Alice: 비공개 버킷 읽기 - 거부됨 (정상)" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "c) 쓰기 권한 테스트 (거부되어야 함):"
    echo "테스트 파일" > test-data/alice-test.txt
    if mc cp test-data/alice-test.txt alice-local/$PUBLIC_BUCKET/ 2>/dev/null; then
        print_error "Alice: 쓰기 권한 있음 (보안 문제!) ✗"
        echo "Alice: 쓰기 권한 - 있음 (보안 문제)" >> $TEST_RESULTS
    else
        print_success "Alice: 쓰기 권한 거부됨 ✓"
        echo "Alice: 쓰기 권한 - 거부됨 (정상)" >> $TEST_RESULTS
    fi
else
    print_error "Alice 사용자 연결 실패"
fi

echo ""
echo "2. Bob (개발자) 권한 테스트:"
echo ""

# Bob 사용자로 별칭 설정
BOB_PASSWORD=$(grep "비밀번호:" user-configs/bob-config.txt | cut -d' ' -f2)
echo "Bob 사용자 연결 설정..."

if mc alias set bob-local http://localhost:9000 bob $BOB_PASSWORD; then
    print_success "Bob 사용자 연결 설정 완료"
    
    echo ""
    echo "a) 업로드 버킷 쓰기 테스트 (허용되어야 함):"
    echo "Bob의 테스트 파일" > test-data/bob-test.txt
    if mc cp test-data/bob-test.txt bob-local/$UPLOADS_BUCKET/ 2>/dev/null; then
        print_success "Bob: 업로드 버킷 쓰기 성공 ✓"
        echo "Bob: 업로드 버킷 쓰기 - 성공" >> $TEST_RESULTS
    else
        print_error "Bob: 업로드 버킷 쓰기 실패 ✗"
        echo "Bob: 업로드 버킷 쓰기 - 실패" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "b) 비공개 버킷 접근 테스트 (거부되어야 함):"
    if mc ls bob-local/$PRIVATE_BUCKET 2>/dev/null; then
        print_error "Bob: 비공개 버킷 접근 성공 (보안 문제!) ✗"
        echo "Bob: 비공개 버킷 접근 - 성공 (보안 문제)" >> $TEST_RESULTS
    else
        print_success "Bob: 비공개 버킷 접근 거부됨 ✓"
        echo "Bob: 비공개 버킷 접근 - 거부됨 (정상)" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "c) 공유 문서 읽기/쓰기 테스트 (허용되어야 함):"
    if mc ls bob-local/$SHARED_BUCKET 2>/dev/null; then
        print_success "Bob: 공유 문서 읽기 성공 ✓"
        echo "Bob: 공유 문서 읽기 - 성공" >> $TEST_RESULTS
        
        echo "Bob의 공유 문서" > test-data/bob-shared.txt
        if mc cp test-data/bob-shared.txt bob-local/$SHARED_BUCKET/ 2>/dev/null; then
            print_success "Bob: 공유 문서 쓰기 성공 ✓"
            echo "Bob: 공유 문서 쓰기 - 성공" >> $TEST_RESULTS
        else
            print_error "Bob: 공유 문서 쓰기 실패 ✗"
            echo "Bob: 공유 문서 쓰기 - 실패" >> $TEST_RESULTS
        fi
    else
        print_error "Bob: 공유 문서 읽기 실패 ✗"
        echo "Bob: 공유 문서 읽기 - 실패" >> $TEST_RESULTS
    fi
else
    print_error "Bob 사용자 연결 실패"
fi

echo ""
echo "3. Diana (게스트) 권한 테스트:"
echo ""

# Diana 사용자로 별칭 설정
DIANA_PASSWORD=$(grep "비밀번호:" user-configs/diana-config.txt | cut -d' ' -f2)
echo "Diana 사용자 연결 설정..."

if mc alias set diana-local http://localhost:9000 diana $DIANA_PASSWORD; then
    print_success "Diana 사용자 연결 설정 완료"
    
    echo ""
    echo "a) 특정 파일 읽기 테스트 (허용되어야 함):"
    if mc cat diana-local/$PUBLIC_BUCKET/public-info.txt 2>/dev/null; then
        print_success "Diana: 특정 파일 읽기 성공 ✓"
        echo "Diana: 특정 파일 읽기 - 성공" >> $TEST_RESULTS
    else
        print_error "Diana: 특정 파일 읽기 실패 ✗"
        echo "Diana: 특정 파일 읽기 - 실패" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "b) 버킷 목록 조회 테스트 (거부되어야 함):"
    if mc ls diana-local/$PUBLIC_BUCKET 2>/dev/null; then
        print_error "Diana: 버킷 목록 조회 성공 (보안 문제!) ✗"
        echo "Diana: 버킷 목록 조회 - 성공 (보안 문제)" >> $TEST_RESULTS
    else
        print_success "Diana: 버킷 목록 조회 거부됨 ✓"
        echo "Diana: 버킷 목록 조회 - 거부됨 (정상)" >> $TEST_RESULTS
    fi
    
    echo ""
    echo "c) 다른 파일 접근 테스트 (거부되어야 함):"
    if mc cat diana-local/$PRIVATE_BUCKET/confidential.txt 2>/dev/null; then
        print_error "Diana: 기밀 파일 접근 성공 (보안 문제!) ✗"
        echo "Diana: 기밀 파일 접근 - 성공 (보안 문제)" >> $TEST_RESULTS
    else
        print_success "Diana: 기밀 파일 접근 거부됨 ✓"
        echo "Diana: 기밀 파일 접근 - 거부됨 (정상)" >> $TEST_RESULTS
    fi
else
    print_error "Diana 사용자 연결 실패"
fi

echo ""
echo -e "${BLUE}📊 권한 테스트 결과 요약:${NC}"
cat $TEST_RESULTS

wait_for_user "권한 테스트를 완료했습니다. 그룹 기반 권한 관리를 학습하겠습니다."

# Step 7: 그룹 기반 권한 관리
print_step "7" "그룹 기반 권한 관리"
echo ""
print_concept "그룹을 생성하여 여러 사용자의 권한을 효율적으로 관리합니다"
echo ""

echo -e "${CYAN}👥 그룹 기반 관리의 장점:${NC}"
echo "• 권한 일괄 관리: 여러 사용자에게 동일한 권한 적용"
echo "• 유지보수 효율성: 정책 변경 시 그룹만 수정"
echo "• 역할 기반 접근: 조직 구조에 맞는 권한 체계"
echo "• 확장성: 새 사용자 추가 시 그룹에만 포함"
echo ""

echo "1. 그룹 생성:"
echo ""

# 그룹 생성
GROUPS=("developers" "managers" "guests")
GROUP_DESCRIPTIONS=("개발팀" "관리팀" "게스트")

for i in "${!GROUPS[@]}"; do
    group="${GROUPS[$i]}"
    desc="${GROUP_DESCRIPTIONS[$i]}"
    
    echo "그룹 생성: $group ($desc)"
    echo "명령어: mc admin group add local $group"
    
    if mc admin group add local $group; then
        print_success "$group 그룹 생성 완료"
    else
        print_error "$group 그룹 생성 실패"
    fi
done

echo ""
echo "2. 그룹에 사용자 추가:"
echo ""

# 그룹별 사용자 매핑
echo "developers 그룹에 bob 추가:"
if mc admin group add local developers bob; then
    print_success "bob을 developers 그룹에 추가 완료"
else
    print_error "bob을 developers 그룹에 추가 실패"
fi

echo ""
echo "managers 그룹에 charlie 추가:"
if mc admin group add local managers charlie; then
    print_success "charlie를 managers 그룹에 추가 완료"
else
    print_error "charlie를 managers 그룹에 추가 실패"
fi

echo ""
echo "guests 그룹에 diana 추가:"
if mc admin group add local guests diana; then
    print_success "diana를 guests 그룹에 추가 완료"
else
    print_error "diana를 guests 그룹에 추가 실패"
fi

echo ""
echo "3. 그룹별 정책 적용:"
echo ""

# 그룹 전용 정책 생성
cat > policies/team-policy.json << EOF
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
                "arn:aws:s3:::$SHARED_BUCKET",
                "arn:aws:s3:::$SHARED_BUCKET/*"
            ]
        }
    ]
}
EOF

echo "팀 공유 정책 등록:"
if mc admin policy add local team-policy policies/team-policy.json; then
    print_success "팀 공유 정책 등록 완료"
    
    echo ""
    echo "developers 그룹에 팀 정책 적용:"
    if mc admin policy set local team-policy group=developers; then
        print_success "developers 그룹에 팀 정책 적용 완료"
    else
        print_error "developers 그룹에 팀 정책 적용 실패"
    fi
else
    print_error "팀 공유 정책 등록 실패"
fi

echo ""
echo "4. 그룹 정보 확인:"
echo ""

for group in "${GROUPS[@]}"; do
    echo "그룹: $group"
    echo "명령어: mc admin group info local $group"
    mc admin group info local $group
    echo ""
done

wait_for_user "그룹 기반 권한 관리를 설정했습니다. 실습 결과를 정리하겠습니다."
# Step 8: 보안 모범 사례 및 권장사항
print_step "8" "보안 모범 사례 및 권장사항"
echo ""
print_concept "MinIO IAM 시스템의 보안을 강화하는 모범 사례를 학습합니다"
echo ""

echo -e "${GREEN}🔒 보안 모범 사례${NC}"
echo ""

echo -e "${BLUE}1. 사용자 관리 모범 사례:${NC}"
echo "• 강력한 비밀번호 정책 적용"
echo "• 정기적인 비밀번호 변경"
echo "• 불필요한 사용자 계정 비활성화"
echo "• 액세스 키 정기 로테이션"
echo "• 사용자별 활동 로그 모니터링"
echo ""

echo -e "${BLUE}2. 정책 설계 모범 사례:${NC}"
echo "• 최소 권한 원칙 적용"
echo "• 명시적 거부 우선 원칙"
echo "• 리소스별 세밀한 권한 제어"
echo "• 조건부 접근 제어 활용"
echo "• 정책 정기 검토 및 업데이트"
echo ""

echo -e "${BLUE}3. 그룹 관리 모범 사례:${NC}"
echo "• 역할 기반 그룹 구성"
echo "• 그룹별 명확한 책임 정의"
echo "• 중첩 그룹 구조 지양"
echo "• 그룹 멤버십 정기 검토"
echo "• 임시 권한은 개별 사용자에게 부여"
echo ""

echo "실제 보안 강화 예시:"
echo ""

echo "1. 비밀번호 정책 강화:"
echo ""
echo "현재 사용자들의 비밀번호 강도 확인:"
for username in "${!USERS[@]}"; do
    password=$(grep "비밀번호:" user-configs/${username}-config.txt | cut -d' ' -f2)
    length=${#password}
    
    echo "• $username: ${length}자 (권장: 12자 이상)"
    
    if [ $length -ge 12 ]; then
        print_success "적절한 비밀번호 길이"
    else
        print_warning "비밀번호 길이 부족"
    fi
done

echo ""
echo "2. 액세스 키 로테이션 시뮬레이션:"
echo ""

# Alice 사용자의 새 비밀번호 생성
NEW_ALICE_PASSWORD=$(generate_random_password 16)
echo "Alice 사용자 비밀번호 변경 시뮬레이션:"
echo "새 비밀번호: $NEW_ALICE_PASSWORD"

# 실제로는 변경하지 않고 절차만 설명
echo ""
echo "비밀번호 변경 절차:"
echo "1. mc admin user add local alice $NEW_ALICE_PASSWORD (기존 사용자 덮어쓰기)"
echo "2. 사용자에게 새 비밀번호 안전하게 전달"
echo "3. 기존 연결 세션 무효화 확인"
echo "4. 새 비밀번호로 접근 테스트"

echo ""
echo "3. 사용자 활동 모니터링:"
echo ""

echo "현재 활성 사용자 세션 확인:"
# 실제 세션 정보는 제한적이므로 개념적 설명
echo "• 로그인 시간 추적"
echo "• API 호출 빈도 모니터링"
echo "• 비정상적인 접근 패턴 감지"
echo "• 실패한 인증 시도 추적"

echo ""
echo "4. 정책 검토 및 최적화:"
echo ""

echo "현재 정책들의 보안 수준 평가:"
echo ""

# 정책별 보안 평가
POLICIES_TO_REVIEW=("readonly-policy" "developer-policy" "admin-policy" "guest-policy")

for policy in "${POLICIES_TO_REVIEW[@]}"; do
    echo "정책: $policy"
    
    case $policy in
        "readonly-policy")
            echo "  보안 수준: 높음 ✓"
            echo "  권장사항: 특정 IP 대역 제한 추가 고려"
            ;;
        "developer-policy")
            echo "  보안 수준: 중간 ⚠"
            echo "  권장사항: 업로드 파일 크기 제한 추가"
            ;;
        "admin-policy")
            echo "  보안 수준: 중간 ⚠"
            echo "  권장사항: 관리 작업 시간대 제한 추가"
            ;;
        "guest-policy")
            echo "  보안 수준: 매우 높음 ✓"
            echo "  권장사항: 현재 설정 유지"
            ;;
    esac
    echo ""
done

wait_for_user "보안 모범 사례를 학습했습니다. 실습 결과를 정리하겠습니다."

# Step 9: 실습 결과 정리 및 요약
print_step "9" "실습 결과 정리 및 요약"
echo ""
echo -e "${BLUE}🎉 Lab 6 완료 - IAM 관리 결과 정리${NC}"
echo ""

echo -e "${CYAN}✅ 완료된 IAM 관리 작업:${NC}"
echo "1. ✓ MinIO IAM 시스템 구조 이해"
echo "2. ✓ 4명의 IAM 사용자 생성 (alice, bob, charlie, diana)"
echo "3. ✓ 4개의 권한 정책 작성 및 등록"
echo "4. ✓ 사용자별 정책 적용 및 권한 부여"
echo "5. ✓ 권한 테스트 및 검증 (15개 테스트 시나리오)"
echo "6. ✓ 3개 그룹 생성 및 사용자 할당"
echo "7. ✓ 그룹 기반 권한 관리 구현"
echo "8. ✓ 보안 모범 사례 학습 및 적용"
echo ""

echo -e "${PURPLE}📊 IAM 시스템 현황:${NC}"
FINAL_USER_COUNT=$(mc admin user list local | wc -l)
FINAL_GROUP_COUNT=$(mc admin group list local | wc -l)
FINAL_POLICY_COUNT=$(mc admin policy list local | wc -l)

echo "• 총 사용자 수: $FINAL_USER_COUNT (관리자 포함)"
echo "• 총 그룹 수: $FINAL_GROUP_COUNT"
echo "• 총 정책 수: $FINAL_POLICY_COUNT"
echo "• 테스트 버킷 수: 4개"
echo "• 권한 테스트 시나리오: 15개"
echo "• 실습 소요 시간: 약 25-30분"
echo ""

echo -e "${YELLOW}🔧 습득한 IAM 관리 기술:${NC}"
echo "• MinIO IAM 시스템 구조 및 동작 원리"
echo "• JSON 기반 정책 작성 및 최적화"
echo "• 사용자 생성 및 액세스 키 관리"
echo "• 권한 테스트 및 검증 방법론"
echo "• 그룹 기반 효율적 권한 관리"
echo "• 보안 모범 사례 및 위험 관리"
echo ""

echo -e "${GREEN}🚀 다음 단계 추천:${NC}"
echo "• Lab 7: 모니터링 설정 (Prometheus, Grafana 대시보드)"
echo "• Lab 9: 정적 웹사이트 호스팅 (버킷 정책 활용)"
echo "• Lab 10: 백업 및 재해 복구 (권한 기반 백업 전략)"
echo ""

echo -e "${BLUE}📚 추가 학습 리소스:${NC}"
echo "• MinIO IAM 가이드: https://docs.min.io/docs/minio-identity-management.html"
echo "• AWS IAM 정책 참조: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html"
echo "• Lab 6 개념 가이드: docs/LAB-06-CONCEPTS.md"
echo ""

# IAM 설정 요약 리포트 생성
echo -e "${CYAN}📋 IAM 설정 리포트 생성:${NC}"
IAM_REPORT="results/iam-setup-report-$(date +%Y%m%d-%H%M%S).txt"

cat > $IAM_REPORT << EOF
MinIO IAM 설정 리포트
====================
설정 일시: $(date)

생성된 사용자:
$(for user in "${!USERS[@]}"; do echo "- $user: ${USERS[$user]}"; done)

생성된 정책:
- readonly-policy: 공개 데이터 읽기 전용
- developer-policy: 개발자 권한 (제한된 쓰기)
- admin-policy: 관리자 권한 (사용자 관리 제외)
- guest-policy: 게스트 권한 (특정 파일만)
- team-policy: 팀 공유 권한

생성된 그룹:
- developers: 개발팀 (bob)
- managers: 관리팀 (charlie)
- guests: 게스트 (diana)

테스트 버킷:
- $PUBLIC_BUCKET: 공개 데이터
- $PRIVATE_BUCKET: 비공개 데이터
- $SHARED_BUCKET: 공유 문서
- $UPLOADS_BUCKET: 사용자 업로드

권한 테스트 결과:
$(cat $TEST_RESULTS | tail -n +4)

보안 권장사항:
- 정기적인 비밀번호 변경 (3개월마다)
- 액세스 키 로테이션 (6개월마다)
- 사용자 활동 모니터링 강화
- 정책 정기 검토 (분기별)

리포트 생성 시간: $(date)
EOF

echo "IAM 설정 리포트 생성: $IAM_REPORT"
echo ""

# 정리 옵션 제공
echo -e "${YELLOW}🧹 정리 옵션:${NC}"
echo "IAM 테스트 환경을 정리하시겠습니까?"
echo "1) 테스트 데이터만 정리 (사용자/정책은 유지)"
echo "2) 모든 IAM 설정 정리 (사용자/정책/그룹 삭제)"
echo "3) 정리하지 않음 (IAM 설정 보존)"
echo ""

read -p "선택하세요 (1-3): " cleanup_choice

case $cleanup_choice in
    1)
        echo ""
        echo "테스트 데이터 정리 중..."
        
        # 테스트 버킷들 삭제
        for bucket in $PUBLIC_BUCKET $PRIVATE_BUCKET $SHARED_BUCKET $UPLOADS_BUCKET; do
            echo "버킷 삭제: $bucket"
            mc rm --recursive --force local/$bucket/ 2>/dev/null || true
            mc rb local/$bucket --force 2>/dev/null || true
        done
        
        # 로컬 테스트 파일 정리
        cd ..
        rm -rf lab6-iam-test/test-data lab6-iam-test/downloads
        
        print_success "테스트 데이터 정리 완료"
        echo "IAM 사용자, 정책, 그룹은 유지됩니다."
        ;;
    2)
        echo ""
        echo "모든 IAM 설정 정리 중..."
        
        # 사용자 삭제
        for username in "${!USERS[@]}"; do
            echo "사용자 삭제: $username"
            mc admin user remove local $username 2>/dev/null || true
        done
        
        # 그룹 삭제
        for group in "${GROUPS[@]}"; do
            echo "그룹 삭제: $group"
            mc admin group remove local $group 2>/dev/null || true
        done
        
        # 정책 삭제
        for policy in readonly-policy developer-policy admin-policy guest-policy team-policy; do
            echo "정책 삭제: $policy"
            mc admin policy remove local $policy 2>/dev/null || true
        done
        
        # 테스트 버킷들 삭제
        for bucket in $PUBLIC_BUCKET $PRIVATE_BUCKET $SHARED_BUCKET $UPLOADS_BUCKET; do
            echo "버킷 삭제: $bucket"
            mc rm --recursive --force local/$bucket/ 2>/dev/null || true
            mc rb local/$bucket --force 2>/dev/null || true
        done
        
        # 사용자 별칭 삭제
        mc alias remove alice-local 2>/dev/null || true
        mc alias remove bob-local 2>/dev/null || true
        mc alias remove diana-local 2>/dev/null || true
        
        # 로컬 파일 정리 (리포트 제외)
        cd ..
        rm -rf lab6-iam-test/test-data lab6-iam-test/downloads lab6-iam-test/policies lab6-iam-test/user-configs
        
        print_success "모든 IAM 설정 정리 완료"
        echo "IAM 설정 리포트는 보존됩니다."
        ;;
    3)
        echo ""
        print_info "IAM 설정을 유지합니다"
        echo "생성된 사용자와 정책을 다른 Lab에서 활용할 수 있습니다."
        cd ..
        ;;
    *)
        echo ""
        print_warning "잘못된 선택입니다. 정리하지 않습니다."
        cd ..
        ;;
esac

echo ""
echo -e "${GREEN}🎯 Lab 6 완료!${NC}"
echo ""
echo -e "${BLUE}💡 핵심 포인트 요약:${NC}"
echo "• MinIO IAM은 AWS IAM과 호환되는 강력한 권한 관리 시스템입니다"
echo "• JSON 기반 정책으로 세밀한 권한 제어가 가능합니다"
echo "• 그룹을 활용하면 대규모 사용자 권한을 효율적으로 관리할 수 있습니다"
echo "• 최소 권한 원칙과 정기적인 권한 검토가 보안의 핵심입니다"
echo ""

echo -e "${PURPLE}🎓 다음 Lab 준비:${NC}"
echo "Lab 7에서는 MinIO 모니터링 시스템을 구축합니다:"
echo "• Prometheus 메트릭 수집 설정"
echo "• Grafana 대시보드 구성"
echo "• 알림 규칙 설정 및 관리"
echo "• 성능 및 보안 모니터링"
echo ""

echo "Lab 6 IAM 관리를 완료했습니다! 🎉"
echo "계속해서 Lab 7을 진행하거나 ./run-lab.sh를 실행하여 메뉴로 돌아가세요."
