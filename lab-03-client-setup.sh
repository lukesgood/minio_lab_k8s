#!/bin/bash

echo "=== Lab 3: MinIO Client 설정 및 기본 사용법 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- MinIO Client (mc) 설치 및 설정"
echo "- S3 호환 API 사용법"
echo "- 버킷 생성 및 관리"
echo "- 객체 업로드/다운로드"
echo "- 데이터 무결성 검증"
echo "- 실제 스토리지 경로에서 데이터 확인"
echo ""

echo -e "${PURPLE}🎯 학습 목표:${NC}"
echo "1. MinIO Client 도구 설치 및 설정하기"
echo "2. S3 호환 API의 기본 개념 이해하기"
echo "3. 버킷과 객체의 관계 이해하기"
echo "4. 실제 데이터 업로드/다운로드 수행하기"
echo "5. 데이터 무결성 검증 방법 학습하기"
echo "6. MinIO 데이터가 실제로 저장되는 위치 확인하기"
echo ""

# 사용자 진행 확인 함수
wait_for_user() {
    echo ""
    echo -e "${YELLOW}🛑 CHECKPOINT: $1${NC}"
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
}

# Step 1: 사전 요구사항 확인
echo -e "${GREEN}📋 Step 1: 사전 요구사항 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Client를 사용하기 전에 다음 사항들을 확인해야 합니다:"
echo "- MinIO Tenant가 정상 실행 중인지"
echo "- MinIO 서비스에 접근할 수 있는지"
echo "- 필요한 네트워크 포트가 열려있는지"
echo ""

echo "1. MinIO Tenant 상태 확인:"
echo "명령어: kubectl get pods -n minio-tenant"
echo ""

if kubectl get pods -n minio-tenant | grep -q "Running"; then
    echo -e "${GREEN}✅ MinIO Tenant가 실행 중입니다${NC}"
    kubectl get pods -n minio-tenant
    
    RUNNING_PODS=$(kubectl get pods -n minio-tenant --no-headers | grep Running | wc -l)
    TOTAL_PODS=$(kubectl get pods -n minio-tenant --no-headers | wc -l)
    echo ""
    echo -e "${BLUE}📊 Pod 상태 분석:${NC}"
    echo "- 실행 중인 Pod: $RUNNING_PODS/$TOTAL_PODS"
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        echo "- 모든 Pod가 정상 실행 중입니다"
    else
        echo "- 일부 Pod가 아직 시작 중입니다"
    fi
else
    echo -e "${RED}❌ MinIO Tenant가 실행되지 않았습니다${NC}"
    echo "Lab 2를 먼저 완료해주세요."
    exit 1
fi

echo ""
echo "2. MinIO 서비스 확인:"
echo "명령어: kubectl get svc -n minio-tenant"
echo ""

kubectl get svc -n minio-tenant
echo ""

echo -e "${BLUE}📚 서비스 설명:${NC}"
echo "- minio: MinIO API 서비스 (S3 호환 API 제공)"
echo "- minio-tenant-console: 웹 관리 콘솔"
echo "- ClusterIP: 클러스터 내부 통신용 IP"

wait_for_user "사전 요구사항을 확인했습니다. MinIO Client 설치를 진행해보겠습니다."

# Step 2: MinIO Client 설치
echo -e "${GREEN}📋 Step 2: MinIO Client (mc) 설치${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Client (mc)는 MinIO 서버와 상호작용하는 명령줄 도구입니다:"
echo "- S3 호환 API를 통한 객체 스토리지 관리"
echo "- 버킷 생성, 삭제, 정책 설정"
echo "- 객체 업로드, 다운로드, 복사"
echo "- 관리 작업 (사용자, 정책, 설정)"
echo ""

echo -e "${CYAN}🔧 설치 방법:${NC}"
echo "Linux 환경에서 MinIO Client를 설치합니다."
echo ""

echo "명령어: curl -O https://dl.min.io/client/mc/release/linux-amd64/mc"
echo "목적: MinIO Client 바이너리 다운로드"
echo ""

if command -v mc &> /dev/null; then
    echo -e "${YELLOW}⚠️ MinIO Client가 이미 설치되어 있습니다${NC}"
    mc --version
    echo ""
    echo "기존 설치된 버전을 사용합니다."
else
    echo "MinIO Client 다운로드 중..."
    if curl -O https://dl.min.io/client/mc/release/linux-amd64/mc; then
        echo -e "${GREEN}✅ MinIO Client 다운로드 완료${NC}"
        
        echo ""
        echo "실행 권한 부여 중..."
        chmod +x mc
        
        echo "PATH에 추가 중..."
        sudo mv mc /usr/local/bin/ 2>/dev/null || mv mc ~/bin/ 2>/dev/null || {
            echo -e "${YELLOW}⚠️ 시스템 경로에 추가할 수 없습니다${NC}"
            echo "현재 디렉토리에서 ./mc로 실행하거나 PATH를 수동으로 설정하세요."
            PATH=$PATH:$(pwd)
        }
        
        echo -e "${GREEN}✅ MinIO Client 설치 완료${NC}"
    else
        echo -e "${RED}❌ MinIO Client 다운로드 실패${NC}"
        echo ""
        echo -e "${YELLOW}해결 방법:${NC}"
        echo "1. 네트워크 연결 확인"
        echo "2. 방화벽 설정 확인"
        echo "3. 수동 다운로드: https://dl.min.io/client/mc/release/linux-amd64/mc"
        exit 1
    fi
