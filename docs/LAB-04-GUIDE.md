# Lab 4: S3 API 고급 기능 - Lab Guide

## 📚 학습 목표

이 실습에서는 MinIO의 S3 호환 API를 사용하여 고급 기능들을 학습합니다:

- **Multipart Upload**: 대용량 파일의 효율적인 업로드
- **메타데이터 관리**: 객체에 사용자 정의 메타데이터 추가
- **스토리지 클래스**: 다양한 스토리지 옵션 활용
- **객체 태깅**: 객체 분류 및 관리
- **Pre-signed URL**: 임시 접근 URL 생성

## 🎯 핵심 개념

### Multipart Upload vs Single Part Upload

| 구분 | Single Part | Multipart |
|------|-------------|-----------|
| **파일 크기** | < 5GB | > 100MB 권장 |
| **업로드 방식** | 한 번에 전송 | 여러 부분으로 분할 |
| **재시도** | 전체 재업로드 | 실패한 부분만 재업로드 |
| **병렬 처리** | 불가능 | 가능 |
| **네트워크 효율성** | 낮음 | 높음 |

### 메타데이터 활용
- **시스템 메타데이터**: Content-Type, Content-Length 등
- **사용자 메타데이터**: X-Amz-Meta-* 헤더로 추가
- **태그**: 키-값 쌍으로 객체 분류

## 🚀 실습 시작

### 1단계: 환경 확인

먼저 MinIO 서비스가 실행 중인지 확인합니다:

```bash
# MinIO 서비스 상태 확인
kubectl get pods -n minio-tenant

# 포트 포워딩 확인 (필요시 재실행)
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
```

### 2단계: 테스트 파일 준비

다양한 크기의 테스트 파일을 생성합니다:

```bash
# 작은 파일 (1MB)
dd if=/dev/zero of=small-file.dat bs=1M count=1

# 중간 파일 (50MB)
dd if=/dev/zero of=medium-file.dat bs=1M count=50

# 큰 파일 (200MB) - Multipart Upload 테스트용
dd if=/dev/zero of=large-file.dat bs=1M count=200

# 파일 크기 확인
ls -lh *.dat
```

### 3단계: 기본 업로드 vs Multipart Upload 비교

#### 기본 업로드 (작은 파일)

```bash
# 작은 파일 업로드 (Single Part)
echo "작은 파일 업로드 시작..."
time mc cp small-file.dat local/test-bucket/small-file.dat

# 업로드 상세 정보 확인
mc stat local/test-bucket/small-file.dat

# 📋 예상 결과:
# real    0m0.123s
# user    0m0.045s
# sys     0m0.012s
# 
# Name      : small-file.dat
# Date      : 2024-08-11 01:30:15 UTC
# Size      : 1.0 MiB
# ETag      : d41d8cd98f00b204e9800998ecf8427e
# Type      : application/octet-stream
# Metadata  :
#   Content-Type: application/octet-stream
```

#### Multipart Upload (큰 파일)

```bash
# 큰 파일 업로드 (자동으로 Multipart Upload 사용)
echo "큰 파일 업로드 시작..."
time mc cp large-file.dat local/test-bucket/large-file.dat

# Multipart Upload 설정 확인
mc admin config get local api

# 📋 실제 결과 (최신 MinIO):
# real    0m2.456s  (Single Part보다 오래 걸림)
# user    0m0.234s
# sys     0m0.089s
# 
# API 설정 출력 예시:
# api requests_max=0 cluster_deadline=10s cors_allow_origin=* remote_transport_deadline=2h 
# list_quorum=strict replication_priority=auto replication_max_workers=500 ...
# 
# 💡 설명:
# - 200MB 파일은 자동으로 Multipart Upload 사용 (MinIO 내부 로직)
# - 기본적으로 64MB 청크로 분할되어 업로드 (하드코딩된 값)
# - 네트워크 오류 시 실패한 부분만 재업로드 가능
# - multipart_size는 최신 버전에서 설정 파일에 노출되지 않음
```

**💡 관찰 포인트:**
- 업로드 시간 차이
- 네트워크 사용량
- 메모리 사용량

### 4단계: 메타데이터 관리

#### 사용자 정의 메타데이터 추가

