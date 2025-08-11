# Lab 5: 성능 테스트 - Lab Guide

## 📚 학습 목표

이 실습에서는 MinIO의 성능 특성을 체계적으로 측정하고 분석합니다:

- **처리량 측정**: 업로드/다운로드 속도 분석
- **동시 연결 테스트**: 병렬 처리 성능 확인
- **파일 크기별 성능**: 다양한 크기의 파일 처리 특성
- **병목 지점 분석**: 시스템 리소스 사용량 모니터링
- **성능 최적화**: 설정 튜닝을 통한 성능 개선

## 🎯 핵심 개념

### 성능 측정 지표

| 지표 | 설명 | 단위 |
|------|------|------|
| **Throughput** | 단위 시간당 처리량 | MB/s, GB/s |
| **IOPS** | 초당 입출력 작업 수 | ops/sec |
| **Latency** | 요청-응답 지연시간 | ms, seconds |
| **Concurrency** | 동시 처리 가능 연결 수 | connections |
| **CPU Usage** | CPU 사용률 | % |
| **Memory Usage** | 메모리 사용량 | MB, GB |

### 성능에 영향을 주는 요소
- **네트워크 대역폭**: 클러스터 내/외부 통신 속도
- **스토리지 I/O**: 디스크 읽기/쓰기 성능
- **CPU 성능**: 암호화, 압축 등 연산 처리
- **메모리**: 버퍼링 및 캐싱 효율성
- **동시 연결 수**: 병렬 처리 최적화

## 🚀 실습 시작

### 1단계: 성능 테스트 환경 준비

#### 시스템 리소스 확인

```bash
# 현재 시스템 리소스 상태 확인
echo "=== 시스템 리소스 현황 ==="
echo "CPU 정보:"
nproc
cat /proc/cpuinfo | grep "model name" | head -1

echo -e "\n메모리 정보:"
free -h

echo -e "\n디스크 정보:"
df -h

echo -e "\n네트워크 인터페이스:"
ip addr show | grep -E "inet.*scope global"
```

#### MinIO 클러스터 상태 확인

```bash
# MinIO 서비스 상태
kubectl get pods -n minio-tenant -o wide

# MinIO 리소스 사용량
kubectl top pods -n minio-tenant 2>/dev/null || echo "metrics-server가 설치되지 않음"

# 포트 포워딩 확인
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
sleep 2
```

#### 테스트 디렉토리 및 도구 준비

```bash
# 성능 테스트 디렉토리 생성
mkdir -p performance-test
cd performance-test

# 테스트 결과 저장 디렉토리
mkdir -p results logs

# 시간 측정 함수 정의
measure_time() {
    local command="$1"
    local description="$2"
    echo "시작: $description"
    start_time=$(date +%s.%N)
    eval "$command"
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    echo "완료: $description - 소요시간: ${duration}초"
    echo "$description,$duration" >> results/timing_results.csv
}
```

### 2단계: 기본 성능 측정

#### 다양한 크기의 테스트 파일 생성