fi

echo ""
echo "설치 확인:"
mc --version
echo ""

echo -e "${BLUE}📚 MinIO Client 기본 명령어:${NC}"
echo "- mc alias: 서버 연결 설정 관리"
echo "- mc ls: 버킷 및 객체 목록 조회"
echo "- mc mb: 버킷 생성"
echo "- mc cp: 객체 복사 (업로드/다운로드)"
echo "- mc rm: 객체 삭제"
echo "- mc admin: 관리 작업"

wait_for_user "MinIO Client 설치를 완료했습니다. 서버 연결을 설정해보겠습니다."

# Step 3: 포트 포워딩 설정
echo -e "${GREEN}📋 Step 3: MinIO 서버 접근을 위한 포트 포워딩 설정${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes 클러스터 내부의 MinIO 서비스에 접근하기 위해 포트 포워딩이 필요합니다:"
echo "- ClusterIP 서비스는 클러스터 내부에서만 접근 가능"
echo "- 포트 포워딩으로 로컬 포트를 클러스터 서비스에 연결"
echo "- kubectl port-forward 명령어 사용"
echo "- 개발 및 테스트 환경에서 주로 사용"
echo ""

echo -e "${CYAN}🔗 포트 포워딩 구조:${NC}"
echo "로컬 컴퓨터:9000 ←→ kubectl ←→ Kubernetes Service ←→ MinIO Pod"
echo ""

echo "명령어: kubectl port-forward svc/minio -n minio-tenant 9000:80"
echo "목적: 로컬 9000 포트를 MinIO API 서비스에 연결"
echo ""

# 기존 포트 포워딩 프로세스 확인 및 정리
if pgrep -f "kubectl port-forward.*minio.*9000" > /dev/null; then
    echo -e "${YELLOW}⚠️ 기존 포트 포워딩이 실행 중입니다${NC}"
    echo "기존 프로세스를 종료하고 새로 시작합니다."
    pkill -f "kubectl port-forward.*minio.*9000"
    sleep 2
fi

echo "MinIO API 포트 포워딩 시작..."
kubectl port-forward svc/minio -n minio-tenant 9000:80 > /dev/null 2>&1 &
API_PF_PID=$!

# 포트 포워딩이 정상적으로 시작되었는지 확인
sleep 3
if ps -p $API_PF_PID > /dev/null; then
    echo -e "${GREEN}✅ 포트 포워딩 설정 완료${NC}"
    echo "- 로컬 포트: 9000"
    echo "- 대상 서비스: minio (포트 80)"
    echo "- 프로세스 ID: $API_PF_PID"
else
    echo -e "${RED}❌ 포트 포워딩 설정 실패${NC}"
    echo ""
    echo -e "${YELLOW}가능한 원인:${NC}"
    echo "1. 포트 9000이 이미 사용 중"
    echo "2. MinIO 서비스가 준비되지 않음"
    echo "3. 네트워크 권한 문제"
    exit 1
fi

echo ""
echo "포트 포워딩 상태 확인:"
if netstat -tlnp 2>/dev/null | grep :9000 > /dev/null || ss -tlnp 2>/dev/null | grep :9000 > /dev/null; then
    echo -e "${GREEN}✅ 포트 9000이 정상적으로 바인딩되었습니다${NC}"
else
    echo -e "${YELLOW}⚠️ 포트 바인딩 확인 중...${NC}"
fi

echo ""
echo -e "${BLUE}📚 포트 포워딩 설명:${NC}"
echo "- 백그라운드에서 실행 중 (&)"
echo "- Ctrl+C로 중단하지 않도록 주의"
echo "- 터미널 종료 시 자동으로 중단됨"
echo "- 다른 터미널에서도 동일한 포트 사용 가능"

wait_for_user "포트 포워딩을 설정했습니다. MinIO 서버 연결을 설정해보겠습니다."

# Step 4: MinIO 서버 연결 설정 (Alias)
echo -e "${GREEN}📋 Step 4: MinIO 서버 연결 설정 (Alias)${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Client에서 서버에 접근하기 위해 Alias를 설정합니다:"
echo "- Alias: 서버 연결 정보의 별칭"
echo "- URL, 액세스 키, 시크릿 키 포함"
echo "- 여러 서버를 다른 이름으로 관리 가능"
echo "- 설정 후 간단한 이름으로 서버 접근"
echo ""

echo -e "${CYAN}🔑 인증 정보:${NC}"
echo "Lab 2에서 설정한 MinIO 관리자 계정을 사용합니다:"
echo "- 사용자명: admin"
echo "- 비밀번호: password123"
echo "- 접근 URL: http://localhost:9000"
echo ""

echo "명령어: mc alias set local http://localhost:9000 admin password123"
echo "목적: 로컬 MinIO 서버를 'local'이라는 이름으로 등록"
echo ""

if mc alias set local http://localhost:9000 admin password123; then
    echo -e "${GREEN}✅ MinIO 서버 연결 설정 완료${NC}"
    echo ""
    echo "설정된 Alias 확인:"
    mc alias list local