```bash
# 메타데이터와 함께 파일 업로드
mc cp medium-file.dat local/test-bucket/medium-with-metadata.dat \
  --attr "X-Amz-Meta-Author=MinIO-Lab" \
  --attr "X-Amz-Meta-Purpose=Testing" \
  --attr "X-Amz-Meta-Version=1.0" \
  --attr "Content-Type=application/octet-stream"

# 메타데이터 확인
mc stat local/test-bucket/medium-with-metadata.dat

# 📋 예상 결과:
# Name      : medium-with-metadata.dat
# Date      : 2024-08-11 01:35:22 UTC
# Size      : 50.0 MiB
# ETag      : 9bb58f26192e4ba00f01e2e7b136bbd8
# Type      : application/octet-stream
# Metadata  :
#   Content-Type         : application/octet-stream
#   X-Amz-Meta-Author    : MinIO-Lab
#   X-Amz-Meta-Purpose   : Testing
#   X-Amz-Meta-Version   : 1.0
# 
# 💡 설명:
# - 사용자 정의 메타데이터는 X-Amz-Meta- 접두사로 저장
# - 메타데이터는 객체와 함께 저장되어 검색 가능
# - Content-Type은 시스템 메타데이터로 분류
```

#### 메타데이터 조회 및 활용

```bash
# 상세 메타데이터 조회
mc stat --json local/test-bucket/medium-with-metadata.dat | jq '.metadata'

# 특정 메타데이터 필터링
mc stat --json local/test-bucket/medium-with-metadata.dat | jq '.metadata."X-Amz-Meta-Author"'

# 📋 예상 결과:
# 전체 메타데이터:
# {
#   "Content-Type": "application/octet-stream",
#   "X-Amz-Meta-Author": "MinIO-Lab",
#   "X-Amz-Meta-Purpose": "Testing",
#   "X-Amz-Meta-Version": "1.0"
# }
# 
# 특정 메타데이터:
# "MinIO-Lab"
# 
# 💡 설명:
# - jq를 사용하여 JSON 형태의 메타데이터 파싱
# - 특정 필드만 추출하여 자동화 스크립트에서 활용 가능
```

### 5단계: 객체 태깅

#### 태그 추가 및 관리

```bash
# 태그와 함께 파일 업로드
mc cp small-file.dat local/test-bucket/tagged-file.dat \
  --tags "Environment=Lab,Type=TestData,Owner=Student"

# 기존 객체에 태그 추가
mc tag set local/test-bucket/medium-file.dat \
  "Environment=Lab" "Type=TestData" "Size=Medium"

# 태그 조회
mc tag list local/test-bucket/tagged-file.dat
mc tag list local/test-bucket/medium-file.dat
```

#### 태그 기반 검색

```bash
# 태그로 객체 검색 (MinIO Console에서 가능)
echo "태그 기반 검색은 MinIO Console에서 확인 가능합니다."
echo "브라우저에서 http://localhost:9001 접속 후 확인하세요."
```

### 6단계: Pre-signed URL 생성

#### 임시 다운로드 URL 생성

```bash
# 1시간 유효한 다운로드 URL 생성
mc share download local/test-bucket/medium-file.dat --expire=1h

# 7일 유효한 다운로드 URL 생성
mc share download local/test-bucket/large-file.dat --expire=7d
```

#### 임시 업로드 URL 생성

```bash
# 업로드용 Pre-signed URL 생성
mc share upload local/test-bucket/uploaded-via-presigned.dat --expire=1h
```

**💡 활용 예시:**
생성된 URL을 사용하여 웹 브라우저나 curl로 직접 접근 가능합니다.

### 7단계: 스토리지 클래스 활용

#### 다양한 스토리지 클래스로 업로드

```bash
# 표준 스토리지 클래스
mc cp small-file.dat local/test-bucket/standard-storage.dat \
  --storage-class STANDARD

# 축소된 중복성 스토리지 (가능한 경우)
mc cp small-file.dat local/test-bucket/reduced-redundancy.dat \
  --storage-class REDUCED_REDUNDANCY

# 스토리지 클래스 확인
mc stat local/test-bucket/standard-storage.dat
mc stat local/test-bucket/reduced-redundancy.dat
```

### 8단계: 고급 복사 옵션

#### 조건부 복사

```bash
# 원본이 더 새로운 경우에만 복사
mc cp --newer-than 1h medium-file.dat local/test-bucket/conditional-copy.dat

# 크기가 다른 경우에만 복사
mc cp --compare-size medium-file.dat local/test-bucket/size-based-copy.dat
```

#### 배치 작업

```bash
# 여러 파일을 메타데이터와 함께 업로드
for i in {1..5}; do
  echo "Test content $i" > test-batch-$i.txt
  mc cp test-batch-$i.txt local/test-bucket/ \
    --attr "X-Amz-Meta-Batch-Number=$i" \
    --attr "X-Amz-Meta-Created=$(date -Iseconds)"
done

# 배치 업로드 결과 확인
mc ls local/test-bucket/ | grep batch
```

### 9단계: 성능 최적화 설정

#### 동시 업로드 설정

```bash
# 동시 업로드 수 설정 (기본값 확인)
mc admin config get local api

# 멀티파트 임계값 확인
echo "현재 멀티파트 임계값: $(mc admin config get local api | grep multipart_size)"
```

#### 청크 크기 최적화