```bash
echo "=== 테스트 파일 생성 ==="

# 작은 파일들 (1KB - 1MB)
dd if=/dev/zero of=file_1kb.dat bs=1K count=1 2>/dev/null
dd if=/dev/zero of=file_100kb.dat bs=100K count=1 2>/dev/null
dd if=/dev/zero of=file_1mb.dat bs=1M count=1 2>/dev/null

# 중간 파일들 (10MB - 100MB)
dd if=/dev/zero of=file_10mb.dat bs=1M count=10 2>/dev/null
dd if=/dev/zero of=file_50mb.dat bs=1M count=50 2>/dev/null
dd if=/dev/zero of=file_100mb.dat bs=1M count=100 2>/dev/null

# 큰 파일들 (500MB - 1GB)
dd if=/dev/zero of=file_500mb.dat bs=1M count=500 2>/dev/null
dd if=/dev/zero of=file_1gb.dat bs=1M count=1024 2>/dev/null

# 파일 크기 확인
echo -e "\n생성된 테스트 파일:"
ls -lh *.dat

# 📋 예상 결과:
# -rw-rw-r-- 1 user user 1.0K Aug 11 01:40 file_1kb.dat
# -rw-rw-r-- 1 user user 100K Aug 11 01:40 file_100kb.dat
# -rw-rw-r-- 1 user user 1.0M Aug 11 01:40 file_1mb.dat
# -rw-rw-r-- 1 user user  10M Aug 11 01:40 file_10mb.dat
# -rw-rw-r-- 1 user user  50M Aug 11 01:40 file_50mb.dat
# -rw-rw-r-- 1 user user 100M Aug 11 01:40 file_100mb.dat
# -rw-rw-r-- 1 user user 500M Aug 11 01:40 file_500mb.dat
# -rw-rw-r-- 1 user user 1.0G Aug 11 01:40 file_1gb.dat
# 
# 💡 설명:
# - dd 명령으로 다양한 크기의 테스트 파일 생성
# - /dev/zero를 사용하여 빠른 파일 생성
# - 파일 크기별 성능 특성 분석을 위한 준비
```

#### 단일 파일 업로드 성능 테스트

```bash
echo "=== 단일 파일 업로드 성능 테스트 ==="

# CSV 헤더 생성
echo "Test,Duration(seconds)" > results/timing_results.csv

# 각 파일 크기별 업로드 테스트
for file in file_*.dat; do
    size=$(echo $file | sed 's/file_//;s/.dat//')
    measure_time "mc cp $file local/test-bucket/perf_$file" "Upload_$size"
done

echo -e "\n업로드 성능 결과:"
cat results/timing_results.csv

# 📋 예상 결과:
# Test,Duration(seconds)
# Upload_1kb,0.156
# Upload_100kb,0.234
# Upload_1mb,0.445
# Upload_10mb,1.234
# Upload_50mb,4.567
# Upload_100mb,8.901
# Upload_500mb,35.678
# Upload_1gb,68.234
# 
# 💡 설명:
# - 파일 크기가 클수록 업로드 시간 증가
# - 100MB 이상에서 Multipart Upload 자동 활성화
# - 네트워크 대역폭과 디스크 I/O가 주요 병목
```

#### 단일 파일 다운로드 성능 테스트

```bash
echo "=== 단일 파일 다운로드 성능 테스트 ==="

# 다운로드 디렉토리 생성
mkdir -p downloads

# 각 파일 크기별 다운로드 테스트
for file in file_*.dat; do
    size=$(echo $file | sed 's/file_//;s/.dat//')
    measure_time "mc cp local/test-bucket/perf_$file downloads/downloaded_$file" "Download_$size"
done

echo -e "\n다운로드 성능 결과:"
tail -n +1 results/timing_results.csv | grep Download

# 📋 예상 결과:
# Download_1kb,0.089
# Download_100kb,0.123
# Download_1mb,0.234
# Download_10mb,0.789
# Download_50mb,2.345
# Download_100mb,4.567
# Download_500mb,18.901
# Download_1gb,35.678
# 
# 💡 설명:
# - 다운로드가 업로드보다 일반적으로 빠름
# - 캐싱 효과로 인한 성능 향상 가능
# - 네트워크 대역폭이 주요 제한 요소
```

### 3단계: 처리량 계산 및 분석

#### 처리량 계산 스크립트