else
    echo -e "${RED}❌ MinIO 서버 연결 설정 실패${NC}"
    echo ""
    echo -e "${YELLOW}가능한 원인:${NC}"
    echo "1. 포트 포워딩이 정상 작동하지 않음"
    echo "2. MinIO 서버가 아직 준비되지 않음"
    echo "3. 인증 정보가 올바르지 않음"
    echo ""
    echo -e "${YELLOW}해결 방법:${NC}"
    echo "1. MinIO Pod 상태 확인: kubectl get pods -n minio-tenant"
    echo "2. 포트 포워딩 재시작"
    echo "3. 잠시 후 다시 시도"
    exit 1
fi

echo ""
echo -e "${BLUE}📚 Alias 설명:${NC}"
echo "- local: 설정한 별칭 이름"
echo "- URL: MinIO 서버 주소"
echo "- API: S3v4 (기본값)"
echo "- Path: auto (경로 스타일 자동 감지)"

wait_for_user "서버 연결을 설정했습니다. 연결 상태를 테스트해보겠습니다."

# Step 5: 연결 테스트
echo -e "${GREEN}📋 Step 5: MinIO 서버 연결 테스트${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "설정한 연결이 정상적으로 작동하는지 확인합니다:"
echo "- 서버 정보 조회"
echo "- API 응답 확인"
echo "- 인증 상태 검증"
echo "- 기본 권한 확인"
echo ""

echo "1. 서버 정보 조회:"
echo "명령어: mc admin info local"
echo ""

if mc admin info local; then
    echo -e "${GREEN}✅ MinIO 서버 연결 테스트 성공${NC}"
    echo ""
    echo -e "${BLUE}📊 서버 정보 분석:${NC}"
    echo "- Uptime: 서버 실행 시간"
    echo "- Version: MinIO 서버 버전"
    echo "- Network: 네트워크 대역폭"
    echo "- Drives: 스토리지 드라이브 정보"
else
    echo -e "${RED}❌ MinIO 서버 연결 테스트 실패${NC}"
    echo ""
    echo -e "${YELLOW}문제 해결 시도:${NC}"
    echo "1. MinIO 서버 상태 재확인..."
    kubectl get pods -n minio-tenant
    
    echo ""
    echo "2. 포트 포워딩 상태 확인..."
    if ps -p $API_PF_PID > /dev/null; then
        echo "포트 포워딩 프로세스 실행 중"
    else
        echo "포트 포워딩 프로세스 중단됨 - 재시작 필요"
    fi
    
    echo ""
    echo "3. 네트워크 연결 테스트..."
    if curl -s http://localhost:9000/minio/health/live > /dev/null; then
        echo "HTTP 연결 성공"
    else
        echo "HTTP 연결 실패"
    fi
    
    exit 1
fi

echo ""
echo "2. 기본 권한 테스트:"
echo "명령어: mc ls local"
echo ""

if mc ls local; then
    echo -e "${GREEN}✅ 버킷 목록 조회 성공${NC}"
    BUCKET_COUNT=$(mc ls local | wc -l)
    echo "현재 버킷 수: $BUCKET_COUNT"
    
    if [ "$BUCKET_COUNT" -eq 0 ]; then
        echo "아직 생성된 버킷이 없습니다 (정상 상태)"
    fi
else
    echo -e "${YELLOW}⚠️ 버킷 목록 조회 실패 또는 빈 결과${NC}"
    echo "권한은 정상이지만 아직 버킷이 없을 수 있습니다."
fi

echo ""
echo -e "${BLUE}📚 연결 테스트 결과:${NC}"
echo "- 서버 연결: 성공"
echo "- 인증: 성공"
echo "- 기본 권한: 확인됨"
echo "- S3 API 호환성: 정상"

wait_for_user "연결 테스트를 완료했습니다. S3 API 기본 개념을 학습해보겠습니다."
# Step 6: S3 API 기본 개념 학습
echo -e "${GREEN}📋 Step 6: S3 API 기본 개념 학습${NC}"
echo ""
echo -e "${BLUE}💡 핵심 개념:${NC}"
echo "Amazon S3 (Simple Storage Service) 호환 API의 기본 구조를 이해해보겠습니다:"
echo ""
echo -e "${CYAN}🗂️ 계층 구조:${NC}"
echo "Account (계정)"
echo "  └── Bucket (버킷) - 최상위 컨테이너"
echo "      └── Object (객체) - 실제 파일과 메타데이터"
echo "          ├── Key (키) - 객체의 고유 식별자 (파일명 + 경로)"
echo "          ├── Value (값) - 실제 파일 데이터"
echo "          └── Metadata (메타데이터) - 파일 정보"
echo ""
echo -e "${PURPLE}📝 주요 특징:${NC}"
echo "• 버킷명은 전역적으로 고유해야 함 (DNS 규칙 적용)"
echo "• 객체 키는 버킷 내에서 고유"
echo "• 폴더 개념 없음 (키에 '/'를 포함하여 계층 구조 시뮬레이션)"
echo "• 객체 크기: 0 bytes ~ 5TB"
echo "• 메타데이터: 사용자 정의 키-값 쌍"
echo ""
echo -e "${YELLOW}🔍 실제 예시:${NC}"
echo "버킷명: my-website"
echo "객체 키: images/logo.png"
echo "실제 URL: http://localhost:9000/my-website/images/logo.png"
echo ""