```bash
# 큰 파일을 다양한 청크 크기로 테스트
echo "청크 크기별 업로드 성능 테스트..."

# 5MB 청크
time mc cp large-file.dat local/test-bucket/large-5mb-chunk.dat

# 16MB 청크 (기본값)
time mc cp large-file.dat local/test-bucket/large-16mb-chunk.dat
```

### 10단계: 결과 분석 및 정리

#### 업로드된 객체 분석

```bash
# 모든 테스트 객체 목록
echo "=== 업로드된 테스트 객체 목록 ==="
mc ls local/test-bucket/

# 총 사용량 확인
echo -e "\n=== 스토리지 사용량 ==="
mc du local/test-bucket/

# 메타데이터가 있는 객체들 확인
echo -e "\n=== 메타데이터 포함 객체 ==="
mc stat local/test-bucket/medium-with-metadata.dat
mc stat local/test-bucket/tagged-file.dat
```

#### 성능 비교 결과

```bash
# 파일 크기별 업로드 시간 비교 결과 정리
echo -e "\n=== 성능 테스트 결과 요약 ==="
echo "1MB 파일: Single Part Upload 사용"
echo "50MB 파일: Single Part Upload 사용"
echo "200MB 파일: Multipart Upload 자동 사용"
echo ""
echo "💡 권장사항:"
echo "- 100MB 이상: Multipart Upload 권장"
echo "- 메타데이터 활용으로 객체 관리 효율성 증대"
echo "- Pre-signed URL로 보안 강화"
```

## 🔍 심화 학습

### 1. Multipart Upload 세부 제어

```bash
# 수동 Multipart Upload (고급)
# 1. 업로드 시작
UPLOAD_ID=$(mc admin trace --verbose local 2>&1 | grep "upload-id" | head -1)

# 2. 부분별 업로드 (실제로는 mc가 자동 처리)
echo "Multipart Upload는 mc가 자동으로 최적화하여 처리합니다."
```

### 2. 메타데이터 기반 자동화

```bash
# 메타데이터 기반 파일 분류 스크립트 예시
cat > classify_files.sh << 'EOF'
#!/bin/bash
# 파일 크기에 따른 자동 메타데이터 추가

for file in *.dat; do
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
  
  if [ $size -lt 10485760 ]; then  # 10MB 미만
    category="small"
  elif [ $size -lt 104857600 ]; then  # 100MB 미만
    category="medium"
  else
    category="large"
  fi
  
  mc cp "$file" "local/test-bucket/classified-$file" \
    --attr "X-Amz-Meta-Size-Category=$category" \
    --attr "X-Amz-Meta-Original-Size=$size"
done
EOF

chmod +x classify_files.sh
./classify_files.sh
```

### 3. 고급 태깅 전략

```bash
# 날짜 기반 태깅
TODAY=$(date +%Y-%m-%d)
mc cp medium-file.dat local/test-bucket/daily-backup.dat \
  --tags "Date=$TODAY,Type=Backup,Retention=30days"

# 환경별 태깅
mc cp small-file.dat local/test-bucket/env-specific.dat \
  --tags "Environment=Development,Application=MinIOLab,Team=DevOps"
```

## 🎯 실습 완료 체크리스트

- [ ] Single Part vs Multipart Upload 차이점 이해
- [ ] 사용자 정의 메타데이터 추가 및 조회
- [ ] 객체 태깅 시스템 활용
- [ ] Pre-signed URL 생성 및 활용
- [ ] 스토리지 클래스 개념 이해
- [ ] 조건부 복사 및 배치 작업 수행
- [ ] 성능 최적화 설정 확인

## 🧹 정리

실습이 완료되면 테스트 파일들을 정리합니다:

```bash
# 로컬 테스트 파일 삭제
rm -f *.dat *.txt classify_files.sh

# MinIO 테스트 객체 삭제 (선택사항)
mc rm --recursive local/test-bucket/
```

## 📚 다음 단계

이제 **Lab 5: 성능 테스트**로 진행하여 MinIO의 성능 특성을 자세히 분석해보세요.

## 💡 핵심 포인트

1. **Multipart Upload**는 100MB 이상 파일에서 자동으로 활성화됩니다
2. **메타데이터**를 활용하면 객체 관리가 훨씬 효율적입니다
3. **Pre-signed URL**은 보안과 편의성을 동시에 제공합니다
4. **태깅**은 객체 분류 및 라이프사이클 관리에 유용합니다
5. **스토리지 클래스**를 통해 비용과 성능을 최적화할 수 있습니다

---

**🔗 관련 문서:**
- [LAB-04-CONCEPTS.md](LAB-04-CONCEPTS.md) - S3 API 고급 기능 상세 개념
- [LAB-05-GUIDE.md](LAB-05-GUIDE.md) - 다음 Lab Guide: 성능 테스트