```bash
# 처리량 계산 스크립트 생성
cat > calculate_throughput.py << 'EOF'
#!/usr/bin/env python3
import csv
import os

def get_file_size(filename):
    """파일 크기를 바이트 단위로 반환"""
    size_map = {
        '1kb': 1024,
        '100kb': 100 * 1024,
        '1mb': 1024 * 1024,
        '10mb': 10 * 1024 * 1024,
        '50mb': 50 * 1024 * 1024,
        '100mb': 100 * 1024 * 1024,
        '500mb': 500 * 1024 * 1024,
        '1gb': 1024 * 1024 * 1024
    }
    return size_map.get(filename.lower(), 0)

def calculate_throughput():
    """처리량 계산 및 결과 출력"""
    print("=== 처리량 분석 결과 ===")
    print(f"{'파일 크기':<10} {'업로드(MB/s)':<15} {'다운로드(MB/s)':<15}")
    print("-" * 45)
    
    upload_results = {}
    download_results = {}
    
    # CSV 파일 읽기
    with open('results/timing_results.csv', 'r') as f:
        reader = csv.reader(f)
        next(reader)  # 헤더 스킵
        
        for row in reader:
            test_name, duration = row[0], float(row[1])
            
            if test_name.startswith('Upload_'):
                size_name = test_name.replace('Upload_', '')
                upload_results[size_name] = duration
            elif test_name.startswith('Download_'):
                size_name = test_name.replace('Download_', '')
                download_results[size_name] = duration
    
    # 처리량 계산 및 출력
    for size_name in ['1kb', '100kb', '1mb', '10mb', '50mb', '100mb', '500mb', '1gb']:
        file_size_bytes = get_file_size(size_name)
        file_size_mb = file_size_bytes / (1024 * 1024)
        
        upload_throughput = file_size_mb / upload_results.get(size_name, 1) if size_name in upload_results else 0
        download_throughput = file_size_mb / download_results.get(size_name, 1) if size_name in download_results else 0
        
        print(f"{size_name:<10} {upload_throughput:<15.2f} {download_throughput:<15.2f}")

if __name__ == "__main__":
    calculate_throughput()
EOF

python3 calculate_throughput.py
```

### 4단계: 동시 연결 성능 테스트

#### 병렬 업로드 테스트

```bash
echo "=== 병렬 업로드 성능 테스트 ==="

# 병렬 테스트용 파일 생성
for i in {1..10}; do
    dd if=/dev/zero of=parallel_${i}.dat bs=1M count=10 2>/dev/null
done

# 순차 업로드 시간 측정
echo "순차 업로드 테스트..."
start_time=$(date +%s.%N)
for i in {1..10}; do
    mc cp parallel_${i}.dat local/test-bucket/sequential_${i}.dat >/dev/null 2>&1
done
end_time=$(date +%s.%N)
sequential_time=$(echo "$end_time - $start_time" | bc -l)
echo "순차 업로드 시간: ${sequential_time}초"

# 병렬 업로드 시간 측정
echo "병렬 업로드 테스트..."
start_time=$(date +%s.%N)
for i in {1..10}; do
    mc cp parallel_${i}.dat local/test-bucket/parallel_${i}.dat >/dev/null 2>&1 &
done
wait  # 모든 백그라운드 작업 완료 대기
end_time=$(date +%s.%N)
parallel_time=$(echo "$end_time - $start_time" | bc -l)
echo "병렬 업로드 시간: ${parallel_time}초"

# 성능 개선 계산
improvement=$(echo "scale=2; ($sequential_time - $parallel_time) / $sequential_time * 100" | bc -l)
echo "병렬 처리 성능 개선: ${improvement}%"
```

#### 동시 연결 수 테스트

```bash
echo "=== 동시 연결 수 테스트 ==="

# 다양한 동시 연결 수로 테스트
for concurrent in 1 5 10 20; do
    echo "동시 연결 수: $concurrent"
    
    # 테스트 파일 준비
    for i in $(seq 1 $concurrent); do
        dd if=/dev/zero of=concurrent_${concurrent}_${i}.dat bs=1M count=5 2>/dev/null
    done
    
    # 동시 업로드 테스트
    start_time=$(date +%s.%N)
    for i in $(seq 1 $concurrent); do
        mc cp concurrent_${concurrent}_${i}.dat local/test-bucket/concurrent_${concurrent}_${i}.dat >/dev/null 2>&1 &
    done
    wait
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    total_size=$(echo "$concurrent * 5" | bc)  # MB
    throughput=$(echo "scale=2; $total_size / $duration" | bc -l)
    
    echo "  - 총 크기: ${total_size}MB"
    echo "  - 소요 시간: ${duration}초"
    echo "  - 처리량: ${throughput}MB/s"
    echo ""
done
```

