#!/bin/bash

# Lab 4: S3 API 고급 기능
# Multipart Upload, 메타데이터 관리, 스토리지 클래스 활용 실습
# 학습 목표: 대용량 파일 처리, 메타데이터 활용, 고급 S3 API 기능

set -e

echo "=== Lab 4: S3 API 고급 기능 ==="
echo "🎯 학습 목표:"
echo "   • Multipart Upload를 통한 대용량 파일 효율적 처리"
echo "   • 객체 메타데이터 관리 및 활용"
echo "   • 스토리지 클래스 설정 및 최적화"
echo "   • 고급 검색 및 필터링 기능"
echo "   • 객체 생명주기 관리"
echo "   • 성능 최적화 기법"
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
    
    echo ""
    print_success "사전 요구사항 확인 완료"
    echo ""
}

create_test_bucket() {
    local bucket_name="advanced-test-$(date +%s)"
    echo "$bucket_name"
}

generate_large_file() {
    local filename=$1
    local size_mb=$2
    
    echo "대용량 테스트 파일 생성: $filename (${size_mb}MB)"
    dd if=/dev/zero of="$filename" bs=1M count=$size_mb 2>/dev/null
    
    if [ -f "$filename" ]; then
        local actual_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
        print_success "파일 생성 완료: $filename (${actual_size} bytes)"
        return 0
    else
        print_error "파일 생성 실패: $filename"
        return 1
    fi
}

calculate_file_hash() {
    local filename=$1
    
    if command -v sha256sum &> /dev/null; then
        sha256sum "$filename" | awk '{print $1}'
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$filename" | awk '{print $1}'
    else
        echo "hash_unavailable"
    fi
}

