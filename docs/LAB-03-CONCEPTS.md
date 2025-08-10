# Lab 3: MinIO Client 및 기본 사용법 - 핵심 개념 상세 설명

## 📚 개요

Lab 3에서는 MinIO Client(mc)를 설치하고 S3 호환 API를 사용하여 실제 데이터 작업을 수행하면서, 포트 포워딩을 통한 서비스 접근과 실제 스토리지 경로에서의 데이터 검증을 학습합니다.

## 🔍 핵심 개념 1: S3 호환 API

### S3 API란?
Amazon S3(Simple Storage Service)는 객체 스토리지의 사실상 표준이 되었으며, MinIO는 완전한 S3 호환성을 제공합니다.

#### S3 API의 핵심 개념

##### 1. 버킷(Bucket)
```bash
# 버킷은 객체를 담는 최상위 컨테이너
# 전역적으로 고유한 이름을 가져야 함 (S3의 경우)
# MinIO에서는 테넌트 내에서만 고유하면 됨

# 버킷 생성
mc mb local/my-bucket

# 버킷 목록 조회
mc ls local/

# 버킷 삭제 (비어있어야 함)
mc rb local/my-bucket
```

##### 2. 객체(Object)
```bash
# 객체는 실제 데이터와 메타데이터의 조합
# 키(Key)로 식별됨

# 객체 업로드
mc cp local-file.txt local/my-bucket/remote-file.txt

# 객체 다운로드
mc cp local/my-bucket/remote-file.txt downloaded-file.txt

# 객체 목록 조회
mc ls local/my-bucket/

# 객체 삭제
mc rm local/my-bucket/remote-file.txt
```

##### 3. 키(Key)와 경로
```bash
# S3에서는 실제 디렉토리가 없고, 키에 '/'를 포함하여 계층 구조 시뮬레이션
mc cp file1.txt local/my-bucket/folder1/subfolder/file1.txt
mc cp file2.txt local/my-bucket/folder1/file2.txt
mc cp file3.txt local/my-bucket/folder2/file3.txt

# 계층 구조처럼 보이지만 실제로는 평면적인 키-값 저장소
mc ls local/my-bucket/
# [2024-01-01 12:00:00 UTC]     0B folder1/
# [2024-01-01 12:00:00 UTC]     0B folder2/

mc ls local/my-bucket/folder1/
# [2024-01-01 12:00:00 UTC]    10B file2.txt
# [2024-01-01 12:00:00 UTC]     0B subfolder/
```

### S3 API vs 전통적인 파일시스템

#### 전통적인 파일시스템
```bash
# 계층적 디렉토리 구조
/home/user/
├── documents/
│   ├── file1.txt
│   └── reports/
│       └── report.pdf
└── pictures/
    └── photo.jpg

# 디렉토리 자체가 실제 존재
ls -la /home/user/documents/  # 디렉토리 내용 표시
mkdir /home/user/new-folder   # 빈 디렉토리 생성 가능
```

#### S3 객체 스토리지
```bash
# 평면적 키-값 구조 (계층 구조는 시뮬레이션)
my-bucket:
  - "documents/file1.txt" → 데이터
  - "documents/reports/report.pdf" → 데이터
  - "pictures/photo.jpg" → 데이터

# "디렉토리"는 키의 접두사로만 존재
mc ls local/my-bucket/documents/  # "documents/"로 시작하는 키들 표시
# 빈 "디렉토리"는 존재할 수 없음
```

## 🔍 핵심 개념 2: MinIO Client (mc) 아키텍처

### mc의 역할과 기능

#### 1. 다중 클라우드 지원
```bash
# 여러 S3 호환 서비스를 동시에 관리
mc alias set aws-s3 https://s3.amazonaws.com ACCESS_KEY SECRET_KEY
mc alias set minio-local http://localhost:9000 minio minio123
mc alias set gcs https://storage.googleapis.com ACCESS_KEY SECRET_KEY

# 서비스 간 데이터 동기화
mc mirror aws-s3/source-bucket minio-local/backup-bucket
```