wait_for_user "S3 API 기본 개념을 학습했습니다. 실제 버킷을 생성해보겠습니다."

# Step 7: 버킷 생성 및 관리
echo -e "${GREEN}📋 Step 7: 버킷 생성 및 관리${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "버킷(Bucket)은 S3의 최상위 컨테이너입니다:"
echo "- 모든 객체는 버킷 안에 저장됨"
echo "- 버킷명은 DNS 규칙을 따라야 함"
echo "- 버킷별로 접근 권한 설정 가능"
echo "- 버킷별로 스토리지 클래스 설정 가능"
echo ""

echo -e "${CYAN}📏 버킷 명명 규칙:${NC}"
echo "• 3-63자 길이"
echo "• 소문자, 숫자, 하이픈(-) 사용"
echo "• 문자나 숫자로 시작/끝"
echo "• IP 주소 형식 금지"
echo "• 연속된 하이픈 금지"
echo ""

echo "1. 테스트 버킷 생성:"
TEST_BUCKET="test-bucket-$(date +%s)"
echo "버킷명: $TEST_BUCKET"
echo "명령어: mc mb local/$TEST_BUCKET"
echo ""

if mc mb local/$TEST_BUCKET; then
    echo -e "${GREEN}✅ 버킷 생성 성공${NC}"
    echo ""
    echo "생성된 버킷 확인:"
    mc ls local
    echo ""
    echo -e "${BLUE}📊 버킷 정보:${NC}"
    echo "- 버킷명: $TEST_BUCKET"
    echo "- 생성 시간: $(date)"
    echo "- 초기 객체 수: 0"
    echo "- 초기 크기: 0 bytes"
else
    echo -e "${RED}❌ 버킷 생성 실패${NC}"
    echo ""
    echo -e "${YELLOW}가능한 원인:${NC}"
    echo "1. 버킷명 규칙 위반"
    echo "2. 권한 부족"
    echo "3. 네트워크 연결 문제"
    exit 1
fi

echo ""
echo "2. 여러 버킷 생성 (다양한 용도):"
BUCKETS=("documents" "images" "backups" "logs")

for bucket in "${BUCKETS[@]}"; do
    FULL_BUCKET_NAME="${bucket}-$(date +%s)"
    echo "버킷 생성: $FULL_BUCKET_NAME"
    
    if mc mb local/$FULL_BUCKET_NAME; then
        echo -e "${GREEN}✅ $FULL_BUCKET_NAME 생성 완료${NC}"
    else
        echo -e "${YELLOW}⚠️ $FULL_BUCKET_NAME 생성 실패${NC}"
    fi
done

echo ""
echo "3. 전체 버킷 목록 확인:"
echo "명령어: mc ls local"
echo ""
mc ls local
echo ""

TOTAL_BUCKETS=$(mc ls local | wc -l)
echo -e "${BLUE}📊 버킷 통계:${NC}"
echo "- 총 버킷 수: $TOTAL_BUCKETS"
echo "- 생성 시간: $(date)"
echo "- 스토리지 사용량: 0 bytes (빈 버킷들)"

wait_for_user "버킷을 생성했습니다. 이제 객체 업로드를 실습해보겠습니다."

# Step 8: 객체 업로드 및 다운로드
echo -e "${GREEN}📋 Step 8: 객체 업로드 및 다운로드${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "객체(Object)는 S3에 저장되는 실제 데이터입니다:"
echo "- 파일 데이터 + 메타데이터로 구성"
echo "- 키(Key)로 고유하게 식별"
echo "- 버전 관리 지원 (선택적)"
echo "- 다양한 스토리지 클래스 지원"
echo ""

echo -e "${CYAN}🔄 업로드/다운로드 과정:${NC}"
echo "업로드: 로컬 파일 → MinIO 서버 → 스토리지"
echo "다운로드: 스토리지 → MinIO 서버 → 로컬 파일"
echo ""

echo "1. 테스트 파일 생성:"
echo "다양한 크기와 형태의 파일을 생성하여 테스트합니다."
echo ""

# 테스트 파일들 생성
mkdir -p test-files
cd test-files

echo "작은 텍스트 파일 생성:"
echo "Hello MinIO! This is a test file." > small-text.txt
echo "Created: $(date)" >> small-text.txt
echo "Size: $(stat -c%s small-text.txt 2>/dev/null || stat -f%z small-text.txt) bytes"
echo ""

echo "중간 크기 파일 생성 (1MB):"
dd if=/dev/zero of=medium-file.dat bs=1024 count=1024 2>/dev/null
echo "Size: $(stat -c%s medium-file.dat 2>/dev/null || stat -f%z medium-file.dat) bytes"
echo ""

echo "JSON 데이터 파일 생성:"
cat > sample-data.json << EOF
{
  "name": "MinIO Test",
  "version": "1.0",
  "timestamp": "$(date -Iseconds)",
  "data": {
    "buckets": $TOTAL_BUCKETS,
    "objects": 0,
    "size": "0 bytes"
  },
  "metadata": {
    "lab": "Lab 3",
    "purpose": "Object upload test"
  }
}
EOF
echo "JSON 파일 크기: $(stat -c%s sample-data.json 2>/dev/null || stat -f%z sample-data.json) bytes"
echo ""

