# Lab 3: MinIO Client 및 기본 사용법 - 단계별 실습 가이드

## 📚 개요

이 실습에서는 MinIO Client (mc)를 설치하고 S3 호환 API를 통해 실제 객체 스토리지 작업을 수행합니다. 업로드된 데이터의 실제 저장 위치를 확인하여 MinIO의 데이터 구조를 이해합니다.

## 🎯 학습 목표

- MinIO Client (mc) 설치 및 설정
- S3 호환 API 사용법 학습
- 버킷 및 객체 기본 관리
- 데이터 무결성 검증
- 실제 스토리지 경로에서 데이터 확인
- MinIO 데이터 구조 이해

## ⏱️ 예상 소요시간
10-15분

## 🔧 사전 준비사항

- Lab 2 완료 (MinIO Tenant 배포)
- MinIO 서비스 포트 포워딩 설정
- 터미널 접근 권한

---

## Step 1: 사전 요구사항 확인

### 💡 개념 설명
MinIO Client 사용 전 MinIO 서버 상태와 접근성을 확인합니다.

### 🔍 MinIO Tenant 상태 확인
```bash
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
```

### ✅ 예상 출력
```
NAME           STATE         AGE
minio-tenant   Initialized   10m

NAME                       READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0      1/1     Running   0          10m
```

### 🔍 포트 포워딩 확인
```bash
# 포트 포워딩이 실행 중인지 확인
ps aux | grep "kubectl port-forward"
```

### 🔍 포트 포워딩 설정 (필요한 경우)
```bash
kubectl port-forward -n minio-tenant svc/minio-tenant-hl 9000:9000 &
```

### 🔍 MinIO API 연결 테스트
```bash
curl -I http://localhost:9000/minio/health/live
```

### ✅ 예상 출력
```
HTTP/1.1 200 OK
Server: MinIO
```

### 🛑 체크포인트
MinIO 서버가 정상 실행 중이고 API 접근이 가능한지 확인하세요.

---

## Step 2: MinIO Client (mc) 설치

### 💡 개념 설명
MinIO Client (mc)는 MinIO 서버와 상호작용하기 위한 명령줄 도구입니다:

**주요 기능**:
- **버킷 관리**: 생성, 삭제, 목록 조회
- **객체 관리**: 업로드, 다운로드, 복사, 삭제
- **정책 관리**: 접근 권한 설정
- **사용자 관리**: IAM 사용자 및 그룹 관리

### 🔍 mc 설치 (Linux)
```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# PATH에 영구 추가
echo 'export PATH=$PATH:$HOME/minio-binaries/' >> ~/.bashrc
source ~/.bashrc
```

### 🔍 설치 확인
```bash
mc --version
```

### ✅ 예상 출력
```
mc version RELEASE.2023-08-08T17-01-06Z (commit-id=1234567890abcdef)
Runtime: go1.20.6 linux/amd64
Copyright (c) 2015-2023 MinIO, Inc.
License GNU AGPLv3 <https://www.gnu.org/licenses/agpl-3.0.html>
```

### 🛑 체크포인트
mc 명령어가 정상적으로 설치되고 버전 정보가 출력되는지 확인하세요.

---

## Step 3: MinIO 서버 연결 설정

### 💡 개념 설명
mc는 alias를 통해 여러 MinIO 서버를 관리할 수 있습니다.

### 🔍 MinIO 서버 alias 추가
```bash
mc alias set local http://localhost:9000 admin password123
```

### ✅ 예상 출력
```
Added `local` successfully.
```

### 🔍 연결 테스트
```bash
mc admin info local
```

### ✅ 예상 출력
```
●  localhost:9000
   Uptime: 15 minutes 
   Version: 2023-08-04T17:40:21Z
   Network: 1/1 OK 
   Drives: 4/4 OK 
   Pool: 1

Drives:
 1: http://localhost:9000/export/data1 - OK 
 2: http://localhost:9000/export/data2 - OK 
 3: http://localhost:9000/export/data3 - OK 
 4: http://localhost:9000/export/data4 - OK 
```

### 📚 출력 정보 해석
- **Network**: 1/1 OK (네트워크 연결 정상)
- **Drives**: 4/4 OK (4개 드라이브 모두 정상)
- **Pool**: 1 (단일 풀 구성)

### 🛑 체크포인트
MinIO 서버 연결이 성공하고 모든 드라이브가 정상 상태인지 확인하세요.

---

## Step 4: 버킷 생성 및 관리

### 💡 개념 설명
버킷은 S3에서 객체를 저장하는 최상위 컨테이너입니다.

### 🔍 버킷 생성
```bash
mc mb local/test-bucket
```

