# Lab 5 핵심 개념: MinIO 성능 테스트 및 최적화

## 개요

Lab 5에서는 MinIO의 성능을 체계적으로 측정하고 분석하는 방법을 학습합니다. 다양한 파일 크기와 동시 연결 시나리오를 통해 실제 운영 환경에서의 성능 특성을 이해하고 최적화 방안을 도출합니다.

## 핵심 개념

### 1. 성능 측정 지표

#### 처리량 (Throughput)
단위 시간당 처리할 수 있는 데이터량을 의미합니다.

```
처리량 = 전송된 데이터 크기 / 소요 시간
단위: MB/s, GB/s, Mbps, Gbps
```

**측정 방법:**
```bash
# 파일 크기 확인
file_size=$(stat -c%s file.dat)

# 업로드 시간 측정
start_time=$(date +%s.%N)
mc cp file.dat local/bucket/
end_time=$(date +%s.%N)

# 처리량 계산
duration=$(echo "$end_time - $start_time" | bc)
throughput_bps=$(echo "scale=2; $file_size / $duration" | bc)
throughput_mbps=$(echo "scale=2; $throughput_bps / 1048576" | bc)
echo "처리량: ${throughput_mbps} MB/s"
```

#### 응답 시간 (Response Time)
요청을 보낸 후 응답을 받기까지의 시간입니다.

**구성 요소:**
- **네트워크 지연**: 클라이언트 ↔ 서버 간 통신 시간
- **처리 시간**: 서버에서 요청을 처리하는 시간
- **큐잉 시간**: 서버 대기열에서 기다리는 시간

#### 동시 처리 능력 (Concurrency)
동시에 처리할 수 있는 요청의 수입니다.

**측정 방법:**
```bash
# 동시 연결 테스트
concurrent_level=4
start_time=$(date +%s)

for ((i=1; i<=concurrent_level; i++)); do
    mc cp file-${i}.dat local/bucket/ &
done
wait

end_time=$(date +%s)
total_time=$((end_time - start_time))
echo "동시 연결 $concurrent_level개 처리 시간: ${total_time}초"
```

### 2. 파일 크기별 성능 특성

#### 작은 파일 (< 1MB)

**특성:**
- 연결 오버헤드가 성능에 큰 영향
- HTTP 헤더 처리 비중 높음
- 메타데이터 처리 시간 상대적으로 큼

**최적화 전략:**
```bash
# 배치 처리로 오버헤드 최소화
mc cp --recursive small-files/ local/bucket/batch/

# 압축 활용
tar -czf small-files.tar.gz small-files/
mc cp small-files.tar.gz local/bucket/
```

#### 중간 파일 (1MB - 64MB)

**특성:**
- 가장 효율적인 처리량 구간
- 단일 HTTP 요청으로 처리
- 네트워크 대역폭 효율적 활용

**최적화 전략:**
```bash
# 기본 업로드 방식 사용
mc cp medium-file.dat local/bucket/

# 병렬 처리로 전체 처리량 향상
for file in medium-*.dat; do
    mc cp "$file" local/bucket/ &
done
wait
```

#### 대용량 파일 (> 64MB)

**특성:**
- 자동으로 Multipart Upload 사용
- 네트워크 안정성이 중요
- 메모리 사용량 최적화됨

**최적화 전략:**
```bash
# Multipart 임계값 조정 (환경 변수)
export MC_MULTIPART_SIZE=16MB

# 재시도 로직 활용
mc cp --continue large-file.dat local/bucket/
```

### 3. 동시 연결 성능 분석

#### 동시 연결의 영향

```
성능 = f(동시 연결 수, 시스템 리소스, 네트워크 대역폭)
```

**일반적인 패턴:**
1. **선형 증가 구간**: 연결 수 증가 시 총 처리량 증가
2. **포화 구간**: 리소스 한계로 처리량 정체
3. **성능 저하 구간**: 과도한 연결로 오버헤드 증가

#### 최적 동시 연결 수 결정

**고려 요소:**
- CPU 코어 수
- 메모리 용량
- 네트워크 대역폭
- 디스크 I/O 성능

**권장 공식:**
```
최적 동시 연결 수 = CPU 코어 수 × 2 ~ 4
```