### 5단계: 시스템 리소스 모니터링

#### 리소스 사용량 모니터링 스크립트

```bash
# 모니터링 스크립트 생성
cat > monitor_resources.sh << 'EOF'
#!/bin/bash

echo "=== 시스템 리소스 모니터링 ==="
echo "시간,CPU사용률,메모리사용률,디스크I/O" > results/resource_usage.csv

# 백그라운드에서 리소스 모니터링
monitor_resources() {
    while true; do
        timestamp=$(date '+%H:%M:%S')
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        disk_io=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk 'NR==1{print $4+$5}' || echo "N/A")
        
        echo "$timestamp,$cpu_usage,$mem_usage,$disk_io" >> results/resource_usage.csv
        sleep 5
    done
}

# 모니터링 시작
monitor_resources &
MONITOR_PID=$!

echo "리소스 모니터링 시작됨 (PID: $MONITOR_PID)"
echo "대용량 파일 업로드 중 리소스 사용량을 모니터링합니다..."

# 대용량 파일 업로드 (모니터링 대상)
dd if=/dev/zero of=monitoring_test.dat bs=1M count=1000 2>/dev/null
mc cp monitoring_test.dat local/test-bucket/monitoring_test.dat

# 모니터링 중지
kill $MONITOR_PID 2>/dev/null
wait $MONITOR_PID 2>/dev/null

echo "리소스 모니터링 완료"
echo "결과는 results/resource_usage.csv에서 확인 가능합니다."
EOF

chmod +x monitor_resources.sh
./monitor_resources.sh
```

### 6단계: MinIO 서버 성능 메트릭

#### MinIO 내부 메트릭 확인

```bash
echo "=== MinIO 서버 메트릭 ==="

# MinIO 서버 정보
mc admin info local

# 서버 성능 통계
mc admin prometheus metrics local > results/minio_metrics.txt

# 주요 메트릭 추출
echo "주요 성능 메트릭:"
grep -E "(minio_http_requests_total|minio_s3_requests_total|minio_network)" results/minio_metrics.txt | head -10
```

#### 실시간 성능 모니터링

```bash
# 실시간 API 호출 추적 (별도 터미널에서 실행 권장)
echo "실시간 API 호출 추적을 시작합니다..."
echo "다른 터미널에서 다음 명령을 실행하세요:"
echo "mc admin trace local --verbose"

# 테스트 트래픽 생성
echo "테스트 트래픽 생성 중..."
for i in {1..5}; do
    mc cp file_10mb.dat local/test-bucket/trace_test_${i}.dat >/dev/null 2>&1
    mc cp local/test-bucket/trace_test_${i}.dat downloads/trace_downloaded_${i}.dat >/dev/null 2>&1
done
```

### 7단계: 성능 최적화 테스트

#### 다양한 설정으로 성능 비교

```bash
echo "=== 성능 최적화 테스트 ==="

# 현재 MinIO 설정 확인
echo "현재 MinIO API 설정:"
mc admin config get local api

# 멀티파트 업로드 임계값 확인
echo -e "\n현재 멀티파트 설정:"
mc admin config get local api | grep -E "(multipart_size|max_parts_count)"

# 다양한 청크 크기로 업로드 테스트
echo -e "\n청크 크기별 성능 테스트:"
for chunk_size in 5 16 32 64; do
    echo "청크 크기: ${chunk_size}MB"
    
    # 테스트 파일 생성
    dd if=/dev/zero of=chunk_test_${chunk_size}mb.dat bs=1M count=200 2>/dev/null
    
    # 업로드 시간 측정
    start_time=$(date +%s.%N)
    mc cp chunk_test_${chunk_size}mb.dat local/test-bucket/chunk_test_${chunk_size}mb.dat
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    throughput=$(echo "scale=2; 200 / $duration" | bc -l)
    
    echo "  - 소요 시간: ${duration}초"
    echo "  - 처리량: ${throughput}MB/s"
    echo ""
done
```