#### 2. 고급 기능들
```bash
# 실시간 이벤트 모니터링
mc events add local/my-bucket arn:minio:sqs::primary:webhook --event put,delete

# 버킷 정책 관리
mc policy set public local/my-bucket

# 사용자 및 권한 관리
mc admin user add local newuser newpassword
mc admin policy attach local readwrite --user newuser

# 서버 관리
mc admin info local
mc admin heal local
```

### mc 설정 구조

#### 1. 별칭(Alias) 시스템
```bash
# 별칭 설정 파일 위치
~/.mc/config.json

# 설정 파일 구조
{
  "version": "10",
  "aliases": {
    "local": {
      "url": "http://localhost:9000",
      "accessKey": "minio",
      "secretKey": "minio123",
      "api": "s3v4",
      "path": "auto"
    },
    "s3": {
      "url": "https://s3.amazonaws.com",
      "accessKey": "YOUR_ACCESS_KEY",
      "secretKey": "YOUR_SECRET_KEY",
      "api": "s3v4",
      "path": "dns"
    }
  }
}
```

#### 2. API 버전 및 경로 스타일
```bash
# API 버전
# s3v2: AWS Signature Version 2 (레거시)
# s3v4: AWS Signature Version 4 (현재 표준)

# 경로 스타일
# dns: https://bucket-name.s3.amazonaws.com/object-key (가상 호스트 스타일)
# path: https://s3.amazonaws.com/bucket-name/object-key (경로 스타일)
# auto: 자동 감지
```

## 🔍 핵심 개념 3: 포트 포워딩을 통한 서비스 접근

### Kubernetes 서비스 접근 방법들

#### 1. ClusterIP (기본값)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio
spec:
  type: ClusterIP  # 클러스터 내부에서만 접근 가능
  selector:
    app: minio
  ports:
  - port: 80
    targetPort: 9000
```

**특징:**
- ✅ **보안**: 클러스터 외부에서 직접 접근 불가
- ❌ **접근성**: 외부에서 테스트/관리 어려움

#### 2. NodePort
```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio-nodeport
spec:
  type: NodePort
  selector:
    app: minio
  ports:
  - port: 80
    targetPort: 9000
    nodePort: 30900  # 모든 노드의 30900 포트로 접근 가능
```

**특징:**
- ✅ **외부 접근**: 노드 IP:30900으로 접근 가능
- ❌ **포트 제한**: 30000-32767 범위만 사용 가능
- ❌ **보안 위험**: 모든 노드에 포트 노출

#### 3. LoadBalancer
```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio-lb
spec:
  type: LoadBalancer
  selector:
    app: minio
  ports:
  - port: 9000
    targetPort: 9000
```

**특징:**
- ✅ **편리함**: 클라우드 로드밸런서 자동 생성
- ❌ **비용**: 클라우드 로드밸런서 비용 발생
- ❌ **환경 제약**: 클라우드 환경에서만 동작

#### 4. 포트 포워딩 (개발/테스트용)
```bash
kubectl port-forward svc/minio -n minio-tenant 9000:80
```

**특징:**
- ✅ **보안**: 로컬에서만 접근 가능
- ✅ **비용 없음**: 추가 리소스 불필요
- ✅ **유연성**: 임시 접근에 최적
- ❌ **일시적**: 프로세스 종료 시 연결 끊김

### 포트 포워딩 동작 원리

#### 1. 연결 흐름
```
로컬 애플리케이션 → localhost:9000 → kubectl → K8s API Server → kube-proxy → Service → Pod
```

#### 2. 실제 네트워크 경로
```bash
# 포트 포워딩 시작
$ kubectl port-forward svc/minio -n minio-tenant 9000:80 &
Forwarding from 127.0.0.1:9000 -> 80
Forwarding from [::1]:9000 -> 80

# 연결 테스트
$ curl http://localhost:9000/minio/health/live
{"status":"ok"}

# 실제 연결 경로 확인
$ netstat -tlnp | grep 9000
tcp        0      0 127.0.0.1:9000          0.0.0.0:*               LISTEN      12345/kubectl
```

#### 3. 다중 포트 포워딩
```bash
# MinIO API와 Console 동시 포워딩
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &

