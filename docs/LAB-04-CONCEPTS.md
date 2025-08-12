# Lab 4 핵심 개념: S3 API 고급 기능

## 개요

Lab 4에서는 S3 API의 고급 기능들을 학습합니다. Multipart Upload, 메타데이터 관리, 성능 최적화 기법 등을 통해 실제 운영 환경에서 필요한 고급 기술들을 습득합니다.

## 핵심 개념

### 1. Multipart Upload

대용량 파일을 여러 부분으로 나누어 병렬로 업로드하는 기술입니다.

#### 동작 원리

```
대용량 파일 (100MB)
    ↓ 분할
┌─────────┬─────────┬─────────┬─────────┐
│ Part 1  │ Part 2  │ Part 3  │ Part 4  │
│ 25MB    │ 25MB    │ 25MB    │ 25MB    │
└─────────┴─────────┴─────────┴─────────┘
    ↓ 병렬 업로드
┌─────────────────────────────────────────┐
│           MinIO Server                  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐      │
│  │ P1  │ │ P2  │ │ P3  │ │ P4  │      │
│  └─────┘ └─────┘ └─────┘ └─────┘      │
└─────────────────────────────────────────┘
    ↓ 결합
완성된 객체 (100MB)
```

#### 3단계 프로세스

1. **Initiate Multipart Upload**
   - 업로드 세션 시작
   - Upload ID 생성
   - 메타데이터 설정

2. **Upload Parts**
   - 각 파트를 개별적으로 업로드
   - 병렬 처리 가능
   - 실패 시 해당 파트만 재시도

3. **Complete Multipart Upload**
   - 모든 파트를 하나의 객체로 결합
   - ETag 생성
   - 메타데이터 최종 설정

#### 장점과 특징

**장점:**
- **안정성**: 네트워크 장애 시 부분 재시도
- **성능**: 병렬 업로드로 속도 향상
- **효율성**: 메모리 사용량 최적화
- **재개 가능**: 중단된 업로드 재개

**기술적 제약:**
- 최소 파트 크기: 5MB (마지막 파트 제외)
- 최대 파트 수: 10,000개
- 최대 객체 크기: 5TB

#### MinIO에서의 자동 처리

```bash
# MinIO Client가 자동으로 Multipart Upload 사용
mc cp large-file.dat local/bucket/

# 임계값 (기본 64MB) 이상 파일은 자동으로 분할
# 사용자는 별도 설정 불필요
```

### 2. 객체 메타데이터 관리

#### 메타데이터 유형

1. **시스템 메타데이터**
   - Content-Type: MIME 타입
   - Content-Length: 파일 크기
   - Last-Modified: 최종 수정 시간
   - ETag: 객체 식별자

2. **사용자 메타데이터**
   - 사용자 정의 키-값 쌍
   - 'x-amz-meta-' 접두사 자동 추가
   - 최대 2KB 크기 제한

3. **HTTP 헤더**
   - Cache-Control: 캐싱 정책
   - Expires: 만료 시간
   - Content-Encoding: 인코딩 방식

#### 메타데이터 설정 방법

```bash
# 업로드 시 메타데이터 설정
mc cp --attr "Author=John,Department=IT,Version=1.0" \
      file.txt local/bucket/

# Content-Type 설정
mc cp --attr "Content-Type=application/json" \
      data.json local/bucket/

# 복합 메타데이터 설정
mc cp --attr "Content-Type=text/html,Cache-Control=max-age=3600,Author=WebTeam" \
      index.html local/bucket/
```

#### 메타데이터 활용 사례

1. **파일 분류**
   ```bash
   # 부서별 분류
   --attr "Department=Engineering"
   --attr "Department=Marketing"
   
   # 프로젝트별 분류
   --attr "Project=WebApp,Version=2.1"
   ```

2. **접근 제어**
   ```bash
   # 보안 레벨 설정
   --attr "SecurityLevel=Confidential"
   --attr "AccessLevel=Internal"
   ```

3. **생명주기 관리**
   ```bash
   # 보관 정책 설정
   --attr "RetentionPeriod=7years"
   --attr "ArchiveDate=2024-12-31"
   ```

### 3. 고급 검색 및 필터링

#### 검색 방법

1. **프리픽스 기반 검색**
   ```bash
   # 특정 경로의 객체들
   mc ls local/bucket/images/
   mc ls local/bucket/documents/2024/
   ```