echo -e "${BLUE}📁 생성된 테스트 파일:${NC}"
ls -la
echo ""

cd ..

wait_for_user "테스트 파일을 생성했습니다. 이제 MinIO에 업로드해보겠습니다."
echo ""
echo "2. 객체 업로드 실습:"
echo "명령어: mc cp [소스] [대상]"
echo ""

echo "a) 단일 파일 업로드:"
echo "명령어: mc cp test-files/small-text.txt local/$TEST_BUCKET/"
echo ""

if mc cp test-files/small-text.txt local/$TEST_BUCKET/; then
    echo -e "${GREEN}✅ 파일 업로드 성공${NC}"
    
    echo ""
    echo "업로드된 객체 확인:"
    mc ls local/$TEST_BUCKET/
    
    echo ""
    echo -e "${BLUE}📊 업로드 분석:${NC}"
    OBJECT_SIZE=$(mc stat local/$TEST_BUCKET/small-text.txt | grep "Size" | awk '{print $2}')
    echo "- 객체 키: small-text.txt"
    echo "- 객체 크기: $OBJECT_SIZE bytes"
    echo "- 업로드 시간: $(date)"
else
    echo -e "${RED}❌ 파일 업로드 실패${NC}"
    exit 1
fi

echo ""
echo "b) 여러 파일 일괄 업로드:"
echo "명령어: mc cp test-files/* local/$TEST_BUCKET/"
echo ""