**측정 예시:**
```bash
# 다양한 동시 연결 수 테스트
for concurrent in 1 2 4 8 16; do
    echo "테스트: $concurrent 동시 연결"
    
    start_time=$(date +%s)
    for ((i=1; i<=concurrent; i++)); do
        mc cp test-10mb.dat local/bucket/test-${concurrent}-${i}.dat &
    done
    wait
    end_time=$(date +%s)
    
    total_time=$((end_time - start_time))
    total_data=$((10 * concurrent))  # MB
    throughput=$(echo "scale=2; $total_data / $total_time" | bc)
    
    echo "처리 시간: ${total_time}초, 총 처리량: ${throughput} MB/s"
done
```

### 4. 시스템 리소스 모니터링

#### CPU 사용률

**모니터링 명령어:**
```bash
# 실시간 CPU 사용률
top -p $(pgrep minio)

# 평균 CPU 사용률
sar -u 1 10

# CPU별 사용률
mpstat -P ALL 1 5
```

**최적화 지표:**
- CPU 사용률 < 80%
- I/O Wait < 10%
- Load Average < CPU 코어 수

#### 메모리 사용량

**모니터링 명령어:**
```bash
# 메모리 사용 현황
free -h

# 프로세스별 메모리 사용량
ps aux | grep minio

# 메모리 사용 패턴
vmstat 1 10
```

**최적화 지표:**
- 사용 가능 메모리 > 20%
- Swap 사용량 < 10%
- 버퍼/캐시 적절히 활용

#### 네트워크 사용률

**모니터링 명령어:**
```bash
# 네트워크 인터페이스 통계
ifstat -i eth0 1

# 네트워크 연결 상태
netstat -an | grep :9000

# 대역폭 사용률
iftop -i eth0
```

**최적화 지표:**
- 네트워크 사용률 < 80%
- 패킷 손실률 < 0.1%
- 연결 타임아웃 < 1%

#### 디스크 I/O 성능

**모니터링 명령어:**
```bash
# 디스크 I/O 통계
iostat -x 1 10

# 디스크 사용률
df -h

# I/O 대기 시간
iotop -o
```

**최적화 지표:**
- 디스크 사용률 < 90%
- I/O 대기 시간 < 100ms
- IOPS 활용률 적절

### 5. 성능 병목 지점 분석

#### 일반적인 병목 지점

1. **네트워크 대역폭**
   ```bash
   # 네트워크 속도 테스트
   iperf3 -c server-ip -t 30
   
   # 대역폭 사용률 확인
   nload eth0
   ```

2. **디스크 I/O**
   ```bash
   # 디스크 성능 테스트
   dd if=/dev/zero of=test.dat bs=1M count=1000 oflag=direct
   
   # 랜덤 I/O 성능
   fio --name=random-rw --ioengine=libaio --rw=randrw --bs=4k --numjobs=4 --size=1G --runtime=60
   ```

3. **CPU 처리 능력**
   ```bash
   # CPU 집약적 작업 테스트
   stress-ng --cpu 4 --timeout 60s
   
   # 암호화 성능 테스트
   openssl speed aes-256-cbc
   ```

4. **메모리 부족**
   ```bash
   # 메모리 압박 테스트
   stress-ng --vm 2 --vm-bytes 1G --timeout 60s
   
   # 메모리 할당 패턴 분석
   valgrind --tool=massif program
   ```

#### 병목 지점 식별 방법

**단계별 접근:**
1. **전체 성능 측정**: 기준선 설정
2. **구간별 분석**: 업로드/다운로드 구분
3. **리소스별 분석**: CPU, 메모리, 네트워크, 디스크
4. **최적화 적용**: 병목 지점 개선
5. **재측정**: 개선 효과 확인

### 6. 성능 최적화 전략

#### 클라이언트 측 최적화

1. **연결 풀링**
   ```bash
   # 환경 변수로 연결 설정 최적화
   export MC_HOST_local="http://admin:password@localhost:9000"
   export MC_INSECURE=false
   export MC_QUIET=true
   ```

2. **배치 처리**
   ```bash
   # 여러 파일 일괄 처리
   mc cp --recursive source/ local/bucket/
   
   # 미러링으로 효율적 동기화
   mc mirror source/ local/bucket/
   ```

3. **압축 활용**
   ```bash
   # 압축 가능한 데이터 압축 후 업로드
   gzip -c large-text.txt | mc pipe local/bucket/large-text.txt.gz
   
   # 압축률 vs 처리 시간 트레이드오프 고려
   ```

#### 서버 측 최적화

1. **리소스 할당**
   ```yaml
   # Kubernetes 리소스 제한
   resources:
     requests:
       memory: "4Gi"
       cpu: "2"
     limits:
       memory: "8Gi"
       cpu: "4"
   ```

