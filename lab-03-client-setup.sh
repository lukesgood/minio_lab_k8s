#!/bin/bash

echo "=== Lab 3: MinIO Client 및 기본 사용법 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- MinIO Client (mc) 설치 및 설정"
echo "- 포트 포워딩을 통한 서비스 접근"
echo "- S3 호환 API 기본 사용법"
echo "- 실제 스토리지 경로에서 데이터 확인"
echo ""

# 사전 확인: MinIO Tenant 상태
echo -e "${GREEN}사전 확인: MinIO Tenant 상태${NC}"
echo ""

TENANT_STATUS=$(kubectl get tenant minio-tenant -n minio-tenant -o jsonpath='{.status.currentState}' 2>/dev/null)
POD_STATUS=$(kubectl get pods -n minio-tenant -o jsonpath='{.items[0].status.phase}' 2>/dev/null)

echo "Tenant 상태: ${TENANT_STATUS:-Unknown}"
echo "Pod 상태: ${POD_STATUS:-Unknown}"

if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${YELLOW}⚠️  MinIO Pod가 아직 Running 상태가 아닙니다.${NC}"
    echo "Pod 상태 확인:"
    kubectl get pods -n minio-tenant
    echo ""
    echo "계속 진행하지만, Pod가 Running 상태가 될 때까지 기다려야 할 수 있습니다."
    echo ""
fi

# 현재 PV 상태 확인
echo -e "${GREEN}현재 스토리지 상태 확인${NC}"
echo ""
echo "생성된 PV와 스토리지 경로:"
kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path,STATUS:.status.phase,CLAIM:.spec.claimRef.name | grep -E "(NAME|minio-tenant)" || echo "MinIO 관련 PV를 찾을 수 없습니다."
echo ""

# 1. MinIO Client 설치 확인
echo -e "${GREEN}1. MinIO Client 설치 확인${NC}"
echo "명령어: curl https://dl.min.io/client/mc/release/linux-amd64/mc"
echo "목적: MinIO 서버와 상호작용하기 위한 명령줄 도구 설치"
echo ""

if ! command -v mc &> /dev/null; then
    echo "MinIO Client 설치 중..."
    curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
    chmod +x mc
    if sudo mv mc /usr/local/bin/ 2>/dev/null; then
        echo -e "${GREEN}✅ MinIO Client가 /usr/local/bin/에 설치되었습니다.${NC}"
    elif mv mc ~/bin/ 2>/dev/null; then
        echo -e "${GREEN}✅ MinIO Client가 ~/bin/에 설치되었습니다.${NC}"
        echo -e "${YELLOW}⚠️  ~/bin이 PATH에 포함되어 있는지 확인하세요.${NC}"
    else
        echo -e "${YELLOW}⚠️  mc 파일을 PATH에 추가하세요.${NC}"
        echo "현재 디렉토리에 mc 파일이 있습니다. 다음 명령어로 사용하세요: ./mc"
    fi
else
    echo -e "${GREEN}✅ MinIO Client가 이미 설치되어 있습니다.${NC}"
fi

# mc 명령어 경로 확인
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    if [ -f "./mc" ]; then
        MC_CMD="./mc"
        echo "로컬 mc 바이너리 사용: $MC_CMD"
    else
        echo -e "${RED}❌ MinIO Client를 찾을 수 없습니다.${NC}"
        exit 1
    fi
fi

echo ""

# 2. 포트 포워딩 설정
echo -e "${GREEN}2. 포트 포워딩 설정${NC}"
echo "목적: Kubernetes 클러스터 내부 서비스에 로컬에서 접근"
echo "   - 포트 9000: MinIO S3 API"
echo "   - 포트 9001: MinIO 웹 콘솔"
echo ""

echo "기존 포트 포워딩 프로세스 정리..."
pkill -f "kubectl port-forward.*minio" 2>/dev/null || true

echo "새로운 포트 포워딩 설정..."
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
MINIO_PF_PID=$!

kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &
CONSOLE_PF_PID=$!