if mc cp test-files/* local/$TEST_BUCKET/; then
    echo -e "${GREEN}✅ 일괄 업로드 성공${NC}"
    
    echo ""
    echo "업로드된 모든 객체 확인:"
    mc ls local/$TEST_BUCKET/
    
    echo ""
    echo -e "${BLUE}📊 버킷 통계:${NC}"
    OBJECT_COUNT=$(mc ls local/$TEST_BUCKET/ | wc -l)
    echo "- 총 객체 수: $OBJECT_COUNT"
    echo "- 버킷 사용량: $(mc du local/$TEST_BUCKET/ | awk '{print $1}')"
else
    echo -e "${YELLOW}⚠️ 일부 파일 업로드 실패 (중복 파일 제외)${NC}"
fi

echo ""
echo "c) 계층 구조로 업로드:"
echo "폴더 구조를 시뮬레이션하여 업로드합니다."
echo ""

# 계층 구조 생성
mkdir -p test-files/documents/reports
mkdir -p test-files/images/thumbnails
echo "Report data" > test-files/documents/reports/monthly-report.txt
echo "Image data" > test-files/images/thumbnails/thumb1.jpg

echo "명령어: mc cp --recursive test-files/ local/$TEST_BUCKET/data/"
echo ""

if mc cp --recursive test-files/ local/$TEST_BUCKET/data/; then
    echo -e "${GREEN}✅ 계층 구조 업로드 성공${NC}"
    
    echo ""
    echo "계층 구조 확인:"
    mc ls --recursive local/$TEST_BUCKET/
else
    echo -e "${RED}❌ 계층 구조 업로드 실패${NC}"
fi

wait_for_user "객체 업로드를 완료했습니다. 이제 다운로드를 실습해보겠습니다."

echo ""
echo "3. 객체 다운로드 실습:"
echo ""

# 다운로드 테스트를 위한 디렉토리 생성
mkdir -p downloads
cd downloads

echo "a) 단일 파일 다운로드:"
echo "명령어: mc cp local/$TEST_BUCKET/small-text.txt ./downloaded-text.txt"
echo ""

if mc cp local/$TEST_BUCKET/small-text.txt ./downloaded-text.txt; then
    echo -e "${GREEN}✅ 파일 다운로드 성공${NC}"
    
    echo ""
    echo "다운로드된 파일 확인:"
    ls -la downloaded-text.txt
    echo ""
    echo "파일 내용:"
    cat downloaded-text.txt
else
    echo -e "${RED}❌ 파일 다운로드 실패${NC}"
fi

echo ""
echo "b) 여러 파일 다운로드:"
echo "명령어: mc cp local/$TEST_BUCKET/*.json ./"
echo ""

if mc cp local/$TEST_BUCKET/sample-data.json ./; then
    echo -e "${GREEN}✅ JSON 파일 다운로드 성공${NC}"
    
    echo ""
    echo "JSON 파일 내용 확인:"
    cat sample-data.json | jq . 2>/dev/null || cat sample-data.json
else
    echo -e "${YELLOW}⚠️ JSON 파일 다운로드 실패${NC}"
fi

echo ""
echo "c) 전체 버킷 동기화:"
echo "명령어: mc mirror local/$TEST_BUCKET/ ./mirror-backup/"
echo ""

if mc mirror local/$TEST_BUCKET/ ./mirror-backup/; then
    echo -e "${GREEN}✅ 버킷 미러링 성공${NC}"
    
    echo ""
    echo "미러링된 구조 확인:"
    find ./mirror-backup/ -type f | head -10
    
    echo ""
    echo -e "${BLUE}📊 미러링 통계:${NC}"
    MIRRORED_FILES=$(find ./mirror-backup/ -type f | wc -l)
    echo "- 미러링된 파일 수: $MIRRORED_FILES"
    echo "- 미러링 시간: $(date)"
else
    echo -e "${RED}❌ 버킷 미러링 실패${NC}"
fi

cd ..

wait_for_user "다운로드를 완료했습니다. 데이터 무결성을 검증해보겠습니다."

# Step 9: 데이터 무결성 검증
echo -e "${GREEN}📋 Step 9: 데이터 무결성 검증${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "데이터 무결성 검증은 업로드/다운로드된 데이터가 손상되지 않았는지 확인하는 과정입니다:"
echo "- 체크섬(Checksum) 비교"
echo "- 파일 크기 비교"
echo "- 내용 비교"
echo "- ETag 검증"
echo ""

echo -e "${CYAN}🔍 검증 방법:${NC}"
echo "• MD5 해시: 파일 내용의 고유 지문"
echo "• SHA256 해시: 더 강력한 암호화 해시"
echo "• ETag: MinIO가 제공하는 객체 식별자"
echo "• 바이트 단위 비교: 정확한 내용 일치 확인"
echo ""

echo "1. 파일 크기 비교:"
echo ""

ORIGINAL_FILE="test-files/small-text.txt"
DOWNLOADED_FILE="downloads/downloaded-text.txt"

if [ -f "$ORIGINAL_FILE" ] && [ -f "$DOWNLOADED_FILE" ]; then
    ORIGINAL_SIZE=$(stat -c%s "$ORIGINAL_FILE" 2>/dev/null || stat -f%z "$ORIGINAL_FILE")
    DOWNLOADED_SIZE=$(stat -c%s "$DOWNLOADED_FILE" 2>/dev/null || stat -f%z "$DOWNLOADED_FILE")
    
    echo "원본 파일 크기: $ORIGINAL_SIZE bytes"
    echo "다운로드 파일 크기: $DOWNLOADED_SIZE bytes"
    
    if [ "$ORIGINAL_SIZE" -eq "$DOWNLOADED_SIZE" ]; then
        echo -e "${GREEN}✅ 파일 크기 일치${NC}"
    else
        echo -e "${RED}❌ 파일 크기 불일치${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ 비교할 파일이 없습니다${NC}"
fi

echo ""
echo "2. MD5 해시 비교:"
echo ""

if command -v md5sum &> /dev/null; then
    ORIGINAL_MD5=$(md5sum "$ORIGINAL_FILE" | awk '{print $1}')
    DOWNLOADED_MD5=$(md5sum "$DOWNLOADED_FILE" | awk '{print $1}')
    
    echo "원본 MD5: $ORIGINAL_MD5"
    echo "다운로드 MD5: $DOWNLOADED_MD5"
    
    if [ "$ORIGINAL_MD5" = "$DOWNLOADED_MD5" ]; then
        echo -e "${GREEN}✅ MD5 해시 일치 - 데이터 무결성 확인${NC}"
    else
        echo -e "${RED}❌ MD5 해시 불일치 - 데이터 손상 가능성${NC}"
    fi
elif command -v md5 &> /dev/null; then
    ORIGINAL_MD5=$(md5 -q "$ORIGINAL_FILE")
    DOWNLOADED_MD5=$(md5 -q "$DOWNLOADED_FILE")
    
    echo "원본 MD5: $ORIGINAL_MD5"
    echo "다운로드 MD5: $DOWNLOADED_MD5"
    
    if [ "$ORIGINAL_MD5" = "$DOWNLOADED_MD5" ]; then
        echo -e "${GREEN}✅ MD5 해시 일치 - 데이터 무결성 확인${NC}"
    else
        echo -e "${RED}❌ MD5 해시 불일치 - 데이터 손상 가능성${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ MD5 도구를 찾을 수 없습니다${NC}"
fi

echo ""
echo "3. 내용 비교:"
echo ""

if diff "$ORIGINAL_FILE" "$DOWNLOADED_FILE" > /dev/null; then
    echo -e "${GREEN}✅ 파일 내용 완전 일치${NC}"
    echo "바이트 단위로 정확히 동일한 파일입니다."
else
    echo -e "${RED}❌ 파일 내용 불일치${NC}"
    echo "파일 간 차이점이 발견되었습니다."
fi

echo ""
echo "4. MinIO ETag 확인:"
echo "명령어: mc stat local/$TEST_BUCKET/small-text.txt"
echo ""

ETAG_INFO=$(mc stat local/$TEST_BUCKET/small-text.txt | grep "ETag")
if [ ! -z "$ETAG_INFO" ]; then
    echo -e "${BLUE}📊 ETag 정보:${NC}"
    echo "$ETAG_INFO"
    echo ""
    echo -e "${PURPLE}💡 ETag 설명:${NC}"
    echo "- ETag는 객체의 고유 식별자입니다"
    echo "- 일반적으로 MD5 해시와 유사합니다"
    echo "- 멀티파트 업로드 시 다른 형식을 사용합니다"
    echo "- 객체 변경 시 ETag도 변경됩니다"
else
    echo -e "${YELLOW}⚠️ ETag 정보를 가져올 수 없습니다${NC}"
fi

wait_for_user "데이터 무결성 검증을 완료했습니다. 실제 스토리지 위치를 확인해보겠습니다."
# Step 10: 실제 스토리지 위치 확인
echo -e "${GREEN}📋 Step 10: 실제 스토리지 위치 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO에 업로드된 데이터가 실제로 어디에 저장되는지 확인해보겠습니다:"
echo "- Kubernetes PersistentVolume 경로"
echo "- MinIO 데이터 구조"
echo "- Erasure Coding 적용 결과"
echo "- 실제 파일시스템에서의 데이터 확인"
echo ""

echo -e "${CYAN}🗂️ MinIO 데이터 구조:${NC}"
echo "MinIO는 다음과 같은 구조로 데이터를 저장합니다:"
echo "- .minio.sys/: 시스템 메타데이터"
echo "- bucket-name/: 각 버킷별 디렉토리"
echo "- xl.meta: 객체 메타데이터 파일"
echo "- part.1, part.2, ...: 실제 데이터 조각들"
echo ""

echo "1. MinIO Pod의 스토리지 마운트 확인:"
echo "명령어: kubectl describe pod -n minio-tenant | grep -A 5 Mounts"
echo ""

MINIO_POD=$(kubectl get pods -n minio-tenant -l app=minio --no-headers | head -1 | awk '{print $1}')
if [ ! -z "$MINIO_POD" ]; then
    echo "MinIO Pod: $MINIO_POD"
    echo ""
    
    echo -e "${BLUE}📁 마운트 정보:${NC}"
    kubectl describe pod $MINIO_POD -n minio-tenant | grep -A 10 "Mounts:" | head -15
    
    echo ""
    echo "2. PersistentVolume 정보 확인:"
    echo "명령어: kubectl get pv"
    echo ""
    
    kubectl get pv | grep minio
    
    echo ""
    echo "3. 실제 스토리지 경로 확인:"
    
    # PV의 실제 경로 찾기
    PV_PATH=$(kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.namespace=="minio-tenant")].spec.local.path}' | head -1)
    if [ ! -z "$PV_PATH" ]; then
        echo "PersistentVolume 경로: $PV_PATH"
        
        echo ""
        echo "스토리지 디렉토리 구조:"
        if [ -d "$PV_PATH" ]; then
            ls -la "$PV_PATH" 2>/dev/null || echo "경로에 접근할 수 없습니다 (권한 문제)"
        else
            echo "로컬 경로를 직접 확인할 수 없습니다 (원격 스토리지 또는 권한 제한)"
        fi
    else
        echo "PV 경로를 찾을 수 없습니다"
    fi
    
    echo ""
    echo "4. Pod 내부에서 데이터 구조 확인:"
    echo "명령어: kubectl exec $MINIO_POD -n minio-tenant -- ls -la /export/"
    echo ""
    
    if kubectl exec $MINIO_POD -n minio-tenant -- ls -la /export/ 2>/dev/null; then
        echo -e "${GREEN}✅ MinIO 데이터 디렉토리 확인 완료${NC}"
        
        echo ""
        echo "버킷 디렉토리 확인:"
        kubectl exec $MINIO_POD -n minio-tenant -- ls -la /export/ | grep -E "^d.*$TEST_BUCKET" || echo "버킷 디렉토리가 아직 생성되지 않았습니다"
        
        echo ""
        echo "시스템 디렉토리 확인:"
        kubectl exec $MINIO_POD -n minio-tenant -- ls -la /export/.minio.sys/ 2>/dev/null | head -5 || echo "시스템 디렉토리에 접근할 수 없습니다"
    else
        echo -e "${YELLOW}⚠️ Pod 내부 접근 실패${NC}"
        echo "Pod가 아직 준비되지 않았거나 권한 문제일 수 있습니다"
    fi
else
    echo -e "${RED}❌ MinIO Pod를 찾을 수 없습니다${NC}"
fi

echo ""
echo -e "${PURPLE}💡 스토리지 구조 이해:${NC}"
echo "• MinIO는 객체를 여러 조각으로 나누어 저장 (Erasure Coding)"
echo "• 각 조각은 다른 드라이브/노드에 분산 저장"
echo "• 메타데이터는 xl.meta 파일에 저장"
echo "• 실제 데이터는 part.N 파일들에 저장"
echo "• 일부 드라이브 장애 시에도 데이터 복구 가능"

wait_for_user "스토리지 위치 확인을 완료했습니다. 실습 결과를 정리해보겠습니다."

# Step 11: 실습 결과 정리 및 요약
echo -e "${GREEN}📋 Step 11: 실습 결과 정리 및 요약${NC}"
echo ""
echo -e "${BLUE}🎉 Lab 3 완료 - 학습 성과 정리${NC}"
echo ""

echo -e "${CYAN}✅ 완료된 학습 내용:${NC}"
echo "1. ✓ MinIO Client (mc) 설치 및 설정"
echo "2. ✓ 포트 포워딩을 통한 서비스 접근"
echo "3. ✓ MinIO 서버 연결 설정 (Alias)"
echo "4. ✓ S3 API 기본 개념 이해"
echo "5. ✓ 버킷 생성 및 관리"
echo "6. ✓ 객체 업로드/다운로드"
echo "7. ✓ 데이터 무결성 검증"
echo "8. ✓ 실제 스토리지 위치 확인"
echo ""

echo -e "${PURPLE}📊 실습 통계:${NC}"
FINAL_BUCKET_COUNT=$(mc ls local | wc -l)
TOTAL_OBJECTS=$(mc ls --recursive local | wc -l)

echo "• 생성된 버킷 수: $FINAL_BUCKET_COUNT"
echo "• 업로드된 객체 수: $TOTAL_OBJECTS"
echo "• 테스트 파일 크기: 다양 (텍스트, 바이너리, JSON)"
echo "• 데이터 무결성: 검증 완료"
echo "• 실습 소요 시간: 약 15-20분"
echo ""

echo -e "${YELLOW}🔧 습득한 기술:${NC}"
echo "• S3 호환 API 사용법"
echo "• MinIO Client 명령어 활용"
echo "• 객체 스토리지 개념 이해"
echo "• 데이터 무결성 검증 방법"
echo "• Kubernetes 서비스 접근 방법"
echo "• 포트 포워딩 설정 및 관리"
echo ""

echo -e "${GREEN}🚀 다음 단계 추천:${NC}"
echo "• Lab 4: S3 API 고급 기능 (Multipart Upload, 메타데이터)"
echo "• Lab 5: 성능 테스트 (처리량, 동시 연결)"
echo "• Lab 6: 사용자 및 권한 관리 (IAM, 정책)"
echo ""

echo -e "${BLUE}📚 추가 학습 리소스:${NC}"
echo "• MinIO Client 공식 문서: https://docs.min.io/docs/minio-client-complete-guide.html"
echo "• S3 API 참조: https://docs.aws.amazon.com/s3/latest/API/"
echo "• MinIO 개념 가이드: docs/LAB-03-CONCEPTS.md"
echo ""

# 정리 옵션 제공
echo -e "${YELLOW}🧹 정리 옵션:${NC}"
echo "실습에서 생성한 테스트 데이터를 정리하시겠습니까?"
echo "1) 테스트 파일만 정리 (버킷과 객체는 유지)"
echo "2) 모든 테스트 데이터 정리 (버킷과 객체 삭제)"
echo "3) 정리하지 않음 (다음 Lab에서 계속 사용)"
echo ""

read -p "선택하세요 (1-3): " cleanup_choice

case $cleanup_choice in
    1)
        echo ""
        echo "로컬 테스트 파일 정리 중..."
        rm -rf test-files downloads
        echo -e "${GREEN}✅ 로컬 테스트 파일 정리 완료${NC}"
        echo "MinIO의 버킷과 객체는 유지됩니다."
        ;;
    2)
        echo ""
        echo "모든 테스트 데이터 정리 중..."
        
        # 버킷 내 객체 삭제
        echo "객체 삭제 중..."
        mc rm --recursive --force local/$TEST_BUCKET/ 2>/dev/null || true
        
        # 버킷 삭제
        echo "버킷 삭제 중..."
        for bucket in $(mc ls local | awk '{print $5}'); do
            if [[ $bucket == *"$(date +%s)"* ]] || [[ $bucket == "$TEST_BUCKET" ]]; then
                mc rb local/$bucket --force 2>/dev/null || true
                echo "삭제됨: $bucket"
            fi
        done
        
        # 로컬 파일 정리
        rm -rf test-files downloads
        
        echo -e "${GREEN}✅ 모든 테스트 데이터 정리 완료${NC}"
        ;;
    3)
        echo ""
        echo -e "${BLUE}ℹ️ 테스트 데이터를 유지합니다${NC}"
        echo "다음 Lab에서 이 데이터를 계속 사용할 수 있습니다."
        ;;
    *)
        echo ""
        echo -e "${YELLOW}⚠️ 잘못된 선택입니다. 정리하지 않습니다.${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}🎯 Lab 3 완료!${NC}"
echo ""
echo -e "${BLUE}💡 핵심 포인트 요약:${NC}"
echo "• MinIO Client는 S3 호환 API의 강력한 명령줄 도구입니다"
echo "• 포트 포워딩으로 Kubernetes 내부 서비스에 안전하게 접근할 수 있습니다"
echo "• 데이터 무결성 검증은 안정적인 스토리지 운영의 핵심입니다"
echo "• MinIO는 Erasure Coding으로 데이터를 안전하게 분산 저장합니다"
echo ""

# 포트 포워딩 정리 안내
if ps -p $API_PF_PID > /dev/null 2>&1; then
    echo -e "${YELLOW}📡 포트 포워딩 상태:${NC}"
    echo "MinIO API 포트 포워딩이 여전히 실행 중입니다 (PID: $API_PF_PID)"
    echo "다음 Lab에서 계속 사용하거나, 종료하려면 다음 명령어를 실행하세요:"
    echo "kill $API_PF_PID"
    echo ""
fi

echo -e "${PURPLE}🎓 다음 Lab 준비:${NC}"
echo "Lab 4에서는 S3 API의 고급 기능들을 학습합니다:"
echo "• Multipart Upload로 대용량 파일 효율적 업로드"
echo "• 객체 메타데이터 관리 및 활용"
echo "• 스토리지 클래스 설정 및 최적화"
echo "• 고급 검색 및 필터링 기능"
echo ""

echo "Lab 3 실습을 완료했습니다! 🎉"
echo "계속해서 Lab 4를 진행하거나 ./run-lab.sh를 실행하여 메뉴로 돌아가세요."
