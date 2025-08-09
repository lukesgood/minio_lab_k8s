#!/bin/bash

echo "=== Lab 5: 성능 테스트 ==="
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

# 성능 테스트용 버킷 생성
echo ""
echo "2. 성능 테스트용 버킷 생성..."
$MC_CMD mb local/perf-test-bucket 2>/dev/null || echo "버킷이 이미 존재합니다."

# 다양한 크기의 파일 테스트
echo ""
echo "3. 다양한 파일 크기별 성능 테스트..."
echo -e "${BLUE}파일 크기별 업로드/다운로드 성능 측정:${NC}"

for size in 1 5 10 25 50; do
    echo ""
    echo "   📁 ${size}MB 파일 테스트..."
    
    # 파일 생성
    echo "      - 파일 생성 중..."
    dd if=/dev/zero of=test-${size}mb.dat bs=1M count=${size} 2>/dev/null
    
    # 업로드 성능 측정
    echo "      - 업로드 성능 측정:"
    UPLOAD_START=$(date +%s.%N)
    $MC_CMD cp test-${size}mb.dat local/perf-test-bucket/perf-${size}mb.dat
    UPLOAD_END=$(date +%s.%N)
    UPLOAD_TIME=$(echo "$UPLOAD_END - $UPLOAD_START" | bc -l 2>/dev/null || echo "N/A")
    
    if [ "$UPLOAD_TIME" != "N/A" ]; then
        UPLOAD_SPEED=$(echo "scale=2; $size / $UPLOAD_TIME" | bc -l 2>/dev/null || echo "N/A")
        echo "        업로드 시간: ${UPLOAD_TIME}초, 속도: ${UPLOAD_SPEED} MB/s"
    else
        echo "        업로드 완료 (시간 측정 불가)"
    fi
    
    # 다운로드 성능 측정
    echo "      - 다운로드 성능 측정:"
    DOWNLOAD_START=$(date +%s.%N)
    $MC_CMD cp local/perf-test-bucket/perf-${size}mb.dat downloaded-${size}mb.dat
    DOWNLOAD_END=$(date +%s.%N)
    DOWNLOAD_TIME=$(echo "$DOWNLOAD_END - $DOWNLOAD_START" | bc -l 2>/dev/null || echo "N/A")
    
    if [ "$DOWNLOAD_TIME" != "N/A" ]; then
        DOWNLOAD_SPEED=$(echo "scale=2; $size / $DOWNLOAD_TIME" | bc -l 2>/dev/null || echo "N/A")
        echo "        다운로드 시간: ${DOWNLOAD_TIME}초, 속도: ${DOWNLOAD_SPEED} MB/s"
    else
        echo "        다운로드 완료 (시간 측정 불가)"
    fi
    
    # 임시 파일 정리
    rm -f test-${size}mb.dat downloaded-${size}mb.dat
done

# 다중 파일 업로드 테스트
echo ""
echo "4. 다중 파일 동시 업로드 테스트..."
echo "   - 10개의 1MB 파일 생성..."
for i in {1..10}; do
    dd if=/dev/zero of=multi-${i}.dat bs=1M count=1 2>/dev/null
done

echo "   - 동시 업로드 성능 측정:"
MULTI_START=$(date +%s.%N)
$MC_CMD cp multi-*.dat local/perf-test-bucket/
MULTI_END=$(date +%s.%N)
MULTI_TIME=$(echo "$MULTI_END - $MULTI_START" | bc -l 2>/dev/null || echo "N/A")

if [ "$MULTI_TIME" != "N/A" ]; then
    MULTI_SPEED=$(echo "scale=2; 10 / $MULTI_TIME" | bc -l 2>/dev/null || echo "N/A")
    echo "     총 시간: ${MULTI_TIME}초, 평균 속도: ${MULTI_SPEED} MB/s"
else
    echo "     업로드 완료 (시간 측정 불가)"
fi

# 정리
rm -f multi-*.dat

# 동시 연결 테스트
echo ""
echo "5. 동시 연결 성능 테스트..."
echo "   - 5개의 동시 다운로드 작업 실행..."

# 백그라운드로 5개의 다운로드 작업 실행
CONCURRENT_START=$(date +%s.%N)
for i in {1..5}; do
    $MC_CMD cp local/perf-test-bucket/perf-10mb.dat concurrent-${i}.dat &
done

# 모든 백그라운드 작업 완료 대기
wait

CONCURRENT_END=$(date +%s.%N)
CONCURRENT_TIME=$(echo "$CONCURRENT_END - $CONCURRENT_START" | bc -l 2>/dev/null || echo "N/A")

if [ "$CONCURRENT_TIME" != "N/A" ]; then
    CONCURRENT_SPEED=$(echo "scale=2; 50 / $CONCURRENT_TIME" | bc -l 2>/dev/null || echo "N/A")
    echo "     동시 다운로드 시간: ${CONCURRENT_TIME}초, 총 처리량: ${CONCURRENT_SPEED} MB/s"
else
    echo "     동시 다운로드 완료 (시간 측정 불가)"
fi

# 정리
rm -f concurrent-*.dat

# 스토리지 사용량 확인
echo ""
echo "6. 스토리지 사용량 확인..."
echo "   - 버킷 사용량:"
$MC_CMD du local/perf-test-bucket

echo ""
echo "   - 전체 서버 정보:"
$MC_CMD admin info local

# 성능 테스트 정리
echo ""
echo "7. 성능 테스트 데이터 정리..."
$MC_CMD rm --recursive --force local/perf-test-bucket/
$MC_CMD rb local/perf-test-bucket

echo ""
echo -e "${GREEN}✅ Lab 5 완료${NC}"
echo "성능 테스트가 완료되었습니다."
echo ""
echo -e "${BLUE}📊 성능 테스트 요약:${NC}"
echo "- ✅ 다양한 파일 크기별 업로드/다운로드 성능 측정"
echo "- ✅ 다중 파일 동시 업로드 성능"
echo "- ✅ 동시 연결 처리 성능"
echo "- ✅ 스토리지 사용량 모니터링"
echo ""
echo -e "${YELLOW}💡 성능 최적화 팁:${NC}"
echo "- 대용량 파일은 Multipart Upload 사용"
echo "- 동시 연결 수를 적절히 조절"
echo "- 네트워크 대역폭과 스토리지 성능 고려"
echo "- 단일 노드 환경에서는 로컬 I/O 성능이 주요 병목"