2. **스토리지 최적화**
   ```bash
   # SSD 사용 권장
   # RAID 구성으로 성능/안정성 향상
   # 적절한 파일시스템 선택 (XFS 권장)
   ```

3. **네트워크 최적화**
   ```bash
   # 네트워크 버퍼 크기 조정
   echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
   echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
   ```

## 실습 시나리오

### 시나리오 1: 파일 크기별 성능 프로파일링

```bash
#!/bin/bash
# 파일 크기별 성능 테스트 스크립트

sizes=(1 10 100 1024 10240)  # KB 단위
results_file="performance_results.csv"

echo "File_Size_KB,Upload_Time_s,Download_Time_s,Upload_Throughput_MBps,Download_Throughput_MBps" > $results_file

for size_kb in "${sizes[@]}"; do
    # 테스트 파일 생성
    dd if=/dev/zero of=test_${size_kb}kb.dat bs=1024 count=$size_kb 2>/dev/null
    
    # 업로드 성능 측정
    start_time=$(date +%s.%N)
    mc cp test_${size_kb}kb.dat local/bucket/
    end_time=$(date +%s.%N)
    upload_time=$(echo "$end_time - $start_time" | bc)
    
    # 다운로드 성능 측정
    start_time=$(date +%s.%N)
    mc cp local/bucket/test_${size_kb}kb.dat downloaded_${size_kb}kb.dat
    end_time=$(date +%s.%N)
    download_time=$(echo "$end_time - $start_time" | bc)
    
    # 처리량 계산
    file_size_bytes=$((size_kb * 1024))
    upload_mbps=$(echo "scale=2; $file_size_bytes / 1048576 / $upload_time" | bc)
    download_mbps=$(echo "scale=2; $file_size_bytes / 1048576 / $download_time" | bc)
    
    # 결과 저장
    echo "$size_kb,$upload_time,$download_time,$upload_mbps,$download_mbps" >> $results_file
    
    echo "완료: ${size_kb}KB - 업로드: ${upload_mbps} MB/s, 다운로드: ${download_mbps} MB/s"
done
```

### 시나리오 2: 동시 연결 확장성 테스트

```bash
#!/bin/bash
# 동시 연결 확장성 테스트 스크립트

concurrent_levels=(1 2 4 8 16)
file_size_mb=10
results_file="concurrency_results.csv"

echo "Concurrent_Connections,Total_Time_s,Total_Throughput_MBps,Avg_Response_Time_s" > $results_file

# 테스트 파일 생성
dd if=/dev/zero of=test_${file_size_mb}mb.dat bs=1M count=$file_size_mb 2>/dev/null

for concurrent in "${concurrent_levels[@]}"; do
    echo "테스트 중: $concurrent 동시 연결"
    
    # 개별 응답 시간 측정을 위한 임시 파일들
    rm -f /tmp/response_time_*.log
    
    start_time=$(date +%s.%N)
    
    # 동시 업로드 실행
    for ((i=1; i<=concurrent; i++)); do
        {
            individual_start=$(date +%s.%N)
            mc cp test_${file_size_mb}mb.dat local/bucket/concurrent_${concurrent}_${i}.dat
            individual_end=$(date +%s.%N)
            individual_time=$(echo "$individual_end - $individual_start" | bc)
            echo "$individual_time" > /tmp/response_time_${i}.log
        } &
    done
    
    wait  # 모든 백그라운드 작업 완료 대기
    
    end_time=$(date +%s.%N)
    total_time=$(echo "$end_time - $start_time" | bc)
    
    # 총 처리량 계산
    total_data_mb=$((file_size_mb * concurrent))
    total_throughput=$(echo "scale=2; $total_data_mb / $total_time" | bc)
    
    # 평균 응답 시간 계산
    total_response_time=0
    for ((i=1; i<=concurrent; i++)); do
        if [ -f "/tmp/response_time_${i}.log" ]; then
            response_time=$(cat /tmp/response_time_${i}.log)
            total_response_time=$(echo "$total_response_time + $response_time" | bc)
        fi
    done
    avg_response_time=$(echo "scale=3; $total_response_time / $concurrent" | bc)
    
    # 결과 저장
    echo "$concurrent,$total_time,$total_throughput,$avg_response_time" >> $results_file
    
    echo "결과: 총 시간 ${total_time}s, 처리량 ${total_throughput} MB/s, 평균 응답시간 ${avg_response_time}s"
done

# 임시 파일 정리
rm -f /tmp/response_time_*.log
```