2. **패턴 매칭**
   ```bash
   # 와일드카드 사용
   mc find local/bucket/ --name "*.jpg"
   mc find local/bucket/ --name "report-*.pdf"
   ```

3. **시간 기반 필터링**
   ```bash
   # 최근 수정된 파일들
   mc find local/bucket/ --newer-than 7d
   mc find local/bucket/ --older-than 30d
   ```

4. **크기 기반 필터링**
   ```bash
   # 크기별 검색
   mc find local/bucket/ --larger 100MB
   mc find local/bucket/ --smaller 1KB
   ```

#### 고급 검색 예시

```bash
# 복합 조건 검색
mc find local/bucket/ \
  --name "*.log" \
  --newer-than 1d \
  --larger 10MB

# 메타데이터 기반 검색 (SQL 쿼리 사용)
mc sql --query "SELECT * FROM s3object WHERE s3object.Department = 'Engineering'" \
       local/bucket/metadata.json
```

### 4. 성능 최적화 기법

#### 병렬 처리 최적화

1. **동시 업로드**
   ```bash
   # 백그라운드 병렬 업로드
   for file in *.dat; do
       mc cp "$file" local/bucket/ &
   done
   wait  # 모든 작업 완료 대기
   ```

2. **배치 처리**
   ```bash
   # 여러 파일 일괄 처리
   mc cp --recursive source-dir/ local/bucket/
   
   # 미러링 (동기화)
   mc mirror source-dir/ local/bucket/
   ```

#### 네트워크 최적화

1. **압축 활용**
   ```bash
   # 압축 후 업로드
   gzip -c large-file.txt | mc pipe local/bucket/large-file.txt.gz
   
   # 압축률 비교
   original_size=$(stat -c%s large-file.txt)
   compressed_size=$(stat -c%s large-file.txt.gz)
   ratio=$(( (original_size - compressed_size) * 100 / original_size ))
   echo "압축률: ${ratio}%"
   ```

2. **연결 최적화**
   ```bash
   # 연결 풀링 설정 (환경 변수)
   export MC_HOST_local="http://admin:password@localhost:9000"
   
   # Keep-Alive 연결 유지
   export MC_INSECURE=true  # 개발 환경에서만
   ```

#### 파일 크기별 최적화 전략

| 파일 크기 | 최적화 전략 | 권장 방법 |
|-----------|-------------|-----------|
| < 1MB | 배치 처리 | 여러 파일 묶어서 처리 |
| 1-64MB | 단일 업로드 | 기본 `mc cp` 사용 |
| 64MB-1GB | Multipart | 자동 처리 (설정 불필요) |
| > 1GB | 병렬 Multipart | 네트워크 대역폭 최대 활용 |

### 5. 스토리지 클래스 및 생명주기

#### 스토리지 클래스 개념

```bash
# 스토리지 클래스 설정
mc cp --storage-class STANDARD file.txt local/bucket/
mc cp --storage-class REDUCED_REDUNDANCY backup.txt local/bucket/
```

#### 생명주기 정책 예시

```json
{
  "Rules": [
    {
      "ID": "ArchiveOldFiles",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "logs/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

## 실습 시나리오

### 시나리오 1: 대용량 파일 최적화 업로드

```bash
# 1. 대용량 파일 생성 (100MB)
dd if=/dev/zero of=large-file.dat bs=1M count=100

# 2. 업로드 시간 측정
time mc cp large-file.dat local/bucket/

# 3. Multipart 동작 확인
mc stat local/bucket/large-file.dat | grep -i multipart
```

### 시나리오 2: 메타데이터 기반 파일 관리

```bash
# 1. 부서별 파일 업로드
mc cp --attr "Department=Engineering,Project=WebApp" \
      app.js local/bucket/

mc cp --attr "Department=Marketing,Campaign=Q4" \
      banner.jpg local/bucket/

# 2. 메타데이터 확인
mc stat local/bucket/app.js
mc stat local/bucket/banner.jpg

# 3. 부서별 파일 검색 (개념적)
# 실제로는 별도 인덱싱 시스템 필요
```

### 시나리오 3: 성능 비교 테스트

```bash
# 1. 순차 업로드 테스트
start_time=$(date +%s)
for i in {1..5}; do
    mc cp file-${i}.dat local/bucket/sequential/
done
sequential_time=$(($(date +%s) - start_time))

