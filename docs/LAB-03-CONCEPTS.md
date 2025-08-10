# Lab 3 핵심 개념: MinIO Client와 S3 API 기초

## 개요

Lab 3에서는 MinIO Client (mc)를 사용하여 S3 호환 API의 기본 개념을 학습하고, 실제 데이터 업로드/다운로드를 통해 객체 스토리지의 동작 원리를 이해합니다.

## 핵심 개념

### 1. MinIO Client (mc)

MinIO Client는 MinIO 서버와 상호작용하는 명령줄 도구입니다.

#### 주요 특징
- **S3 호환성**: Amazon S3 API와 완벽 호환
- **크로스 플랫폼**: Linux, macOS, Windows 지원
- **배치 처리**: 대량 파일 처리 최적화
- **암호화 지원**: 전송 중 및 저장 시 암호화

#### 핵심 명령어
```bash
# 서버 연결 설정
mc alias set <alias> <url> <access-key> <secret-key>

# 버킷 관리
mc mb <alias>/<bucket>          # 버킷 생성
mc rb <alias>/<bucket>          # 버킷 삭제
mc ls <alias>/<bucket>          # 목록 조회

# 객체 관리
mc cp <source> <target>         # 복사 (업로드/다운로드)
mc rm <alias>/<bucket>/<object> # 삭제
mc stat <alias>/<bucket>/<object> # 상태 조회
```

### 2. S3 API 기본 구조

#### 계층 구조
```
Account (계정)
└── Bucket (버킷) - 최상위 컨테이너
    └── Object (객체) - 실제 파일과 메타데이터
        ├── Key (키) - 객체의 고유 식별자
        ├── Value (값) - 실제 파일 데이터
        └── Metadata (메타데이터) - 파일 정보
```

#### 버킷 (Bucket)
- **전역 고유성**: 버킷명은 전역적으로 고유해야 함
- **DNS 규칙**: 소문자, 숫자, 하이픈만 사용
- **네임스페이스**: 모든 객체의 최상위 컨테이너

#### 객체 (Object)
- **키-값 구조**: 키(파일명+경로)와 값(데이터)으로 구성
- **메타데이터**: 시스템 및 사용자 정의 메타데이터
- **버전 관리**: 동일 키에 대한 여러 버전 지원

### 3. 포트 포워딩 (Port Forwarding)

Kubernetes 환경에서 클러스터 내부 서비스에 접근하는 방법입니다.

#### 동작 원리
```
로컬 컴퓨터:9000 ←→ kubectl ←→ Kubernetes Service ←→ MinIO Pod
```

#### 장점과 단점
**장점:**
- 간단한 설정
- 개발/테스트 환경에 적합
- 보안 터널 제공

**단점:**
- 단일 연결만 지원
- 터미널 종료 시 연결 끊김
- 프로덕션 환경 부적합

### 4. 데이터 무결성 검증

#### 검증 방법

1. **파일 크기 비교**
   ```bash
   stat -c%s original_file
   stat -c%s downloaded_file
   ```

2. **해시 비교**
   ```bash
   md5sum original_file
   md5sum downloaded_file
   ```

3. **바이트 단위 비교**
   ```bash
   diff original_file downloaded_file
   ```

4. **ETag 검증**
   ```bash
   mc stat local/bucket/object | grep ETag
   ```

#### ETag의 이해
- **단일 파트**: 일반적으로 MD5 해시
- **멀티파트**: 특별한 형식 (MD5-파트수)
- **변경 감지**: 객체 변경 시 ETag도 변경

### 5. MinIO 데이터 구조

#### 파일시스템 구조
```
/export/
├── .minio.sys/          # 시스템 메타데이터
│   ├── config/          # 서버 설정
│   ├── buckets/         # 버킷 메타데이터
│   └── tmp/             # 임시 파일
└── bucket-name/         # 각 버킷별 디렉토리
    ├── xl.meta          # 객체 메타데이터
    ├── part.1           # 데이터 조각 1
    ├── part.2           # 데이터 조각 2
    └── ...
```

#### Erasure Coding 적용
- **데이터 분할**: 파일을 여러 조각으로 분할
- **패리티 생성**: 오류 복구용 패리티 데이터 생성
- **분산 저장**: 각 조각을 다른 드라이브에 저장
- **자동 복구**: 일부 드라이브 장애 시 자동 복구