### ✅ 예상 출력
```
Bucket created successfully `local/test-bucket`.
```

### 🔍 버킷 목록 확인
```bash
mc ls local
```

### ✅ 예상 출력
```
[2023-08-10 10:45:00 UTC]     0B test-bucket/
```

### 🔍 버킷 상세 정보
```bash
mc stat local/test-bucket
```

### ✅ 예상 출력
```
Name      : test-bucket/
Date      : 2023-08-10 10:45:00 UTC
Size      : 0B
Type      : folder
```

### 🛑 체크포인트
test-bucket이 성공적으로 생성되었는지 확인하세요.

---

## Step 5: 객체 업로드 및 다운로드

### 💡 개념 설명
실제 파일을 업로드하여 MinIO의 객체 스토리지 기능을 테스트합니다.

### 🔍 테스트 파일 생성
```bash
echo "Hello MinIO World!" > test-file.txt
echo "This is a test file for MinIO lab" >> test-file.txt
date >> test-file.txt
```

### 🔍 파일 업로드
```bash
mc cp test-file.txt local/test-bucket/
```

### ✅ 예상 출력
```
...file.txt: 58 B / 58 B ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100.00% 1.45 KiB/s 0s
```

### 🔍 객체 목록 확인
```bash
mc ls local/test-bucket/
```

### ✅ 예상 출력
```
[2023-08-10 10:46:00 UTC]    58B STANDARD test-file.txt
```

### 🔍 객체 다운로드 테스트
```bash
mc cp local/test-bucket/test-file.txt downloaded-file.txt
cat downloaded-file.txt
```

### ✅ 예상 출력
```
Hello MinIO World!
This is a test file for MinIO lab
Thu Aug 10 10:46:00 UTC 2023
```

### 🛑 체크포인트
파일 업로드와 다운로드가 정상적으로 작동하는지 확인하세요.

---

## Step 6: 실제 데이터 저장 위치 확인

### 💡 개념 설명
업로드된 데이터가 실제로 어디에 저장되는지 확인하여 MinIO의 데이터 구조를 이해합니다.

### 🔍 Pod 내부 데이터 구조 확인
```bash
kubectl exec -n minio-tenant minio-tenant-pool-0-0 -- find /export -name "*test-file*" -type f
```

### ✅ 예상 출력
```
/export/data1/.minio.sys/buckets/test-bucket/test-file.txt/xl.meta
/export/data2/.minio.sys/buckets/test-bucket/test-file.txt/xl.meta
/export/data3/test-bucket/test-file.txt/part.1
/export/data4/test-bucket/test-file.txt/part.1
```

### 📚 데이터 구조 해석
- **xl.meta**: 메타데이터 파일 (Erasure Coding 정보)
- **part.1**: 실제 데이터 조각
- **분산 저장**: 데이터가 여러 드라이브에 분산됨

### 🔍 메타데이터 확인
```bash
kubectl exec -n minio-tenant minio-tenant-pool-0-0 -- cat /export/data1/.minio.sys/buckets/test-bucket/test-file.txt/xl.meta
```

### 🔍 실제 데이터 확인
```bash
kubectl exec -n minio-tenant minio-tenant-pool-0-0 -- cat /export/data3/test-bucket/test-file.txt/part.1
```

### 🛑 체크포인트
업로드된 데이터가 Erasure Coding에 따라 분산 저장되었는지 확인하세요.

---

## 🎯 학습 성과 확인

### ✅ 완료 체크리스트

- [ ] MinIO Client (mc) 설치 완료
- [ ] MinIO 서버 연결 설정 완료
- [ ] 버킷 생성 및 관리 성공
- [ ] 파일 업로드/다운로드 테스트 완료
- [ ] 데이터 무결성 검증 완료
- [ ] 실제 저장 위치 확인 완료
- [ ] MinIO 데이터 구조 이해 완료

### 🧠 핵심 개념 이해도 점검

1. **S3 호환 API의 기본 개념을 이해했나요?**
2. **Erasure Coding이 데이터를 어떻게 분산 저장하는지 알고 있나요?**
3. **메타데이터와 실제 데이터가 어떻게 분리되어 저장되는지 이해했나요?**

---

## 🚀 다음 단계

MinIO Client 설정과 기본 사용법을 완료했습니다!

**Lab 4: S3 API 고급 기능**에서 학습할 내용:
- Multipart Upload 테스트
- 메타데이터 관리
- 스토리지 클래스 활용

### 🔗 관련 문서
- [Lab 4 가이드: S3 API 고급 기능](LAB-04-GUIDE.md)
- [MinIO Client 상세 개념](LAB-03-CONCEPTS.md)

---

축하합니다! MinIO의 기본 사용법을 성공적으로 학습했습니다.
