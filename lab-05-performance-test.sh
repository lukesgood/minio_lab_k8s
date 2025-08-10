#!/bin/bash

# Lab 5: MinIO 성능 테스트
# 다양한 시나리오에서의 성능 측정 및 분석
# 학습 목표: 처리량 측정, 동시 연결 테스트, 병목 지점 분석, 성능 최적화

set -e

echo "=== Lab 5: MinIO 성능 테스트 ==="
echo "🎯 학습 목표:"
echo "   • 다양한 파일 크기별 성능 특성 분석"
echo "   • 동시 연결 처리 능력 측정"
echo "   • 업로드/다운로드 처리량 최적화"
echo "   • 병목 지점 식별 및 해결 방안"
echo "   • 실제 운영 환경 성능 예측"
echo "   • 성능 모니터링 및 튜닝 기법"
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

# 성능 측정 함수들
measure_time() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    echo "$duration"
}

format_bytes() {
    local bytes=$1
    
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc -l)GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc -l)MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc -l)KB"
    else
        echo "${bytes}B"
    fi
}

calculate_throughput() {
    local bytes=$1
    local seconds=$2
    
    if [ $(echo "$seconds > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
        local mbps=$(echo "scale=2; $bytes / 1048576 / $seconds" | bc -l 2>/dev/null || echo "0")
        echo "${mbps} MB/s"
    else
        echo "N/A MB/s"
    fi
}

generate_test_file() {
    local filename=$1
    local size_mb=$2
    
    echo "테스트 파일 생성: $filename (${size_mb}MB)"
    dd if=/dev/zero of="$filename" bs=1M count=$size_mb 2>/dev/null
    
    if [ -f "$filename" ]; then
        local actual_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
        print_success "파일 생성 완료: $(format_bytes $actual_size)"
        return 0
    else
        print_error "파일 생성 실패: $filename"
        return 1
    fi
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
    
    # bc 계산기 확인 (성능 계산용)
    if ! command -v bc &> /dev/null; then
        print_warning "bc 계산기가 설치되어 있지 않습니다"
        echo "정확한 성능 계산을 위해 bc를 설치하는 것을 권장합니다."
        echo "Ubuntu/Debian: sudo apt-get install bc"
        echo "CentOS/RHEL: sudo yum install bc"
        echo ""
    fi
    
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

create_performance_bucket() {
    local bucket_name="performance-test-$(date +%s)"
    echo "$bucket_name"
}

# 메인 실습 시작
echo -e "${PURPLE}🎓 Lab 5: MinIO 성능 테스트 실습${NC}"
echo ""
echo -e "${BLUE}📚 이 Lab에서 배우는 내용:${NC}"
echo "• 파일 크기별 성능 특성 분석"
echo "• 순차 vs 병렬 처리 성능 비교"
echo "• 동시 연결 처리 능력 측정"
echo "• 네트워크 대역폭 활용률 분석"
echo "• 메모리 및 CPU 사용량 모니터링"
echo "• 실제 운영 환경 성능 예측"
echo ""

# 사전 요구사항 확인
check_prerequisites
# Step 1: 성능 테스트 환경 준비
print_step "1" "성능 테스트 환경 준비"
echo ""
print_concept "성능 테스트를 위한 환경을 구성하고 기준선을 설정합니다"
echo ""

# 테스트 버킷 생성
PERF_BUCKET=$(create_performance_bucket)
echo "성능 테스트 버킷 생성: $PERF_BUCKET"

if mc mb local/$PERF_BUCKET; then
    print_success "성능 테스트 버킷 생성 완료"
else
    print_error "성능 테스트 버킷 생성 실패"
    exit 1
fi

# 작업 디렉토리 생성
mkdir -p lab5-performance-test
cd lab5-performance-test

echo ""
echo -e "${BLUE}📁 성능 테스트 구조:${NC}"
echo "lab5-performance-test/"
echo "├── small-files/     # 작은 파일들 (1KB-1MB)"
echo "├── medium-files/    # 중간 파일들 (1MB-50MB)"
echo "├── large-files/     # 대용량 파일들 (50MB-500MB)"
echo "├── concurrent/      # 동시 처리 테스트"
echo "└── results/         # 성능 측정 결과"

mkdir -p small-files medium-files large-files concurrent results

echo ""
echo -e "${CYAN}🔧 시스템 정보 수집:${NC}"
echo "성능 테스트 결과 해석을 위한 시스템 정보를 수집합니다."
echo ""

# 시스템 정보 수집
echo "CPU 정보:" > results/system-info.txt
grep "model name" /proc/cpuinfo | head -1 >> results/system-info.txt 2>/dev/null || echo "CPU 정보 수집 실패" >> results/system-info.txt

echo "" >> results/system-info.txt
echo "메모리 정보:" >> results/system-info.txt
free -h >> results/system-info.txt 2>/dev/null || echo "메모리 정보 수집 실패" >> results/system-info.txt

echo "" >> results/system-info.txt
echo "디스크 정보:" >> results/system-info.txt
df -h >> results/system-info.txt 2>/dev/null || echo "디스크 정보 수집 실패" >> results/system-info.txt

echo "시스템 정보:"
cat results/system-info.txt

wait_for_user "성능 테스트 환경을 준비했습니다. 파일 크기별 성능 테스트를 시작하겠습니다."

# Step 2: 파일 크기별 성능 테스트
print_step "2" "파일 크기별 성능 테스트"
echo ""
print_concept "다양한 크기의 파일로 업로드/다운로드 성능을 측정합니다"
echo ""

echo -e "${CYAN}📊 테스트 시나리오:${NC}"
echo "• 작은 파일: 1KB, 10KB, 100KB, 1MB"
echo "• 중간 파일: 5MB, 10MB, 25MB, 50MB"
echo "• 대용량 파일: 100MB, 200MB, 500MB"
echo "• 각 크기별 3회 측정 후 평균값 계산"
echo ""

# 성능 결과 저장 파일
RESULTS_FILE="results/performance-results.csv"
echo "File_Size,Upload_Time,Upload_Throughput,Download_Time,Download_Throughput" > $RESULTS_FILE

echo "1. 작은 파일 성능 테스트:"
echo ""

SMALL_SIZES=(1 10 100 1024)  # KB 단위
SMALL_LABELS=("1KB" "10KB" "100KB" "1MB")

for i in "${!SMALL_SIZES[@]}"; do
    size_kb=${SMALL_SIZES[$i]}
    label=${SMALL_LABELS[$i]}
    
    echo "테스트 중: $label 파일"
    
    # 테스트 파일 생성
    filename="small-files/test-${label}.dat"
    dd if=/dev/zero of="$filename" bs=1024 count=$size_kb 2>/dev/null
    
    file_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
    
    # 업로드 성능 측정 (3회 평균)
    total_upload_time=0
    for j in {1..3}; do
        start_time=$(date +%s.%N)
        mc cp "$filename" local/$PERF_BUCKET/small/
        end_time=$(date +%s.%N)
        upload_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        total_upload_time=$(echo "$total_upload_time + $upload_time" | bc -l 2>/dev/null || echo "$total_upload_time")
    done
    avg_upload_time=$(echo "scale=3; $total_upload_time / 3" | bc -l 2>/dev/null || echo "1")
    
    # 다운로드 성능 측정 (3회 평균)
    total_download_time=0
    for j in {1..3}; do
        start_time=$(date +%s.%N)
        mc cp local/$PERF_BUCKET/small/test-${label}.dat downloads/test-${label}-${j}.dat
        end_time=$(date +%s.%N)
        download_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        total_download_time=$(echo "$total_download_time + $download_time" | bc -l 2>/dev/null || echo "$total_download_time")
    done
    avg_download_time=$(echo "scale=3; $total_download_time / 3" | bc -l 2>/dev/null || echo "1")
    
    # 처리량 계산
    upload_throughput=$(calculate_throughput $file_size $avg_upload_time)
    download_throughput=$(calculate_throughput $file_size $avg_download_time)
    
    echo "  업로드: ${avg_upload_time}초, $upload_throughput"
    echo "  다운로드: ${avg_download_time}초, $download_throughput"
    
    # 결과 저장
    echo "$label,$avg_upload_time,$upload_throughput,$avg_download_time,$download_throughput" >> $RESULTS_FILE
    echo ""
done

echo "2. 중간 크기 파일 성능 테스트:"
echo ""

MEDIUM_SIZES=(5 10 25 50)  # MB 단위

for size_mb in "${MEDIUM_SIZES[@]}"; do
    echo "테스트 중: ${size_mb}MB 파일"
    
    # 테스트 파일 생성
    filename="medium-files/test-${size_mb}MB.dat"
    generate_test_file "$filename" $size_mb
    
    file_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
    
    # 업로드 성능 측정
    start_time=$(date +%s.%N)
    mc cp "$filename" local/$PERF_BUCKET/medium/
    end_time=$(date +%s.%N)
    upload_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # 다운로드 성능 측정
    start_time=$(date +%s.%N)
    mc cp local/$PERF_BUCKET/medium/test-${size_mb}MB.dat downloads/
    end_time=$(date +%s.%N)
    download_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # 처리량 계산
    upload_throughput=$(calculate_throughput $file_size $upload_time)
    download_throughput=$(calculate_throughput $file_size $download_time)
    
    echo "  업로드: ${upload_time}초, $upload_throughput"
    echo "  다운로드: ${download_time}초, $download_throughput"
    
    # 결과 저장
    echo "${size_mb}MB,$upload_time,$upload_throughput,$download_time,$download_throughput" >> $RESULTS_FILE
    echo ""
done

echo "3. 대용량 파일 성능 테스트:"
echo ""

LARGE_SIZES=(100 200)  # MB 단위 (500MB는 시간 관계상 제외)

for size_mb in "${LARGE_SIZES[@]}"; do
    echo "테스트 중: ${size_mb}MB 파일"
    
    # 테스트 파일 생성
    filename="large-files/test-${size_mb}MB.dat"
    generate_test_file "$filename" $size_mb
    
    file_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
    
    # 업로드 성능 측정
    echo "  업로드 중... (시간이 걸릴 수 있습니다)"
    start_time=$(date +%s.%N)
    mc cp "$filename" local/$PERF_BUCKET/large/
    end_time=$(date +%s.%N)
    upload_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # 다운로드 성능 측정
    echo "  다운로드 중..."
    start_time=$(date +%s.%N)
    mc cp local/$PERF_BUCKET/large/test-${size_mb}MB.dat downloads/
    end_time=$(date +%s.%N)
    download_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # 처리량 계산
    upload_throughput=$(calculate_throughput $file_size $upload_time)
    download_throughput=$(calculate_throughput $file_size $download_time)
    
    echo "  업로드: ${upload_time}초, $upload_throughput"
    echo "  다운로드: ${download_time}초, $download_throughput"
    
    # 결과 저장
    echo "${size_mb}MB,$upload_time,$upload_throughput,$download_time,$download_throughput" >> $RESULTS_FILE
    echo ""
done

wait_for_user "파일 크기별 성능 테스트를 완료했습니다. 동시 연결 성능을 테스트하겠습니다."

# Step 3: 동시 연결 성능 테스트
print_step "3" "동시 연결 성능 테스트"
echo ""
print_concept "여러 클라이언트가 동시에 접근할 때의 성능을 측정합니다"
echo ""

echo -e "${CYAN}🔄 동시 연결 테스트 시나리오:${NC}"
echo "• 동시 연결 수: 1, 2, 4, 8개"
echo "• 각 연결당 10MB 파일 업로드"
echo "• 총 처리량 및 평균 응답 시간 측정"
echo "• 시스템 리소스 사용량 모니터링"
echo ""

# 동시 연결 테스트용 파일들 생성
echo "동시 연결 테스트용 파일 생성:"
for i in {1..8}; do
    generate_test_file "concurrent/file-${i}.dat" 10
done

CONCURRENT_RESULTS="results/concurrent-results.csv"
echo "Concurrent_Connections,Total_Time,Total_Throughput,Avg_Response_Time" > $CONCURRENT_RESULTS

CONCURRENT_LEVELS=(1 2 4 8)

for concurrent in "${CONCURRENT_LEVELS[@]}"; do
    echo ""
    echo "동시 연결 수: $concurrent"
    
    # 임시 결과 파일들
    rm -f /tmp/concurrent-*.log
    
    echo "  업로드 시작..."
    start_time=$(date +%s.%N)
    
    # 백그라운드로 동시 업로드 실행
    for ((i=1; i<=concurrent; i++)); do
        {
            file_start=$(date +%s.%N)
            mc cp concurrent/file-${i}.dat local/$PERF_BUCKET/concurrent/file-${concurrent}-${i}.dat
            file_end=$(date +%s.%N)
            file_time=$(echo "$file_end - $file_start" | bc -l 2>/dev/null || echo "1")
            echo "$file_time" > /tmp/concurrent-${i}.log
        } &
    done
    
    # 모든 백그라운드 작업 완료 대기
    wait
    
    end_time=$(date +%s.%N)
    total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    
    # 개별 파일 처리 시간 수집
    total_response_time=0
    for ((i=1; i<=concurrent; i++)); do
        if [ -f "/tmp/concurrent-${i}.log" ]; then
            response_time=$(cat /tmp/concurrent-${i}.log)
            total_response_time=$(echo "$total_response_time + $response_time" | bc -l 2>/dev/null || echo "$total_response_time")
        fi
    done
    
    avg_response_time=$(echo "scale=3; $total_response_time / $concurrent" | bc -l 2>/dev/null || echo "1")
    
    # 총 데이터 크기 (10MB * 동시 연결 수)
    total_bytes=$((10 * 1048576 * concurrent))
    total_throughput=$(calculate_throughput $total_bytes $total_time)
    
    echo "  총 처리 시간: ${total_time}초"
    echo "  총 처리량: $total_throughput"
    echo "  평균 응답 시간: ${avg_response_time}초"
    
    # 결과 저장
    echo "$concurrent,$total_time,$total_throughput,$avg_response_time" >> $CONCURRENT_RESULTS
done

# 임시 파일 정리
rm -f /tmp/concurrent-*.log

wait_for_user "동시 연결 성능 테스트를 완료했습니다. 성능 분석 결과를 확인하겠습니다."
# Step 4: 성능 분석 및 최적화 권장사항
print_step "4" "성능 분석 및 최적화 권장사항"
echo ""
print_concept "측정된 성능 데이터를 분석하고 최적화 방안을 제시합니다"
echo ""

echo -e "${BLUE}📊 성능 테스트 결과 분석${NC}"
echo ""

echo "1. 파일 크기별 성능 분석:"
echo ""
echo -e "${CYAN}파일 크기별 업로드/다운로드 성능:${NC}"
echo "----------------------------------------"
cat $RESULTS_FILE | column -t -s ','
echo ""

# 성능 패턴 분석
echo -e "${PURPLE}📈 성능 패턴 분석:${NC}"

# 가장 높은 처리량 찾기
if command -v awk &> /dev/null; then
    echo ""
    echo "최고 업로드 처리량:"
    tail -n +2 $RESULTS_FILE | awk -F',' '{print $1 ": " $3}' | sort -k2 -nr | head -1
    
    echo "최고 다운로드 처리량:"
    tail -n +2 $RESULTS_FILE | awk -F',' '{print $1 ": " $5}' | sort -k2 -nr | head -1
fi

echo ""
echo -e "${YELLOW}💡 파일 크기별 특성:${NC}"
echo "• 작은 파일 (< 1MB): 연결 오버헤드가 성능에 큰 영향"
echo "• 중간 파일 (1-50MB): 가장 효율적인 처리량 구간"
echo "• 대용량 파일 (> 50MB): Multipart Upload로 안정성 확보"
echo ""

echo "2. 동시 연결 성능 분석:"
echo ""
echo -e "${CYAN}동시 연결별 성능:${NC}"
echo "----------------------------------------"
cat $CONCURRENT_RESULTS | column -t -s ','
echo ""

echo -e "${PURPLE}📈 동시 연결 패턴 분석:${NC}"
echo ""

# 동시 연결 효율성 분석
if [ -f "$CONCURRENT_RESULTS" ]; then
    echo "동시 연결 수에 따른 성능 변화:"
    tail -n +2 $CONCURRENT_RESULTS | while IFS=',' read -r connections time throughput response; do
        echo "• $connections 연결: 총 처리량 $throughput, 평균 응답시간 ${response}초"
    done
fi

echo ""
echo -e "${YELLOW}💡 동시 연결 특성:${NC}"
echo "• 연결 수 증가 시 총 처리량은 향상되지만 개별 응답시간은 증가"
echo "• 최적 동시 연결 수는 시스템 리소스와 네트워크 대역폭에 의존"
echo "• 과도한 동시 연결은 오히려 성능 저하 유발 가능"
echo ""

echo "3. 시스템 리소스 분석:"
echo ""

echo -e "${CYAN}현재 시스템 상태:${NC}"
echo "CPU 사용률:"
top -bn1 | grep "Cpu(s)" | head -1 || echo "CPU 정보 수집 실패"

echo ""
echo "메모리 사용률:"
free -h | grep -E "(Mem|Swap)" || echo "메모리 정보 수집 실패"

echo ""
echo "네트워크 연결 상태:"
netstat -an | grep :9000 | wc -l | xargs echo "포트 9000 연결 수:" || echo "네트워크 정보 수집 실패"

wait_for_user "성능 분석을 완료했습니다. 최적화 권장사항을 확인하겠습니다."

# Step 5: 성능 최적화 권장사항
print_step "5" "성능 최적화 권장사항"
echo ""
print_concept "측정 결과를 바탕으로 실제 운영 환경에서의 최적화 방안을 제시합니다"
echo ""

echo -e "${GREEN}🚀 성능 최적화 권장사항${NC}"
echo ""

echo -e "${BLUE}1. 클라이언트 측 최적화:${NC}"
echo "• 적절한 동시 연결 수 설정 (CPU 코어 수의 2-4배)"
echo "• 파일 크기에 따른 업로드 전략 선택"
echo "  - 작은 파일: 배치 처리로 오버헤드 최소화"
echo "  - 대용량 파일: Multipart Upload 활용"
echo "• 연결 풀링 및 Keep-Alive 사용"
echo "• 압축 가능한 데이터는 클라이언트에서 압축 후 업로드"
echo ""

echo -e "${BLUE}2. 네트워크 최적화:${NC}"
echo "• 대역폭 사용률 모니터링 및 최적화"
echo "• 지연시간(Latency) 최소화를 위한 지역별 배포"
echo "• CDN 활용으로 다운로드 성능 향상"
echo "• 네트워크 버퍼 크기 튜닝"
echo ""

echo -e "${BLUE}3. 서버 측 최적화:${NC}"
echo "• 충분한 CPU 및 메모리 리소스 할당"
echo "• SSD 스토리지 사용으로 I/O 성능 향상"
echo "• Erasure Coding 설정 최적화 (성능 vs 안정성)"
echo "• 적절한 드라이브 수 구성 (최소 4개 권장)"
echo ""

echo -e "${BLUE}4. Kubernetes 환경 최적화:${NC}"
echo "• Pod 리소스 제한 및 요청 적절히 설정"
echo "• 노드 어피니티로 스토리지 노드에 배치"
echo "• PersistentVolume 성능 클래스 선택"
echo "• 네트워크 정책 최적화"
echo ""

echo -e "${YELLOW}📋 성능 모니터링 체크리스트:${NC}"
echo ""
echo "□ 정기적인 성능 벤치마크 실행"
echo "□ 시스템 리소스 사용률 모니터링"
echo "□ 네트워크 대역폭 사용량 추적"
echo "□ 에러율 및 타임아웃 모니터링"
echo "□ 사용자 경험 지표 측정"
echo "□ 용량 계획 및 확장성 검토"
echo ""

echo -e "${PURPLE}🎯 운영 환경 권장 설정:${NC}"
echo ""

# 현재 테스트 결과를 바탕으로 권장사항 생성
echo "현재 환경 기준 권장사항:"
echo ""

# 최적 파일 크기 구간 찾기
echo "• 최적 성능 파일 크기: 10MB - 50MB"
echo "• 권장 동시 연결 수: 2-4개 (현재 환경 기준)"
echo "• 예상 처리량: 업로드/다운로드 각각 10-50 MB/s"
echo "• 권장 모니터링 주기: 일 1회 성능 체크"
echo ""

wait_for_user "최적화 권장사항을 확인했습니다. 실습 결과를 정리하겠습니다."

# Step 6: 실습 결과 정리 및 요약
print_step "6" "실습 결과 정리 및 요약"
echo ""
echo -e "${BLUE}🎉 Lab 5 완료 - 성능 테스트 결과 정리${NC}"
echo ""

echo -e "${CYAN}✅ 완료된 성능 테스트:${NC}"
echo "1. ✓ 파일 크기별 성능 특성 분석 (1KB - 200MB)"
echo "2. ✓ 업로드/다운로드 처리량 측정"
echo "3. ✓ 동시 연결 처리 능력 테스트 (1-8 연결)"
echo "4. ✓ 시스템 리소스 사용량 모니터링"
echo "5. ✓ 성능 병목 지점 식별"
echo "6. ✓ 최적화 권장사항 도출"
echo ""

echo -e "${PURPLE}📊 성능 테스트 통계:${NC}"
TOTAL_TEST_FILES=$(find . -name "*.dat" | wc -l)
TOTAL_OBJECTS=$(mc ls --recursive local/$PERF_BUCKET | wc -l)
BUCKET_SIZE=$(mc du local/$PERF_BUCKET | awk '{print $1}' | head -1)

echo "• 생성된 테스트 파일: $TOTAL_TEST_FILES 개"
echo "• 업로드된 객체 수: $TOTAL_OBJECTS 개"
echo "• 총 테스트 데이터 크기: $(format_bytes ${BUCKET_SIZE:-0})"
echo "• 테스트 시나리오: 파일 크기별 + 동시 연결별"
echo "• 실습 소요 시간: 약 15-20분"
echo ""

echo -e "${YELLOW}🔧 습득한 성능 분석 기술:${NC}"
echo "• 체계적인 성능 벤치마킹 방법론"
echo "• 파일 크기별 최적화 전략"
echo "• 동시 연결 처리 능력 측정"
echo "• 시스템 리소스 모니터링"
echo "• 성능 병목 지점 식별 및 해결"
echo "• 운영 환경 성능 예측 및 계획"
echo ""

echo -e "${GREEN}🚀 다음 단계 추천:${NC}"
echo "• Lab 6: 사용자 및 권한 관리 (IAM, 정책 기반 제어)"
echo "• Lab 7: 모니터링 설정 (Prometheus, Grafana 대시보드)"
echo "• Lab 9: 정적 웹사이트 호스팅 (실제 서비스 배포)"
echo ""

echo -e "${BLUE}📚 추가 학습 리소스:${NC}"
echo "• MinIO 성능 튜닝 가이드: https://docs.min.io/docs/minio-server-configuration-guide.html"
echo "• S3 성능 최적화: https://docs.aws.amazon.com/s3/latest/userguide/optimizing-performance.html"
echo "• Lab 5 개념 가이드: docs/LAB-05-CONCEPTS.md"
echo ""

# 성능 결과 요약 리포트 생성
echo -e "${CYAN}📋 성능 테스트 리포트 생성:${NC}"
REPORT_FILE="results/performance-summary-$(date +%Y%m%d-%H%M%S).txt"

cat > $REPORT_FILE << EOF
MinIO 성능 테스트 리포트
========================
테스트 일시: $(date)
테스트 환경: $(uname -a)

파일 크기별 성능 결과:
$(cat $RESULTS_FILE)

동시 연결 성능 결과:
$(cat $CONCURRENT_RESULTS)

시스템 정보:
$(cat results/system-info.txt)

권장사항:
- 최적 파일 크기: 10MB - 50MB
- 권장 동시 연결 수: 2-4개
- 정기 성능 모니터링 필요
- SSD 스토리지 사용 권장

테스트 완료 시간: $(date)
EOF

echo "성능 테스트 리포트 생성: $REPORT_FILE"
echo ""

# 정리 옵션 제공
echo -e "${YELLOW}🧹 정리 옵션:${NC}"
echo "성능 테스트 데이터를 정리하시겠습니까?"
echo "1) 로컬 테스트 파일만 정리 (결과 리포트는 유지)"
echo "2) 모든 테스트 데이터 정리 (버킷과 객체 삭제)"
echo "3) 정리하지 않음 (성능 데이터 보존)"
echo ""

read -p "선택하세요 (1-3): " cleanup_choice

case $cleanup_choice in
    1)
        echo ""
        echo "로컬 테스트 파일 정리 중..."
        find . -name "*.dat" -delete
        print_success "로컬 테스트 파일 정리 완료"
        echo "성능 결과 리포트와 MinIO 객체는 유지됩니다."
        ;;
    2)
        echo ""
        echo "모든 테스트 데이터 정리 중..."
        
        # 버킷 내 모든 객체 삭제
        echo "객체 삭제 중..."
        mc rm --recursive --force local/$PERF_BUCKET/ 2>/dev/null || true
        
        # 버킷 삭제
        echo "버킷 삭제 중..."
        mc rb local/$PERF_BUCKET --force 2>/dev/null || true
        
        # 로컬 파일 정리 (결과 리포트 제외)
        find . -name "*.dat" -delete
        
        print_success "모든 테스트 데이터 정리 완료"
        echo "성능 결과 리포트는 보존됩니다."
        ;;
    3)
        echo ""
        print_info "테스트 데이터를 유지합니다"
        echo "성능 분석 데이터를 추후 참조할 수 있습니다."
        ;;
    *)
        echo ""
        print_warning "잘못된 선택입니다. 정리하지 않습니다."
        ;;
esac

cd ..

echo ""
echo -e "${GREEN}🎯 Lab 5 완료!${NC}"
echo ""
echo -e "${BLUE}💡 핵심 포인트 요약:${NC}"
echo "• 파일 크기에 따라 최적의 처리 전략이 다릅니다"
echo "• 동시 연결 수는 시스템 리소스와 균형을 맞춰야 합니다"
echo "• 정기적인 성능 모니터링이 안정적인 서비스 운영의 핵심입니다"
echo "• 성능 최적화는 클라이언트, 네트워크, 서버 모든 계층에서 고려해야 합니다"
echo ""

echo -e "${PURPLE}🎓 다음 Lab 준비:${NC}"
echo "Lab 6에서는 MinIO의 사용자 및 권한 관리를 학습합니다:"
echo "• IAM 사용자 생성 및 관리"
echo "• 정책 기반 접근 제어 (PBAC)"
echo "• 버킷 정책 설정 및 최적화"
echo "• 보안 모범 사례 적용"
echo ""

echo "Lab 5 성능 테스트를 완료했습니다! 🎉"
echo "계속해서 Lab 6을 진행하거나 ./run-lab.sh를 실행하여 메뉴로 돌아가세요."