### 8단계: 성능 테스트 결과 분석

#### 종합 성능 리포트 생성

```bash
# 성능 리포트 생성
cat > generate_report.py << 'EOF'
#!/usr/bin/env python3
import csv
import os
from datetime import datetime

def generate_performance_report():
    """성능 테스트 종합 리포트 생성"""
    
    report = f"""
# MinIO 성능 테스트 리포트
생성 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 테스트 환경
- 시스템: {os.uname().sysname} {os.uname().release}
- 아키텍처: {os.uname().machine}

## 성능 테스트 결과

### 1. 파일 크기별 성능
"""
    
    # 타이밍 결과 분석
    if os.path.exists('results/timing_results.csv'):
        with open('results/timing_results.csv', 'r') as f:
            reader = csv.reader(f)
            next(reader)  # 헤더 스킵
            
            upload_times = {}
            download_times = {}
            
            for row in reader:
                test_name, duration = row[0], float(row[1])
                if test_name.startswith('Upload_'):
                    size = test_name.replace('Upload_', '')
                    upload_times[size] = duration
                elif test_name.startswith('Download_'):
                    size = test_name.replace('Download_', '')
                    download_times[size] = duration
            
            report += "\n| 파일 크기 | 업로드 시간(초) | 다운로드 시간(초) |\n"
            report += "|-----------|----------------|------------------|\n"
            
            for size in ['1kb', '100kb', '1mb', '10mb', '50mb', '100mb', '500mb', '1gb']:
                upload_time = upload_times.get(size, 'N/A')
                download_time = download_times.get(size, 'N/A')
                report += f"| {size} | {upload_time} | {download_time} |\n"
    
    report += """
### 2. 성능 최적화 권장사항

1. **파일 크기별 최적화**
   - 100MB 이상: Multipart Upload 자동 활성화
   - 1GB 이상: 청크 크기 32MB 이상 권장

2. **동시 연결 최적화**
   - 단일 노드: 5-10개 동시 연결 권장
   - 다중 노드: 노드당 10-20개 동시 연결 권장

3. **시스템 리소스 최적화**
   - CPU: 멀티코어 활용을 위한 병렬 처리
   - 메모리: 버퍼링을 위한 충분한 RAM 확보
   - 스토리지: SSD 사용 권장

### 3. 병목 지점 분석

주요 병목 지점:
- 네트워크 I/O: 클러스터 내부 통신
- 디스크 I/O: 스토리지 읽기/쓰기 성능
- CPU: 암호화 및 체크섬 계산

### 4. 모니터링 권장사항

정기적으로 모니터링해야 할 지표:
- 처리량 (MB/s)
- 응답 시간 (ms)
- 에러율 (%)
- 리소스 사용률 (CPU, Memory, Disk)
"""
    
    # 리포트 저장
    with open('results/performance_report.md', 'w') as f:
        f.write(report)
    
    print("성능 리포트가 results/performance_report.md에 저장되었습니다.")

if __name__ == "__main__":
    generate_performance_report()
EOF

python3 generate_report.py
```

#### 결과 시각화 (선택사항)

```bash
# 간단한 성능 그래프 생성 (gnuplot 사용)
if command -v gnuplot >/dev/null 2>&1; then
    echo "성능 그래프 생성 중..."
    
    # 업로드 성능 그래프 데이터 준비
    echo "# 파일크기(MB) 처리량(MB/s)" > results/upload_performance.dat
    echo "0.001 $(echo "0.001 / $(grep Upload_1kb results/timing_results.csv | cut -d, -f2)" | bc -l)" >> results/upload_performance.dat
    echo "0.1 $(echo "0.1 / $(grep Upload_100kb results/timing_results.csv | cut -d, -f2)" | bc -l)" >> results/upload_performance.dat
    echo "1 $(echo "1 / $(grep Upload_1mb results/timing_results.csv | cut -d, -f2)" | bc -l)" >> results/upload_performance.dat
    
    # 그래프 생성
    gnuplot << EOF
set terminal png
set output 'results/upload_performance.png'
set title 'MinIO Upload Performance'
set xlabel 'File Size (MB)'
set ylabel 'Throughput (MB/s)'
set logscale x
plot 'results/upload_performance.dat' with linespoints title 'Upload Throughput'
EOF
    
    echo "성능 그래프가 results/upload_performance.png에 저장되었습니다."
else
    echo "gnuplot이 설치되지 않아 그래프 생성을 건너뜁니다."
fi
```