echo "포트 포워딩 설정 완료 (PID: $MINIO_PF_PID, $CONSOLE_PF_PID)"
echo "연결 대기 중..."
sleep 5

echo ""

# 3. 서버 연결 설정
echo -e "${GREEN}3. MinIO 서버 연결 설정${NC}"
echo "명령어: mc alias set local http://localhost:9000 minio minio123"
echo "목적: MinIO 서버에 대한 연결 별칭 생성"
echo "   - 별칭: local"
echo "   - 엔드포인트: http://localhost:9000"
echo "   - 사용자: minio"
echo "   - 비밀번호: minio123"
echo ""

$MC_CMD alias set local http://localhost:9000 minio minio123

echo -e "${GREEN}✅ 서버 연결 설정 완료${NC}"
echo ""

# 4. 연결 테스트
echo -e "${GREEN}4. 서버 연결 테스트${NC}"
echo "명령어: mc admin info local"
echo "목적: MinIO 서버 상태 및 정보 확인"
echo ""

if $MC_CMD admin info local; then
    echo -e "${GREEN}✅ MinIO 서버 연결 성공${NC}"
else
    echo -e "${RED}❌ MinIO 서버 연결 실패${NC}"
    echo "Pod 상태를 다시 확인해주세요:"
    kubectl get pods -n minio-tenant
    echo ""
    echo "포트 포워딩 상태 확인:"
    ps aux | grep "kubectl port-forward" | grep -v grep
    exit 1
fi

echo ""

# 5. 기본 기능 테스트
echo -e "${GREEN}5. 기본 S3 기능 테스트${NC}"
echo ""

echo -e "${BLUE}5-1. 테스트 버킷 생성${NC}"
echo "명령어: mc mb local/test-bucket"
echo "목적: S3 버킷 생성 기능 테스트"
echo ""

$MC_CMD mb local/test-bucket
echo -e "${GREEN}✅ 테스트 버킷 생성 완료${NC}"
echo ""

echo -e "${BLUE}5-2. 테스트 파일 업로드${NC}"
echo "명령어: mc cp test-file.txt local/test-bucket/"
echo "목적: S3 객체 업로드 기능 테스트"
echo ""

echo "Hello MinIO from Kubernetes Lab!" > test-file.txt
echo "현재 시간: $(date)" >> test-file.txt
echo "호스트명: $(hostname)" >> test-file.txt

$MC_CMD cp test-file.txt local/test-bucket/
echo -e "${GREEN}✅ 파일 업로드 완료${NC}"
echo ""

echo -e "${BLUE}5-3. 버킷 내용 확인${NC}"
echo "명령어: mc ls local/test-bucket/"
echo "목적: 업로드된 객체 목록 확인"
echo ""

$MC_CMD ls local/test-bucket/
echo ""

echo -e "${BLUE}5-4. 파일 다운로드 테스트${NC}"
echo "명령어: mc cp local/test-bucket/test-file.txt downloaded-test.txt"
echo "목적: S3 객체 다운로드 기능 테스트"
echo ""

$MC_CMD cp local/test-bucket/test-file.txt downloaded-test.txt
echo -e "${GREEN}✅ 파일 다운로드 완료${NC}"
echo ""

echo -e "${BLUE}5-5. 데이터 무결성 검증${NC}"
echo "명령어: diff test-file.txt downloaded-test.txt"
echo "목적: 업로드/다운로드 과정에서 데이터 손실 없음 확인"
echo ""

if diff test-file.txt downloaded-test.txt > /dev/null; then
    echo -e "${GREEN}✅ 데이터 무결성 검증 성공${NC}"
    echo "원본 파일과 다운로드된 파일이 동일합니다."
else
    echo -e "${RED}❌ 데이터 무결성 검증 실패${NC}"
    echo "파일 내용이 다릅니다!"
fi

echo ""

# 6. 실제 스토리지 경로에서 데이터 확인
echo -e "${GREEN}6. 실제 스토리지 경로에서 데이터 확인${NC}"
echo ""
echo -e "${BLUE}📖 스토리지 경로 이해:${NC}"
echo "MinIO는 업로드된 데이터를 실제 파일 시스템에 저장합니다."
echo "동적 프로비저닝으로 생성된 PV의 실제 경로를 확인해보겠습니다."
echo ""

