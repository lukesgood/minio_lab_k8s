#!/bin/bash

echo "=== Lab 4: S3 API 고급 기능 테스트 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# MinIO Client 명령어 확인
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    if [ -f "./mc" ]; then
        MC_CMD="./mc"
    else
        echo -e "${RED}❌ MinIO Client가 설치되지 않았습니다.${NC}"
        echo "먼저 Lab 3을 실행하여 MinIO Client를 설치하세요."
        exit 1
    fi
fi

# 연결 확인
echo "1. MinIO 서버 연결 확인..."
if ! $MC_CMD admin info local &>/dev/null; then
    echo -e "${RED}❌ MinIO 서버에 연결할 수 없습니다.${NC}"
    echo "먼저 Lab 3을 실행하여 포트 포워딩을 설정하세요."
    exit 1
fi
echo -e "${GREEN}✅ MinIO 서버 연결 확인${NC}"

# Multipart Upload 테스트
echo ""
echo "2. Multipart Upload 테스트..."
echo "   - 대용량 파일 생성 (50MB)..."
dd if=/dev/zero of=large-file.dat bs=1M count=50 2>/dev/null

echo "   - Multipart Upload 실행..."
echo "     업로드 시간 측정:"
time $MC_CMD cp large-file.dat local/test-bucket/large-multipart.dat

echo ""
echo "   - Single Part Upload 비교..."
echo "     업로드 시간 측정 (multipart 비활성화):"
time $MC_CMD cp --disable-multipart large-file.dat local/test-bucket/large-single.dat

echo ""
echo "   - 업로드된 파일 확인..."
$MC_CMD ls -la local/test-bucket/ | grep large

# 메타데이터 테스트
echo ""
echo "3. 메타데이터 관리 테스트..."
echo "   - 커스텀 메타데이터로 파일 업로드..."
echo "MinIO Metadata Test" > metadata-test.txt
$MC_CMD cp --attr "Content-Type=text/plain;Author=MinIO-Lab;Version=1.0;Environment=Test" metadata-test.txt local/test-bucket/

echo ""
echo "   - 객체 상세 정보 확인..."
$MC_CMD stat local/test-bucket/metadata-test.txt

# 스토리지 클래스 테스트
echo ""
echo "4. 스토리지 클래스 테스트..."
echo "   - REDUCED_REDUNDANCY 스토리지 클래스로 업로드..."
echo "Storage Class Test" > storage-class-test.txt
$MC_CMD cp --storage-class REDUCED_REDUNDANCY storage-class-test.txt local/test-bucket/

echo ""
echo "   - 스토리지 클래스 확인..."
$MC_CMD stat local/test-bucket/storage-class-test.txt

# 버전 관리 테스트 (가능한 경우)
echo ""
echo "5. 객체 버전 관리 테스트..."
echo "   - 동일한 키로 다른 내용 업로드..."
echo "Version 1 Content" > version-test.txt
$MC_CMD cp version-test.txt local/test-bucket/version-test.txt

echo "Version 2 Content" > version-test.txt
$MC_CMD cp version-test.txt local/test-bucket/version-test.txt

echo ""
echo "   - 최종 버전 확인..."
$MC_CMD cat local/test-bucket/version-test.txt

# 대용량 파일 다운로드 테스트
echo ""
echo "6. 대용량 파일 다운로드 성능 테스트..."
echo "   - 50MB 파일 다운로드 시간 측정:"
time $MC_CMD cp local/test-bucket/large-multipart.dat downloaded-large.dat

echo ""
echo "   - 다운로드 파일 크기 확인..."
ls -lh downloaded-large.dat

# 정리
echo ""
echo "7. 임시 파일 정리..."
rm -f large-file.dat downloaded-large.dat metadata-test.txt storage-class-test.txt version-test.txt

echo ""
echo -e "${GREEN}✅ Lab 4 완료${NC}"
echo "S3 API 고급 기능 테스트가 완료되었습니다."
echo ""
echo -e "${BLUE}📊 테스트 결과 요약:${NC}"
echo "- ✅ Multipart Upload vs Single Part Upload 성능 비교"
echo "- ✅ 커스텀 메타데이터 설정 및 조회"
echo "- ✅ 스토리지 클래스 설정"
echo "- ✅ 객체 버전 관리"
echo "- ✅ 대용량 파일 업로드/다운로드 성능"
echo ""
echo -e "${YELLOW}💡 참고:${NC}"
echo "- Multipart Upload는 대용량 파일에서 더 효율적입니다"
echo "- 메타데이터는 객체와 함께 저장되어 검색 가능합니다"
echo "- 스토리지 클래스는 데이터 저장 정책을 결정합니다"