# 프로세스 확인
$ ps aux | grep "kubectl port-forward"
user  12345  kubectl port-forward svc/minio -n minio-tenant 9000:80
user  12346  kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090
```

## 🔍 핵심 개념 4: 데이터 무결성 검증

### 데이터 무결성이란?
데이터가 전송, 저장, 처리 과정에서 손상되지 않고 원본과 동일하게 유지되는 것을 의미합니다.

#### 1. 체크섬 기반 검증
```bash
# 원본 파일 체크섬 계산
$ echo "Hello MinIO" > test.txt
$ md5sum test.txt
5d41402abc4b2a76b9719d911017c592  test.txt

# MinIO 업로드 후 다운로드
$ mc cp test.txt local/test-bucket/
$ mc cp local/test-bucket/test.txt downloaded.txt

# 다운로드 파일 체크섬 확인
$ md5sum downloaded.txt
5d41402abc4b2a76b9719d911017c592  downloaded.txt

# 체크섬 비교
$ md5sum test.txt downloaded.txt
5d41402abc4b2a76b9719d911017c592  test.txt
5d41402abc4b2a76b9719d911017c592  downloaded.txt
```

#### 2. 바이트 단위 비교
```bash
# diff 명령어로 바이트 단위 비교
$ diff test.txt downloaded.txt
# 출력 없음 = 파일이 동일함

# cmp 명령어로 바이너리 비교
$ cmp test.txt downloaded.txt
# 출력 없음 = 파일이 동일함

# 파일 크기 비교
$ ls -l test.txt downloaded.txt
-rw-r--r-- 1 user user 11 Jan  1 12:00 test.txt
-rw-r--r-- 1 user user 11 Jan  1 12:00 downloaded.txt
```

### MinIO의 데이터 무결성 보장

#### 1. 업로드 시 체크섬 계산
```bash
# mc 클라이언트가 자동으로 체크섬 계산 및 전송
$ mc cp --debug test.txt local/test-bucket/ 2>&1 | grep -i checksum
# MinIO 서버가 체크섬 검증 후 저장
```

#### 2. Erasure Coding을 통한 데이터 보호
```bash
# MinIO 서버 로그에서 EC 정보 확인
$ kubectl logs -n minio-tenant minio-tenant-pool-0-0 -c minio | grep -i "erasure\|checksum"
```

#### 3. 비트 부패(Bit Rot) 감지
```bash
# MinIO의 자동 힐링 기능
$ mc admin heal local --recursive

# 데이터 무결성 스캔
$ mc admin heal local/test-bucket --scan deep
```

## 🔍 핵심 개념 5: 실제 파일시스템에서 데이터 확인

### MinIO 데이터 저장 구조

#### 1. 디렉토리 구조
```bash
# PV 경로 확인
$ kubectl get pv -o custom-columns=PATH:.spec.local.path
PATH
/opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012
/opt/local-path-provisioner/pvc-87654321-4321-4321-4321-210987654321

# 실제 디렉토리 구조 (노드에서 확인)
$ ls -la /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012/
total 16
drwxrwxrwx 4 root root 4096 Jan  1 12:00 .
drwxr-xr-x 6 root root 4096 Jan  1 12:00 ..
drwxr-xr-x 6 root root 4096 Jan  1 12:00 .minio.sys
drwxr-xr-x 3 root root 4096 Jan  1 12:00 test-bucket
```

#### 2. MinIO 시스템 파일들
```bash
# .minio.sys 디렉토리 내용
$ ls -la /opt/local-path-provisioner/pvc-*/\.minio.sys/
total 32
drwxr-xr-x 6 root root 4096 Jan  1 12:00 .
drwxrwxrwx 4 root root 4096 Jan  1 12:00 ..
drwxr-xr-x 2 root root 4096 Jan  1 12:00 buckets
drwxr-xr-x 2 root root 4096 Jan  1 12:00 config
-rw-r--r-- 1 root root  156 Jan  1 12:00 format.json
drwxr-xr-x 2 root root 4096 Jan  1 12:00 pool.bin
drwxr-xr-x 2 root root 4096 Jan  1 12:00 tmp
```

**주요 파일 설명:**
- **format.json**: 드라이브 포맷 정보 및 Erasure Coding 설정
- **pool.bin**: 스토리지 풀 정보
- **buckets/**: 버킷 메타데이터
- **config/**: 서버 설정 정보
- **tmp/**: 임시 파일들

#### 3. 객체 데이터 구조
```bash
# 버킷 내 객체 구조
$ ls -la /opt/local-path-provisioner/pvc-*/test-bucket/
total 12
drwxr-xr-x 3 root root 4096 Jan  1 12:00 .
drwxrwxrwx 4 root root 4096 Jan  1 12:00 ..
drwxr-xr-x 2 root root 4096 Jan  1 12:00 test.txt