## 실습 시나리오

### 시나리오 1: 기본 파일 업로드/다운로드

```bash
# 1. 테스트 파일 생성
echo "Hello MinIO!" > test.txt

# 2. 버킷 생성
mc mb local/my-bucket

# 3. 파일 업로드
mc cp test.txt local/my-bucket/

# 4. 파일 다운로드
mc cp local/my-bucket/test.txt downloaded.txt

# 5. 무결성 검증
md5sum test.txt downloaded.txt
```

### 시나리오 2: 계층 구조 시뮬레이션

```bash
# 1. 디렉토리 구조 생성
mkdir -p docs/reports
echo "Report data" > docs/reports/monthly.txt

# 2. 계층 구조로 업로드
mc cp --recursive docs/ local/my-bucket/documents/

# 3. 구조 확인
mc ls --recursive local/my-bucket/
```

### 시나리오 3: 메타데이터 활용

```bash
# 1. 메타데이터와 함께 업로드
mc cp --attr "Author=John,Department=IT" file.txt local/my-bucket/

# 2. 메타데이터 확인
mc stat local/my-bucket/file.txt
```

## 문제 해결

### 일반적인 문제들

#### 1. 포트 포워딩 실패
**증상**: 연결 거부 또는 타임아웃
**해결책**:
```bash
# 포트 사용 확인
netstat -tlnp | grep :9000

# 기존 프로세스 종료
pkill -f "kubectl port-forward.*minio"

# 포트 포워딩 재시작
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
```

#### 2. 인증 실패
**증상**: Access Denied 오류
**해결책**:
```bash
# 연결 설정 확인
mc alias list local

# 서버 상태 확인
mc admin info local

# 연결 재설정
mc alias set local http://localhost:9000 admin password123
```

#### 3. 파일 업로드 실패
**증상**: 업로드 중 오류 발생
**해결책**:
```bash
# 디스크 공간 확인
df -h

# 권한 확인
mc admin user info local admin

# 버킷 존재 확인
mc ls local/
```

## 성능 최적화

### 업로드 최적화
- **병렬 업로드**: 여러 파일 동시 업로드
- **적절한 파일 크기**: 1MB-100MB 권장
- **네트워크 최적화**: 안정적인 연결 유지

### 다운로드 최적화
- **미러링 사용**: `mc mirror` 명령어 활용
- **재시도 로직**: 네트워크 오류 시 자동 재시도
- **압축 활용**: 가능한 경우 압축 파일 사용

## 보안 고려사항

### 연결 보안
- **HTTPS 사용**: 프로덕션 환경에서 필수
- **인증서 검증**: SSL/TLS 인증서 유효성 확인
- **액세스 키 보호**: 키 노출 방지

### 데이터 보안
- **전송 암호화**: TLS를 통한 데이터 전송
- **저장 암호화**: 서버 측 암호화 활성화
- **액세스 로그**: 모든 접근 기록 유지

## 모니터링 및 로깅

### 성능 모니터링
```bash
# 서버 상태 확인
mc admin info local

# 처리량 모니터링
time mc cp large-file.dat local/bucket/

# 연결 상태 확인
mc admin trace local
```

### 로그 분석
- **업로드/다운로드 로그**: 성능 분석
- **오류 로그**: 문제 진단
- **액세스 로그**: 보안 감사

## 다음 단계

Lab 3 완료 후 다음 내용을 학습할 수 있습니다:

1. **Lab 4**: S3 API 고급 기능
   - Multipart Upload
   - 메타데이터 관리
   - 성능 최적화

2. **Lab 5**: 성능 테스트
   - 처리량 측정
   - 동시 연결 테스트
   - 병목 지점 분석

3. **Lab 6**: 사용자 및 권한 관리
   - IAM 시스템
   - 정책 기반 제어
   - 보안 모범 사례

## 참고 자료

- [MinIO Client 공식 문서](https://docs.min.io/docs/minio-client-complete-guide.html)
- [S3 API 참조](https://docs.aws.amazon.com/s3/latest/API/)
- [Kubernetes 포트 포워딩](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
- [데이터 무결성 검증](https://en.wikipedia.org/wiki/Data_integrity)