# 2. 병렬 업로드 테스트
start_time=$(date +%s)
for i in {1..5}; do
    mc cp file-${i}.dat local/bucket/parallel/ &
done
wait
parallel_time=$(($(date +%s) - start_time))

# 3. 성능 비교
echo "순차 업로드: ${sequential_time}초"
echo "병렬 업로드: ${parallel_time}초"
```

## 문제 해결

### 일반적인 문제들

#### 1. Multipart Upload 실패
**증상**: 대용량 파일 업로드 중 중단
**해결책**:
```bash
# 미완료 업로드 확인
mc admin trace local

# 미완료 업로드 정리
mc rm --incomplete --recursive local/bucket/

# 재시도
mc cp --continue large-file.dat local/bucket/
```

#### 2. 메타데이터 손실
**증상**: 업로드 후 메타데이터 누락
**해결책**:
```bash
# 메타데이터 확인
mc stat local/bucket/file.txt

# 메타데이터 재설정 (복사 방식)
mc cp --attr "Author=John" local/bucket/file.txt local/bucket/file-new.txt
mc rm local/bucket/file.txt
mc mv local/bucket/file-new.txt local/bucket/file.txt
```

#### 3. 성능 저하
**증상**: 업로드/다운로드 속도 느림
**해결책**:
```bash
# 네트워크 상태 확인
ping -c 4 localhost

# 서버 리소스 확인
mc admin info local

# 동시 연결 수 조정
# 환경에 따라 2-8개 권장
```

## 성능 벤치마킹

### 측정 지표

1. **처리량 (Throughput)**
   ```bash
   # MB/s 계산
   file_size_mb=$(( $(stat -c%s file.dat) / 1048576 ))
   upload_time=$(time mc cp file.dat local/bucket/ 2>&1 | grep real | awk '{print $2}')
   throughput=$(echo "scale=2; $file_size_mb / $upload_time" | bc)
   echo "처리량: ${throughput} MB/s"
   ```

2. **응답 시간 (Response Time)**
   ```bash
   # 평균 응답 시간 측정
   total_time=0
   for i in {1..10}; do
       start=$(date +%s.%N)
       mc cp small-file.txt local/bucket/test-${i}.txt
       end=$(date +%s.%N)
       time=$(echo "$end - $start" | bc)
       total_time=$(echo "$total_time + $time" | bc)
   done
   avg_time=$(echo "scale=3; $total_time / 10" | bc)
   echo "평균 응답 시간: ${avg_time}초"
   ```

3. **동시 처리 능력**
   ```bash
   # 동시 연결 테스트
   for concurrent in 1 2 4 8; do
       echo "동시 연결 수: $concurrent"
       start=$(date +%s)
       for ((i=1; i<=concurrent; i++)); do
           mc cp test-file.dat local/bucket/concurrent-${concurrent}-${i}.dat &
       done
       wait
       end=$(date +%s)
       echo "처리 시간: $((end - start))초"
   done
   ```

## 모니터링 및 최적화

### 성능 모니터링

```bash
# 실시간 트레이스
mc admin trace local

# 서버 통계
mc admin info local

# 프로파일링 (고급)
mc admin profile start local
# 작업 수행
mc admin profile stop local
```

### 최적화 체크리스트

- [ ] 파일 크기에 적합한 업로드 방식 선택
- [ ] 적절한 동시 연결 수 설정
- [ ] 네트워크 대역폭 최대 활용
- [ ] 압축 가능한 데이터 압축 적용
- [ ] 메타데이터 효율적 활용
- [ ] 정기적인 성능 벤치마킹

## 다음 단계

Lab 4 완료 후 다음 내용을 학습할 수 있습니다:

1. **Lab 5**: 성능 테스트
   - 체계적인 성능 측정
   - 병목 지점 분석
   - 최적화 전략 수립

2. **Lab 6**: 사용자 및 권한 관리
   - IAM 시스템 구축
   - 정책 기반 접근 제어
   - 보안 모범 사례

## 참고 자료

- [AWS S3 Multipart Upload](https://docs.aws.amazon.com/s3/latest/userguide/mpuoverview.html)
- [MinIO 성능 튜닝](https://docs.min.io/docs/minio-server-configuration-guide.html)
- [S3 메타데이터 가이드](https://docs.aws.amazon.com/s3/latest/userguide/UsingMetadata.html)
- [객체 스토리지 최적화](https://min.io/resources/docs/MinIO-object-storage-for-kubernetes.pdf)