### 9단계: 결과 요약 및 분석

```bash
echo "=== 성능 테스트 결과 요약 ==="

# 테스트 결과 파일들 확인
echo "생성된 결과 파일들:"
ls -la results/

# 주요 결과 출력
echo -e "\n=== 주요 성능 지표 ==="
if [ -f results/timing_results.csv ]; then
    echo "가장 빠른 업로드: $(grep Upload results/timing_results.csv | sort -t, -k2 -n | head -1)"
    echo "가장 느린 업로드: $(grep Upload results/timing_results.csv | sort -t, -k2 -nr | head -1)"
    echo "가장 빠른 다운로드: $(grep Download results/timing_results.csv | sort -t, -k2 -n | head -1)"
    echo "가장 느린 다운로드: $(grep Download results/timing_results.csv | sort -t, -k2 -nr | head -1)"
fi

# 리소스 사용량 요약
if [ -f results/resource_usage.csv ]; then
    echo -e "\n=== 리소스 사용량 요약 ==="
    echo "평균 CPU 사용률: $(tail -n +2 results/resource_usage.csv | cut -d, -f2 | awk '{sum+=$1; count++} END {printf "%.1f%%", sum/count}')"
    echo "평균 메모리 사용률: $(tail -n +2 results/resource_usage.csv | cut -d, -f3 | awk '{sum+=$1; count++} END {printf "%.1f%%", sum/count}')"
fi

echo -e "\n=== 성능 최적화 권장사항 ==="
echo "1. 100MB 이상 파일은 Multipart Upload 활용"
echo "2. 병렬 업로드로 처리량 개선 (5-10개 동시 연결)"
echo "3. SSD 스토리지 사용으로 I/O 성능 향상"
echo "4. 네트워크 대역폭 최적화"
echo "5. 정기적인 성능 모니터링 실시"
```

## 🎯 실습 완료 체크리스트

- [ ] 다양한 파일 크기별 성능 측정 완료
- [ ] 순차 vs 병렬 업로드 성능 비교 완료
- [ ] 동시 연결 수별 성능 테스트 완료
- [ ] 시스템 리소스 사용량 모니터링 완료
- [ ] MinIO 서버 메트릭 수집 완료
- [ ] 성능 최적화 설정 테스트 완료
- [ ] 종합 성능 리포트 생성 완료

## 🧹 정리

실습이 완료되면 테스트 파일들을 정리합니다:

```bash
# 성능 테스트 디렉토리로 이동
cd /home/luke/minio_lab_k8s

# 테스트 파일 정리
rm -rf performance-test

# MinIO 테스트 객체 정리 (선택사항)
mc rm --recursive local/test-bucket/ --force
```

## 📚 다음 단계

이제 **Lab 6: 사용자 및 권한 관리**로 진행하여 MinIO의 보안 기능을 학습해보세요.

## 💡 핵심 포인트

1. **파일 크기**에 따라 성능 특성이 크게 달라집니다
2. **병렬 처리**는 전체 처리량을 크게 개선시킵니다
3. **시스템 리소스** 모니터링은 병목 지점 파악에 필수입니다
4. **네트워크와 스토리지 I/O**가 주요 성능 결정 요소입니다
5. **정기적인 성능 테스트**로 시스템 상태를 점검해야 합니다

---

**🔗 관련 문서:**
- [LAB-05-CONCEPTS.md](LAB-05-CONCEPTS.md) - 성능 테스트 상세 개념 (예정)
- [LAB-06-GUIDE.md](LAB-06-GUIDE.md) - 다음 Lab Guide: 사용자 및 권한 관리