# PV 경로 확인
echo "현재 PV 경로 정보:"
PV_PATHS=$(kubectl get pv -o jsonpath='{range .items[*]}{.spec.local.path}{"\n"}{end}' | grep -v "^$")

if [ -n "$PV_PATHS" ]; then
    echo "$PV_PATHS" | while read -r path; do
        echo "   PV 경로: $path"
        
        # 경로가 접근 가능한지 확인 (로컬 클러스터의 경우)
        if [ -d "$path" ]; then
            echo "     ✅ 경로 접근 가능"
            echo "     디렉토리 내용:"
            ls -la "$path" 2>/dev/null | head -5 | sed 's/^/       /'
            
            # MinIO 데이터 구조 확인
            if find "$path" -name "*.xl.meta" 2>/dev/null | head -1 | grep -q "xl.meta"; then
                echo "     ✅ MinIO 데이터 파일 발견 (.xl.meta 파일)"
            fi
        else
            echo "     ⚠️  경로에 직접 접근할 수 없음 (원격 노드이거나 권한 없음)"
        fi
        echo ""
    done
else
    echo "   PV 경로 정보를 가져올 수 없습니다."
fi

echo -e "${BLUE}💡 참고:${NC}"
echo "   - MinIO는 Erasure Coding을 사용하여 데이터를 여러 파일로 분산 저장"
echo "   - .xl.meta 파일은 MinIO의 메타데이터 파일"
echo "   - 실제 데이터는 바이너리 형태로 저장되어 직접 읽기 어려움"
echo ""

# 7. 웹 콘솔 접근 정보
echo -e "${GREEN}7. MinIO 웹 콘솔 접근${NC}"
echo ""
echo -e "${BLUE}📋 웹 콘솔 접근 정보:${NC}"
echo "   URL: http://localhost:9001"
echo "   사용자명: minio"
echo "   비밀번호: minio123"
echo ""
echo -e "${YELLOW}💡 웹 콘솔에서 할 수 있는 작업:${NC}"
echo "   - 버킷 및 객체 시각적 관리"
echo "   - 서버 상태 모니터링"
echo "   - 사용자 및 정책 관리"
echo "   - 메트릭 및 로그 확인"
echo ""

# 정리
echo -e "${GREEN}8. 임시 파일 정리${NC}"
rm -f test-file.txt downloaded-test.txt

echo ""
echo -e "${GREEN}✅ Lab 3 완료${NC}"
echo "MinIO Client 설정 및 기본 기능 테스트가 완료되었습니다."
echo ""
echo -e "${BLUE}📋 완료된 작업 요약:${NC}"
echo "   - ✅ MinIO Client 설치 및 설정"
echo "   - ✅ 포트 포워딩으로 서비스 접근 설정"
echo "   - ✅ S3 API 기본 기능 테스트 (버킷 생성, 파일 업로드/다운로드)"
echo "   - ✅ 데이터 무결성 검증"
echo "   - ✅ 실제 스토리지 경로 확인"
echo "   - ✅ 웹 콘솔 접근 정보 제공"
echo ""
echo -e "${BLUE}💡 학습 포인트:${NC}"
echo "   - 동적 프로비저닝으로 생성된 PV에 실제 데이터가 저장됨"
echo "   - MinIO는 S3 호환 API를 제공하여 표준 S3 도구 사용 가능"
echo "   - 포트 포워딩을 통해 클러스터 내부 서비스에 안전하게 접근"
echo ""
echo -e "${GREEN}🚀 다음 단계: S3 API 고급 기능 (Lab 4)${NC}"
echo "   명령어: ./lab-04-advanced-s3.sh"
echo ""
echo -e "${YELLOW}💡 팁:${NC}"
echo "   - 포트 포워딩을 중단하려면: pkill -f 'kubectl port-forward.*minio'"
echo "   - 웹 콘솔에서 GUI로 버킷 및 객체 관리 가능"
