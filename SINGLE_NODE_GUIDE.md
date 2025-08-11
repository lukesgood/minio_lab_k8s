# MinIO Kubernetes Lab - 단일 노드 환경 가이드

## 📋 개요

이 가이드는 **단일 노드 Kubernetes 클러스터** 환경에서 MinIO를 배포하고 운영하는 방법을 다룹니다.

### 환경 요구사항
- 단일 노드 Kubernetes 클러스터 (control-plane)
- kubectl 설치 및 설정 완료
- 최소 4GB RAM, 2 CPU 코어
- 10GB 이상 디스크 여유 공간

## 🚀 빠른 시작

### 1단계: 환경 사전 검증

```bash
# 환경 감지 및 검증
./detect-environment.sh
```

### 2단계: 자동 설치 (권장)

```bash
# 단일 노드 환경 자동 설정
./setup-environment.sh
```

### 3단계: 실습 메뉴 실행

```bash
# 통합 실습 메뉴 (단일 노드 환경 자동 감지)
# Lab Guide를 순서대로 따라하며 실습 진행
docs/LAB-00-GUIDE.md  # 환경 사전 검증부터 시작
```

## 📚 단계별 상세 가이드

### Step 1: 환경 준비

#### 1-1. Control-plane Taint 제거
```bash
# 단일 노드에서 Pod 스케줄링 허용
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

#### 1-2. 스토리지 프로비저너 설치
```bash
# Local Path Provisioner 설치
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# 기본 스토리지 클래스로 설정
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 설치 확인
kubectl get storageclass
```

### Step 2: MinIO Operator 설치

#### 2-1. Operator 설치
```bash
kubectl apply -k "github.com/minio/operator?ref=v5.0.10"
```

#### 2-2. 단일 노드 최적화
```bash
# Operator replica를 1로 조정
kubectl scale deployment minio-operator -n minio-operator --replicas=1

# 상태 확인
kubectl get pods -n minio-operator
```

### Step 3: MinIO Tenant 배포

#### 3-1. 네임스페이스 생성
```bash
kubectl create namespace minio-tenant
```

#### 3-2. 인증 시크릿 생성 (단일 노드용)
```bash
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant
```

#### 3-3. Tenant YAML 생성 (단일 노드용)
```yaml
# single-node-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Gi
        storageClassName: local-path
  mountPath: /export
  configuration:
    name: minio-creds-secret
  requestAutoCert: false
  # 단일 노드 최적화 설정
  podManagementPolicy: Parallel
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

#### 3-4. Tenant 배포
```bash
kubectl apply -f single-node-tenant.yaml

# 배포 상태 확인
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant
```

### Step 4: 서비스 접근

#### 4-1. 서비스 확인
```bash
kubectl get svc -n minio-tenant
```

#### 4-2. MinIO API 접근
```bash
# API 포트 포워딩
kubectl port-forward svc/minio -n minio-tenant 9000:80 &

# 접근 테스트
curl http://localhost:9000/minio/health/live
```

#### 4-3. MinIO Console 접근
```bash
# Console 포트 포워딩
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9001 &

# 웹 브라우저에서 접속
# URL: http://localhost:9001
# 사용자: admin
# 비밀번호: password123
```

## 🔧 단일 노드 환경 특화 설정

### 리소스 최적화

#### CPU/메모리 제한 설정
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

#### 스토리지 최적화
```yaml
# 작은 볼륨 크기 사용
storage: 2Gi  # 단일 노드용

# 로컬 스토리지 클래스 사용
storageClassName: local-path
```

### 고가용성 비활성화

#### Pod Anti-Affinity 제거
```yaml
# 단일 노드에서는 Anti-Affinity 불필요
# affinity 설정 제거 또는 비활성화
```

#### Replica 최소화
```yaml
# Operator replica = 1
# Tenant servers = 1
servers: 1
```

## 🚨 단일 노드 환경 제한사항

### 1. 고가용성 없음
- 노드 장애 시 전체 서비스 중단
- 데이터 복제 없음 (Erasure Coding 제한적)

### 2. 성능 제한
- 단일 노드의 리소스에 의존
- 네트워크 병목 없음 (로컬 통신)

### 3. 확장성 제한
- 수평 확장 불가
- 스토리지 확장 제한적

## 📊 모니터링 (단일 노드용)

### 리소스 모니터링
```bash
# 노드 리소스 사용량
kubectl top node

# Pod 리소스 사용량
kubectl top pods -n minio-tenant

# 스토리지 사용량
kubectl get pvc -n minio-tenant
```

### 로그 모니터링
```bash
# MinIO 로그
kubectl logs -n minio-tenant -l app=minio -f

# Operator 로그
kubectl logs -n minio-operator -l name=minio-operator -f
```

## 🧪 테스트 시나리오

### 1. 기본 기능 테스트
```bash
# MinIO Client 설치
curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
chmod +x mc

# 서버 설정
./mc alias set local http://localhost:9000 admin password123

# 버킷 생성
./mc mb local/test-bucket

# 파일 업로드
echo "Hello MinIO" > test.txt
./mc cp test.txt local/test-bucket/

# 파일 다운로드
./mc cp local/test-bucket/test.txt downloaded.txt
```

### 2. 성능 테스트 (단일 노드용)
```bash
# 소규모 성능 테스트
./mc speed test local --size 10MB --duration 30s
```

## 🔄 업그레이드 및 유지보수

### Tenant 업그레이드
```bash
# 이미지 버전 업데이트
kubectl patch tenant minio-tenant -n minio-tenant --type='merge' -p='{"spec":{"image":"minio/minio:RELEASE.2024-02-01T00-00-00Z"}}'
```

### 백업 및 복구
```bash
# 설정 백업
kubectl get tenant minio-tenant -n minio-tenant -o yaml > tenant-backup.yaml

# PVC 백업 (수동)
kubectl get pvc -n minio-tenant -o yaml > pvc-backup.yaml
```

## 🗑️ 정리

### 전체 정리
```bash
# Tenant 삭제
kubectl delete tenant minio-tenant -n minio-tenant

# 네임스페이스 삭제
kubectl delete namespace minio-tenant

# Operator 삭제
kubectl delete -k "github.com/minio/operator?ref=v5.0.10"

# 스토리지 프로비저너 삭제 (선택사항)
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

## 📝 트러블슈팅

### 일반적인 문제들

#### 1. Pod Pending 상태
```bash
# 원인 확인
kubectl describe pod -n minio-tenant <pod-name>

# 해결책: taint 제거
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

#### 2. PVC Pending 상태
```bash
# 스토리지 클래스 확인
kubectl get storageclass

# Local Path Provisioner 재설치
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

#### 3. 리소스 부족
```bash
# 노드 리소스 확인
kubectl describe node

# 리소스 제한 조정
kubectl patch tenant minio-tenant -n minio-tenant --type='merge' -p='{"spec":{"pools":[{"resources":{"requests":{"memory":"256Mi","cpu":"100m"}}}]}}'
```

---

**참고:** 이 가이드는 학습 및 개발 목적으로 설계되었습니다. 프로덕션 환경에서는 다중 노드 환경을 권장합니다.
