#!/bin/bash

echo "=== Lab 3: MinIO Client 및 기본 사용법 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# MinIO Client 설치 확인
echo "1. MinIO Client 설치 확인..."
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

# 포트 포워딩 설정
echo ""
echo "2. 포트 포워딩 설정..."
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

# 서버 연결 설정
echo ""
echo "3. MinIO 서버 연결 설정..."
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    MC_CMD="./mc"
fi

$MC_CMD alias set local http://localhost:9000 minio minio123

# 기본 기능 테스트
echo ""
echo "4. 기본 기능 테스트..."
echo "   - 서버 정보 확인..."
$MC_CMD admin info local

echo ""
echo "   - 테스트 버킷 생성..."
$MC_CMD mb local/test-bucket

echo ""
echo "   - 테스트 파일 업로드..."
echo "Hello MinIO from Kubernetes Lab!" > test-file.txt
$MC_CMD cp test-file.txt local/test-bucket/

echo ""
echo "   - 버킷 내용 확인..."
$MC_CMD ls local/test-bucket/

echo ""
echo "   - 파일 다운로드 테스트..."
$MC_CMD cp local/test-bucket/test-file.txt downloaded-test.txt

echo ""
echo "   - 데이터 무결성 확인..."
if diff test-file.txt downloaded-test.txt > /dev/null; then
    echo -e "${GREEN}✅ 데이터 무결성 검증 성공${NC}"
else
    echo -e "${RED}❌ 데이터 무결성 검증 실패${NC}"
fi

# 정리
rm -f test-file.txt downloaded-test.txt

echo ""
echo -e "${GREEN}✅ Lab 3 완료${NC}"
echo "MinIO Client 설정 및 기본 기능 테스트가 완료되었습니다."
echo ""
echo -e "${BLUE}📋 접근 정보:${NC}"
echo "- MinIO API: http://localhost:9000"
echo "- MinIO Console: http://localhost:9001"
echo "- 사용자: minio"
echo "- 비밀번호: minio123"
echo ""
echo -e "${YELLOW}💡 팁:${NC}"
echo "- 포트 포워딩을 중단하려면: pkill -f 'kubectl port-forward.*minio'"
echo "- 웹 콘솔에서 GUI로 버킷 및 객체 관리 가능"