### 시나리오 3: 시스템 리소스 모니터링

```bash
#!/bin/bash
# 성능 테스트 중 시스템 리소스 모니터링

monitor_duration=60  # 모니터링 시간 (초)
results_file="system_monitoring.log"

echo "성능 테스트 중 시스템 리소스 모니터링 시작"
echo "모니터링 시간: ${monitor_duration}초"

# 백그라운드에서 시스템 모니터링 시작
{
    echo "=== 시스템 리소스 모니터링 결과 ===" > $results_file
    echo "시작 시간: $(date)" >> $results_file
    echo "" >> $results_file
    
    # CPU 사용률 모니터링
    echo "=== CPU 사용률 ===" >> $results_file
    sar -u 1 $monitor_duration >> $results_file &
    SAR_PID=$!
    
    # 메모리 사용량 모니터링
    echo "=== 메모리 사용량 ===" >> $results_file
    for ((i=1; i<=monitor_duration; i++)); do
        echo "$(date): $(free -h | grep Mem)" >> $results_file
        sleep 1
    done &
    MEMORY_PID=$!
    
    # 네트워크 사용률 모니터링
    echo "=== 네트워크 사용률 ===" >> $results_file
    ifstat -i eth0 1 $monitor_duration >> $results_file &
    IFSTAT_PID=$!
    
    wait $SAR_PID $MEMORY_PID $IFSTAT_PID
    
    echo "" >> $results_file
    echo "종료 시간: $(date)" >> $results_file
} &

MONITOR_PID=$!

# 성능 테스트 실행 (예시)
echo "성능 테스트 실행 중..."
for i in {1..10}; do
    mc cp test-file.dat local/bucket/perf-test-${i}.dat &
done
wait

# 모니터링 완료 대기
wait $MONITOR_PID

echo "모니터링 완료. 결과: $results_file"
```

## 성능 분석 및 해석

### 결과 분석 방법

1. **기준선 설정**
   - 단일 연결, 중간 크기 파일로 기준 성능 측정
   - 시스템 리소스 사용률 기준값 설정

2. **패턴 식별**
   - 파일 크기별 성능 곡선 분석
   - 동시 연결 수에 따른 확장성 패턴 확인

3. **병목 지점 식별**
   - 성능이 급격히 저하되는 구간 분석
   - 리소스 사용률과 성능의 상관관계 분석

4. **최적화 포인트 도출**
   - 가장 효율적인 파일 크기 구간 식별
   - 최적 동시 연결 수 결정
   - 시스템 리소스 최적화 방향 설정

### 성능 리포트 작성

```bash
#!/bin/bash
# 성능 테스트 리포트 생성 스크립트

report_file="performance_report_$(date +%Y%m%d_%H%M%S).md"

cat > $report_file << EOF
# MinIO 성능 테스트 리포트

## 테스트 환경
- 테스트 일시: $(date)
- 시스템 정보: $(uname -a)
- MinIO 버전: $(mc version | head -1)

## 테스트 결과 요약

### 파일 크기별 성능
$(cat performance_results.csv | column -t -s ',')

### 동시 연결별 성능
$(cat concurrency_results.csv | column -t -s ',')

## 분석 결과

### 최적 성능 구간
- 파일 크기: [분석 결과 입력]
- 동시 연결 수: [분석 결과 입력]
- 예상 처리량: [분석 결과 입력]

### 권장사항
1. [권장사항 1]
2. [권장사항 2]
3. [권장사항 3]

## 시스템 리소스 분석
$(tail -20 system_monitoring.log)

EOF

echo "성능 리포트 생성 완료: $report_file"
```

## 다음 단계

Lab 5 완료 후 다음 내용을 학습할 수 있습니다:

1. **Lab 6**: 사용자 및 권한 관리
   - 성능 테스트 결과를 바탕으로 한 권한 정책 설계
   - 사용자별 리소스 할당 최적화

2. **Lab 7**: 모니터링 설정
   - 성능 지표 기반 모니터링 대시보드 구성
   - 성능 임계값 기반 알림 설정

## 참고 자료

- [MinIO 성능 튜닝 가이드](https://docs.min.io/docs/minio-server-configuration-guide.html)
- [S3 성능 최적화](https://docs.aws.amazon.com/s3/latest/userguide/optimizing-performance.html)
- [Linux 성능 모니터링](https://www.brendangregg.com/linuxperf.html)
- [네트워크 성능 분석](https://www.speedguide.net/analyzer.php)