# 객체별 상세 구조
$ ls -la /opt/local-path-provisioner/pvc-*/test-bucket/test.txt/
total 16
drwxr-xr-x 2 root root 4096 Jan  1 12:00 .
drwxr-xr-x 3 root root 4096 Jan  1 12:00 ..
-rw-r--r-- 1 root root   11 Jan  1 12:00 part.1
-rw-r--r-- 1 root root  156 Jan  1 12:00 xl.meta
```

**파일 설명:**
- **part.1**: 실제 객체 데이터 (Erasure Coding 적용 시 분할됨)
- **xl.meta**: 객체 메타데이터 (크기, 체크섬, 타임스탬프, 사용자 메타데이터 등)

#### 4. xl.meta 파일 분석
```bash
# xl.meta 파일 내용 확인 (바이너리 파일이므로 hexdump 사용)
$ hexdump -C /opt/local-path-provisioner/pvc-*/test-bucket/test.txt/xl.meta | head -10

# 또는 strings 명령어로 텍스트 부분만 추출
$ strings /opt/local-path-provisioner/pvc-*/test-bucket/test.txt/xl.meta
XL2 
test.txt
application/octet-stream
2024-01-01T12:00:00.000Z
```

### 데이터 분산 저장 확인

#### 1. 다중 볼륨 환경에서의 분산
```bash
# volumesPerServer: 2인 경우 두 PV에 데이터 분산
$ find /opt/local-path-provisioner/pvc-*/test-bucket -name "xl.meta" -exec ls -l {} \;
-rw-r--r-- 1 root root 156 Jan  1 12:00 /opt/local-path-provisioner/pvc-12345678.../test-bucket/test.txt/xl.meta
-rw-r--r-- 1 root root 156 Jan  1 12:00 /opt/local-path-provisioner/pvc-87654321.../test-bucket/test.txt/xl.meta

# 각 볼륨의 part 파일 확인
$ find /opt/local-path-provisioner/pvc-*/test-bucket -name "part.*" -exec ls -l {} \;
-rw-r--r-- 1 root root 6 Jan  1 12:00 /opt/local-path-provisioner/pvc-12345678.../test-bucket/test.txt/part.1
-rw-r--r-- 1 root root 5 Jan  1 12:00 /opt/local-path-provisioner/pvc-87654321.../test-bucket/test.txt/part.1
```

#### 2. Erasure Coding 데이터 확인
```bash
# 원본 데이터와 저장된 데이터 비교
$ echo "Hello MinIO" | wc -c
11

# 각 part 파일 크기 확인 (EC로 분할됨)
$ wc -c /opt/local-path-provisioner/pvc-*/test-bucket/test.txt/part.1
6 /opt/local-path-provisioner/pvc-12345678.../test-bucket/test.txt/part.1
5 /opt/local-path-provisioner/pvc-87654321.../test-bucket/test.txt/part.1
```

## 🔍 핵심 개념 6: MinIO 웹 콘솔

### 웹 콘솔 기능

#### 1. 버킷 관리
- **버킷 생성/삭제**: GUI를 통한 직관적인 버킷 관리
- **버킷 정책**: 공개/비공개 설정, 세밀한 권한 제어
- **버킷 알림**: 이벤트 기반 알림 설정
- **버킷 복제**: 다른 MinIO 인스턴스로 데이터 복제

#### 2. 객체 관리
- **파일 업로드/다운로드**: 드래그 앤 드롭 지원
- **폴더 구조**: 가상 폴더 생성 및 관리
- **객체 메타데이터**: 사용자 정의 메타데이터 편집
- **객체 미리보기**: 이미지, 텍스트 파일 미리보기

#### 3. 사용자 관리
- **IAM 사용자**: 사용자 생성, 수정, 삭제
- **그룹 관리**: 사용자 그룹 생성 및 관리
- **정책 관리**: JSON 기반 정책 생성 및 할당
- **액세스 키**: 프로그래밍 접근용 키 관리

#### 4. 모니터링
- **서버 상태**: CPU, 메모리, 디스크 사용량
- **네트워크 통계**: 업로드/다운로드 통계
- **로그 뷰어**: 실시간 로그 모니터링
- **메트릭**: Prometheus 메트릭 시각화

### 웹 콘솔 접근 설정

#### 1. 서비스 구조
```yaml
# MinIO Console 서비스
apiVersion: v1
kind: Service
metadata:
  name: minio-tenant-console