format_bytes() {
    local bytes=$1
    
    if [ $bytes -ge 1073741824 ]; then
        echo "$(($bytes / 1073741824))GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(($bytes / 1048576))MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(($bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}
# 메인 실습 시작
echo -e "${PURPLE}🎓 Lab 4: S3 API 고급 기능 실습${NC}"
echo ""
echo -e "${BLUE}📚 이 Lab에서 배우는 내용:${NC}"
echo "• Multipart Upload vs Single Part Upload 비교"
echo "• 대용량 파일 처리 최적화 기법"
echo "• 객체 메타데이터 설정 및 활용"
echo "• 스토리지 클래스 및 생명주기 관리"
echo "• 고급 검색 및 필터링"
echo "• 성능 모니터링 및 최적화"
echo ""

# 사전 요구사항 확인
check_prerequisites

# Step 1: 실습 환경 준비
print_step "1" "실습 환경 준비"
echo ""
print_concept "실습을 위한 테스트 환경을 구성합니다"
echo ""

# 테스트 버킷 생성
TEST_BUCKET=$(create_test_bucket)
echo "테스트 버킷 생성: $TEST_BUCKET"

if mc mb local/$TEST_BUCKET; then
    print_success "테스트 버킷 생성 완료"
else
    print_error "테스트 버킷 생성 실패"
    exit 1
fi

# 작업 디렉토리 생성
mkdir -p lab4-advanced-test
cd lab4-advanced-test

echo ""
echo -e "${BLUE}📁 작업 디렉토리 구조:${NC}"
echo "lab4-advanced-test/"
echo "├── small-files/     # 작은 파일들"
echo "├── large-files/     # 대용량 파일들"
echo "├── metadata-test/   # 메타데이터 테스트"
echo "└── downloads/       # 다운로드 테스트"

mkdir -p small-files large-files metadata-test downloads

wait_for_user "실습 환경 준비를 완료했습니다. Multipart Upload를 학습해보겠습니다."

# Step 2: Multipart Upload 개념 및 실습
print_step "2" "Multipart Upload 개념 및 실습"
echo ""
print_concept "Multipart Upload는 대용량 파일을 여러 부분으로 나누어 병렬로 업로드하는 기술입니다"
echo ""

echo -e "${CYAN}🔄 Multipart Upload 장점:${NC}"
echo "• 대용량 파일의 안정적 업로드"
echo "• 네트워크 장애 시 부분 재시도 가능"
echo "• 병렬 업로드로 성능 향상"
echo "• 업로드 중 일시정지/재개 가능"
echo "• 메모리 사용량 최적화"
echo ""

echo -e "${YELLOW}📏 Multipart Upload 기준:${NC}"
echo "• MinIO 기본 임계값: 64MB"
echo "• 최소 파트 크기: 5MB (마지막 파트 제외)"
echo "• 최대 파트 수: 10,000개"
echo "• 최대 객체 크기: 5TB"
echo ""

echo "1. 작은 파일 업로드 (Single Part):"
echo ""

# 작은 파일 생성 및 업로드
echo "작은 테스트 파일 생성 (1MB):"
generate_large_file "small-files/small-1mb.dat" 1

echo ""
echo "Single Part 업로드 테스트:"
echo "명령어: mc cp small-files/small-1mb.dat local/$TEST_BUCKET/"

start_time=$(date +%s)
if mc cp small-files/small-1mb.dat local/$TEST_BUCKET/; then
    end_time=$(date +%s)
    upload_time=$((end_time - start_time))
    print_success "Single Part 업로드 완료 (소요시간: ${upload_time}초)"
    
    echo ""
    echo "업로드된 객체 정보:"
    mc stat local/$TEST_BUCKET/small-1mb.dat
else
    print_error "Single Part 업로드 실패"
fi

echo ""
echo "2. 대용량 파일 업로드 (Multipart):"
echo ""

# 대용량 파일 생성
echo "대용량 테스트 파일 생성 (100MB):"
generate_large_file "large-files/large-100mb.dat" 100

echo ""
echo "Multipart Upload 테스트:"
echo "명령어: mc cp large-files/large-100mb.dat local/$TEST_BUCKET/"
echo ""

print_info "MinIO Client가 자동으로 Multipart Upload를 사용합니다"
echo ""

start_time=$(date +%s)
if mc cp large-files/large-100mb.dat local/$TEST_BUCKET/; then
    end_time=$(date +%s)
    upload_time=$((end_time - start_time))
    print_success "Multipart 업로드 완료 (소요시간: ${upload_time}초)"
    
    echo ""
    echo "업로드된 객체 정보:"
    mc stat local/$TEST_BUCKET/large-100mb.dat
    
    echo ""
    echo -e "${BLUE}📊 업로드 성능 비교:${NC}"
    echo "• 1MB 파일: Single Part 방식"
    echo "• 100MB 파일: Multipart 방식"
    echo "• 성능 차이: 대용량 파일에서 Multipart가 더 안정적"
else
    print_error "Multipart 업로드 실패"
fi

echo ""
echo "3. Multipart Upload 과정 상세 분석:"
echo ""

print_concept "MinIO Client의 내부 동작을 이해해보겠습니다"
echo ""

echo -e "${PURPLE}🔍 Multipart Upload 단계:${NC}"
echo "1. Initiate Multipart Upload - 업로드 세션 시작"
echo "2. Upload Parts - 각 파트를 병렬로 업로드"
echo "3. Complete Multipart Upload - 모든 파트를 결합"
echo ""

# 수동 Multipart Upload 시뮬레이션 (개념 설명용)
echo "수동 Multipart Upload 시뮬레이션:"
echo ""

# 파일을 여러 부분으로 분할
LARGE_FILE="large-files/large-100mb.dat"
PART_SIZE=20971520  # 20MB

echo "파일 분할 (20MB 단위):"
split -b $PART_SIZE "$LARGE_FILE" "large-files/part-"

echo "생성된 파트 파일들:"
ls -la large-files/part-* | head -5

PART_COUNT=$(ls large-files/part-* | wc -l)
echo "총 파트 수: $PART_COUNT"

wait_for_user "Multipart Upload를 학습했습니다. 메타데이터 관리를 실습해보겠습니다."

# Step 3: 객체 메타데이터 관리
print_step "3" "객체 메타데이터 관리"
echo ""
print_concept "메타데이터는 객체에 대한 추가 정보를 저장하는 키-값 쌍입니다"
echo ""

echo -e "${CYAN}📋 메타데이터 유형:${NC}"
echo "• 시스템 메타데이터: Content-Type, Content-Length, ETag 등"
echo "• 사용자 메타데이터: 사용자 정의 키-값 쌍"
echo "• HTTP 헤더: Cache-Control, Expires 등"
echo "• 태그: 객체 분류 및 관리용"
echo ""

echo -e "${YELLOW}🏷️ 메타데이터 활용 사례:${NC}"
echo "• 파일 분류 및 검색"
echo "• 접근 제어 및 권한 관리"
echo "• 캐싱 정책 설정"
echo "• 데이터 생명주기 관리"
echo "• 비즈니스 로직 구현"
echo ""

echo "1. 기본 메타데이터 설정:"
echo ""

# 메타데이터가 포함된 파일 생성
cat > metadata-test/document.txt << EOF
이것은 메타데이터 테스트용 문서입니다.
작성일: $(date)
작성자: MinIO Lab 사용자
버전: 1.0
카테고리: 테스트 문서
EOF

echo "테스트 문서 생성 완료"
echo "파일 내용:"
cat metadata-test/document.txt
echo ""

echo "메타데이터와 함께 업로드:"
echo "명령어: mc cp --attr 'Author=MinIO-Lab,Category=Test,Version=1.0' metadata-test/document.txt local/$TEST_BUCKET/"
echo ""

if mc cp --attr "Author=MinIO-Lab,Category=Test,Version=1.0,Department=Engineering,Project=Lab4" metadata-test/document.txt local/$TEST_BUCKET/; then
    print_success "메타데이터 업로드 완료"
    
    echo ""
    echo "업로드된 객체의 메타데이터 확인:"
    mc stat local/$TEST_BUCKET/document.txt
    
    echo ""
    echo -e "${BLUE}📊 메타데이터 분석:${NC}"
    echo "• Author: 문서 작성자 정보"
    echo "• Category: 문서 분류"
    echo "• Version: 문서 버전"
    echo "• Department: 부서 정보"
    echo "• Project: 프로젝트 정보"
else
    print_error "메타데이터 업로드 실패"
fi

echo ""
echo "2. Content-Type 설정:"
echo ""

# 다양한 파일 형식 생성
echo '{"name": "test", "value": 123}' > metadata-test/data.json
echo '<html><body><h1>Test</h1></body></html>' > metadata-test/page.html
echo 'body { color: blue; }' > metadata-test/style.css

echo "다양한 Content-Type으로 업로드:"
echo ""

# JSON 파일
echo "JSON 파일 업로드:"
if mc cp --attr "Content-Type=application/json" metadata-test/data.json local/$TEST_BUCKET/; then
    print_success "JSON 파일 업로드 완료"
fi

# HTML 파일
echo "HTML 파일 업로드:"
if mc cp --attr "Content-Type=text/html" metadata-test/page.html local/$TEST_BUCKET/; then
    print_success "HTML 파일 업로드 완료"
fi

# CSS 파일
echo "CSS 파일 업로드:"
if mc cp --attr "Content-Type=text/css" metadata-test/style.css local/$TEST_BUCKET/; then
    print_success "CSS 파일 업로드 완료"
fi

echo ""
echo "업로드된 파일들의 Content-Type 확인:"
for file in data.json page.html style.css; do
    echo ""
    echo "파일: $file"
    mc stat local/$TEST_BUCKET/$file | grep "Content-Type" || echo "Content-Type 정보 없음"
done

wait_for_user "메타데이터 관리를 학습했습니다. 고급 검색 및 필터링을 실습해보겠습니다."
# Step 4: 고급 검색 및 필터링
print_step "4" "고급 검색 및 필터링"
echo ""
print_concept "MinIO는 다양한 방법으로 객체를 검색하고 필터링할 수 있습니다"
echo ""

echo -e "${CYAN}🔍 검색 방법:${NC}"
echo "• 프리픽스 기반 검색: 객체 키의 시작 부분으로 검색"
echo "• 와일드카드 검색: 패턴 매칭을 통한 검색"
echo "• 메타데이터 기반 검색: 사용자 정의 메타데이터로 검색"
echo "• 시간 기반 필터링: 생성/수정 시간으로 필터링"
echo "• 크기 기반 필터링: 파일 크기로 필터링"
echo ""

echo "1. 프리픽스 기반 검색:"
echo ""

# 계층 구조 시뮬레이션을 위한 파일 업로드
echo "계층 구조 파일 생성 및 업로드:"

# 다양한 경로의 파일들 생성
mkdir -p metadata-test/{images,documents,logs,backups}

echo "이미지 파일" > metadata-test/images/photo1.jpg
echo "이미지 파일" > metadata-test/images/photo2.png
echo "문서 파일" > metadata-test/documents/report.pdf
echo "문서 파일" > metadata-test/documents/manual.docx
echo "로그 파일" > metadata-test/logs/app.log
echo "로그 파일" > metadata-test/logs/error.log
echo "백업 파일" > metadata-test/backups/db-backup.sql

# 파일들 업로드
echo "계층 구조로 파일 업로드:"
if mc cp --recursive metadata-test/ local/$TEST_BUCKET/metadata-test/; then
    print_success "계층 구조 업로드 완료"
else
    print_warning "일부 파일 업로드 실패"
fi

echo ""
echo "전체 객체 목록:"
mc ls --recursive local/$TEST_BUCKET/

echo ""
echo "프리픽스 검색 예시:"
echo ""

echo "a) 'images/' 프리픽스로 검색:"
echo "명령어: mc ls local/$TEST_BUCKET/metadata-test/images/"
mc ls local/$TEST_BUCKET/metadata-test/images/

echo ""
echo "b) 'logs/' 프리픽스로 검색:"
echo "명령어: mc ls local/$TEST_BUCKET/metadata-test/logs/"
mc ls local/$TEST_BUCKET/metadata-test/logs/

echo ""
echo "c) 특정 확장자 검색 (*.log):"
echo "명령어: mc find local/$TEST_BUCKET/ --name '*.log'"
mc find local/$TEST_BUCKET/ --name "*.log" 2>/dev/null || echo "find 명령어를 지원하지 않습니다"

echo ""
echo "2. 시간 기반 필터링:"
echo ""

print_concept "객체의 생성 시간을 기준으로 필터링할 수 있습니다"
echo ""

echo "최근 생성된 객체 목록 (상세 정보 포함):"
echo "명령어: mc ls --recursive local/$TEST_BUCKET/ | head -10"
mc ls --recursive local/$TEST_BUCKET/ | head -10

echo ""
echo "3. 크기 기반 필터링:"
echo ""

echo "크기별 객체 분류:"
echo ""

# 다양한 크기의 파일 생성
generate_large_file "metadata-test/tiny.dat" 1
generate_large_file "metadata-test/small.dat" 5
generate_large_file "metadata-test/medium.dat" 20

# 업로드
mc cp metadata-test/tiny.dat local/$TEST_BUCKET/size-test/
mc cp metadata-test/small.dat local/$TEST_BUCKET/size-test/
mc cp metadata-test/medium.dat local/$TEST_BUCKET/size-test/

echo "크기별 객체 정보:"
for file in tiny.dat small.dat medium.dat; do
    echo ""
    echo "파일: $file"
    mc stat local/$TEST_BUCKET/size-test/$file | grep "Size"
done

wait_for_user "고급 검색 및 필터링을 학습했습니다. 성능 최적화 기법을 실습해보겠습니다."

# Step 5: 성능 최적화 기법
print_step "5" "성능 최적화 기법"
echo ""
print_concept "S3 API 사용 시 성능을 최적화하는 다양한 기법들을 학습합니다"
echo ""

echo -e "${CYAN}⚡ 성능 최적화 전략:${NC}"
echo "• 병렬 업로드/다운로드"
echo "• 적절한 파트 크기 설정"
echo "• 연결 풀링 및 재사용"
echo "• 압축 활용"
echo "• 캐싱 전략"
echo "• 네트워크 최적화"
echo ""

echo "1. 병렬 처리 성능 테스트:"
echo ""

# 여러 파일 생성
echo "병렬 테스트용 파일들 생성:"
mkdir -p performance-test

for i in {1..5}; do
    generate_large_file "performance-test/file-${i}.dat" 10
done

echo ""
echo "순차 업로드 테스트:"
start_time=$(date +%s)

for i in {1..5}; do
    echo "업로드 중: file-${i}.dat"
    mc cp performance-test/file-${i}.dat local/$TEST_BUCKET/sequential/
done

end_time=$(date +%s)
sequential_time=$((end_time - start_time))
print_success "순차 업로드 완료 (소요시간: ${sequential_time}초)"

echo ""
echo "병렬 업로드 테스트:"
start_time=$(date +%s)

# 백그라운드로 병렬 업로드
for i in {1..5}; do
    echo "병렬 업로드 시작: file-${i}.dat"
    mc cp performance-test/file-${i}.dat local/$TEST_BUCKET/parallel/ &
done

# 모든 백그라운드 작업 완료 대기
wait

end_time=$(date +%s)
parallel_time=$((end_time - start_time))
print_success "병렬 업로드 완료 (소요시간: ${parallel_time}초)"

echo ""
echo -e "${BLUE}📊 성능 비교 결과:${NC}"
echo "• 순차 업로드: ${sequential_time}초"
echo "• 병렬 업로드: ${parallel_time}초"

if [ $parallel_time -lt $sequential_time ]; then
    improvement=$((sequential_time - parallel_time))
    echo "• 성능 향상: ${improvement}초 단축"
    echo "• 개선율: $(((sequential_time - parallel_time) * 100 / sequential_time))%"
else
    echo "• 이 환경에서는 병렬 처리 효과가 제한적입니다"
fi

echo ""
echo "2. 압축 활용 테스트:"
echo ""

print_concept "압축을 통해 네트워크 전송량을 줄일 수 있습니다"
echo ""

# 압축 가능한 텍스트 파일 생성
echo "압축 테스트용 텍스트 파일 생성:"
cat > performance-test/large-text.txt << EOF
$(for i in {1..10000}; do echo "This is line $i of the large text file for compression testing."; done)
EOF

ORIGINAL_SIZE=$(stat -c%s performance-test/large-text.txt 2>/dev/null || stat -f%z performance-test/large-text.txt)
echo "원본 파일 크기: $(format_bytes $ORIGINAL_SIZE)"

# 압축 파일 생성
echo "파일 압축 중..."
gzip -c performance-test/large-text.txt > performance-test/large-text.txt.gz

COMPRESSED_SIZE=$(stat -c%s performance-test/large-text.txt.gz 2>/dev/null || stat -f%z performance-test/large-text.txt.gz)
echo "압축 파일 크기: $(format_bytes $COMPRESSED_SIZE)"

COMPRESSION_RATIO=$(((ORIGINAL_SIZE - COMPRESSED_SIZE) * 100 / ORIGINAL_SIZE))
echo "압축률: ${COMPRESSION_RATIO}%"

echo ""
echo "압축 파일 업로드 테스트:"
start_time=$(date +%s)
mc cp performance-test/large-text.txt.gz local/$TEST_BUCKET/compression-test/
end_time=$(date +%s)
compressed_upload_time=$((end_time - start_time))

echo ""
echo "원본 파일 업로드 테스트:"
start_time=$(date +%s)
mc cp performance-test/large-text.txt local/$TEST_BUCKET/compression-test/
end_time=$(date +%s)
original_upload_time=$((end_time - start_time))

echo ""
echo -e "${BLUE}📊 압축 효과 분석:${NC}"
echo "• 원본 업로드 시간: ${original_upload_time}초"
echo "• 압축 업로드 시간: ${compressed_upload_time}초"
echo "• 네트워크 전송량 절약: ${COMPRESSION_RATIO}%"

wait_for_user "성능 최적화 기법을 학습했습니다. 실습 결과를 정리해보겠습니다."

# Step 6: 실습 결과 정리 및 요약
print_step "6" "실습 결과 정리 및 요약"
echo ""
echo -e "${BLUE}🎉 Lab 4 완료 - 학습 성과 정리${NC}"
echo ""

echo -e "${CYAN}✅ 완료된 학습 내용:${NC}"
echo "1. ✓ Multipart Upload vs Single Part Upload 비교"
echo "2. ✓ 대용량 파일 처리 최적화"
echo "3. ✓ 객체 메타데이터 설정 및 활용"
echo "4. ✓ Content-Type 및 사용자 정의 메타데이터"
echo "5. ✓ 고급 검색 및 필터링 기법"
echo "6. ✓ 성능 최적화 전략"
echo "7. ✓ 병렬 처리 및 압축 활용"
echo ""

echo -e "${PURPLE}📊 실습 통계:${NC}"
TOTAL_OBJECTS=$(mc ls --recursive local/$TEST_BUCKET | wc -l)
BUCKET_SIZE=$(mc du local/$TEST_BUCKET | awk '{print $1}' | head -1)

echo "• 생성된 객체 수: $TOTAL_OBJECTS"
echo "• 총 데이터 크기: $(format_bytes ${BUCKET_SIZE:-0})"
echo "• 테스트한 파일 형식: 텍스트, 바이너리, JSON, HTML, CSS"
echo "• 성능 테스트: 순차 vs 병렬, 압축 효과"
echo "• 실습 소요 시간: 약 20-25분"
echo ""

echo -e "${YELLOW}🔧 습득한 고급 기술:${NC}"
echo "• Multipart Upload 메커니즘 이해"
echo "• 메타데이터 기반 객체 관리"
echo "• 고급 검색 및 필터링 기법"
echo "• 성능 최적화 전략"
echo "• 병렬 처리 및 압축 활용"
echo "• 대용량 파일 처리 최적화"
echo ""

echo -e "${GREEN}🚀 다음 단계 추천:${NC}"
echo "• Lab 5: 성능 테스트 (처리량, 동시 연결 측정)"
echo "• Lab 6: 사용자 및 권한 관리 (IAM, 정책 기반 제어)"
echo "• Lab 7: 모니터링 설정 (Prometheus, Grafana)"
echo ""

echo -e "${BLUE}📚 추가 학습 리소스:${NC}"
echo "• S3 Multipart Upload 가이드: https://docs.aws.amazon.com/s3/latest/userguide/mpuoverview.html"
echo "• MinIO 성능 튜닝: https://docs.min.io/docs/minio-server-configuration-guide.html"
echo "• Lab 4 개념 가이드: docs/LAB-04-CONCEPTS.md"
echo ""

# 정리 옵션 제공
echo -e "${YELLOW}🧹 정리 옵션:${NC}"
echo "실습에서 생성한 테스트 데이터를 정리하시겠습니까?"
echo "1) 로컬 테스트 파일만 정리 (MinIO 객체는 유지)"
echo "2) 모든 테스트 데이터 정리 (버킷과 객체 삭제)"
echo "3) 정리하지 않음 (다음 Lab에서 계속 사용)"
echo ""

read -p "선택하세요 (1-3): " cleanup_choice

case $cleanup_choice in
    1)
        echo ""
        echo "로컬 테스트 파일 정리 중..."
        cd ..
        rm -rf lab4-advanced-test
        print_success "로컬 테스트 파일 정리 완료"
        echo "MinIO의 버킷과 객체는 유지됩니다."
        ;;
    2)
        echo ""
        echo "모든 테스트 데이터 정리 중..."
        
        # 버킷 내 모든 객체 삭제
        echo "객체 삭제 중..."
        mc rm --recursive --force local/$TEST_BUCKET/ 2>/dev/null || true
        
        # 버킷 삭제
        echo "버킷 삭제 중..."
        mc rb local/$TEST_BUCKET --force 2>/dev/null || true
        
        # 로컬 파일 정리
        cd ..
        rm -rf lab4-advanced-test
        
        print_success "모든 테스트 데이터 정리 완료"
        ;;
    3)
        echo ""
        print_info "테스트 데이터를 유지합니다"
        echo "다음 Lab에서 이 데이터를 계속 사용할 수 있습니다."
        cd ..
        ;;
    *)
        echo ""
        print_warning "잘못된 선택입니다. 정리하지 않습니다."
        cd ..
        ;;
esac

echo ""
echo -e "${GREEN}🎯 Lab 4 완료!${NC}"
echo ""
echo -e "${BLUE}💡 핵심 포인트 요약:${NC}"
echo "• Multipart Upload는 대용량 파일 처리의 핵심 기술입니다"
echo "• 메타데이터를 활용하면 객체 관리가 훨씬 효율적입니다"
echo "• 병렬 처리와 압축은 성능 향상의 핵심 요소입니다"
echo "• 적절한 검색 및 필터링으로 대량의 객체를 효율적으로 관리할 수 있습니다"
echo ""

echo -e "${PURPLE}🎓 다음 Lab 준비:${NC}"
echo "Lab 5에서는 MinIO의 성능을 체계적으로 측정하고 분석합니다:"
echo "• 다양한 파일 크기별 성능 특성 분석"
echo "• 동시 연결 처리 능력 측정"
echo "• 병목 지점 식별 및 최적화"
echo "• 실제 운영 환경 성능 예측"
echo ""

echo "Lab 4 실습을 완료했습니다! 🎉"
echo "계속해서 Lab 5를 진행하거나 ./run-lab.sh를 실행하여 메뉴로 돌아가세요."