spec:
  selector:
    v1.min.io/tenant: minio-tenant
  ports:
  - name: https-console
    port: 9090
    targetPort: 9090
```

#### 2. 포트 포워딩 설정
```bash
# Console 포트 포워딩
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090

# 브라우저에서 접근
# URL: http://localhost:9001
# Username: minio
# Password: minio123
```

## 🎯 실습에서 확인할 수 있는 것들

### 1. S3 API 호환성 테스트
```bash
# AWS CLI로도 접근 가능 (S3 호환성 확인)
aws configure set aws_access_key_id minio
aws configure set aws_secret_access_key minio123
aws configure set default.region us-east-1

# S3 명령어 사용
aws --endpoint-url http://localhost:9000 s3 ls
aws --endpoint-url http://localhost:9000 s3 mb s3://aws-test-bucket
aws --endpoint-url http://localhost:9000 s3 cp test.txt s3://aws-test-bucket/
```

### 2. 데이터 무결성 검증
```bash
# 대용량 파일로 무결성 테스트
dd if=/dev/zero of=large-test.dat bs=1M count=10
md5sum large-test.dat > original.md5

mc cp large-test.dat local/test-bucket/
mc cp local/test-bucket/large-test.dat downloaded-large.dat
md5sum downloaded-large.dat > downloaded.md5

diff original.md5 downloaded.md5
```

### 3. 실제 스토리지 경로 탐색
```bash
# 업로드 전후 디렉토리 구조 비교
find /opt/local-path-provisioner/pvc-* -type f -name "*.meta" | wc -l

# 새 파일 업로드 후
mc cp new-file.txt local/test-bucket/
find /opt/local-path-provisioner/pvc-* -type f -name "*.meta" | wc -l
```

## 🚨 일반적인 문제와 해결 방법

### 1. 포트 포워딩 연결 실패
**원인:** 서비스나 Pod가 준비되지 않음
```bash
# 서비스 상태 확인
kubectl get svc -n minio-tenant

# Pod 상태 확인
kubectl get pods -n minio-tenant

# 포트 포워딩 재시작
pkill -f "kubectl port-forward.*minio"
kubectl port-forward svc/minio -n minio-tenant 9000:80 &
```

### 2. mc 명령어 인식 안됨
**원인:** PATH에 mc가 없음
```bash
# mc 위치 확인
which mc

# PATH에 추가 또는 절대 경로 사용
export PATH=$PATH:/usr/local/bin
# 또는
./mc ls local/
```

### 3. 웹 콘솔 접근 불가
**원인:** Console 서비스 포트 포워딩 미설정
```bash
# Console 서비스 확인
kubectl get svc minio-tenant-console -n minio-tenant

# Console 포트 포워딩 설정
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &
```

## 📖 추가 학습 자료

### 공식 문서
- [MinIO Client Documentation](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [S3 API Compatibility](https://min.io/docs/minio/linux/developers/s3-compatible-api.html)
- [MinIO Console](https://min.io/docs/minio/kubernetes/upstream/operations/install-deploy-manage/deploy-operator-console.html)

### 실습 명령어
```bash
# Client 설정 및 기본 사용법 실행
./lab-03-client-setup.sh

# 상세 디버그 모드로 mc 실행
mc --debug cp test.txt local/test-bucket/

# 실제 스토리지 경로 탐색
find /opt/local-path-provisioner -name "*.meta" -exec ls -l {} \;
```

이 개념들을 이해하면 MinIO의 S3 호환 API를 완전히 활용하고, 실제 데이터가 어떻게 저장되고 관리되는지 완전히 이해할 수 있습니다.
