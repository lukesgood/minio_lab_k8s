# Lab 2: MinIO Tenant 배포 - Lab Guide

## 📚 개요

이 실습에서는 MinIO Operator를 사용하여 실제 MinIO Tenant를 배포합니다. **환경에 따른 최적화된 스토리지 클래스를 선택**하고, 동적 프로비저닝 과정을 실시간으로 관찰하며, MinIO의 권장사항을 준수한 배포를 경험합니다.

## 🎯 학습 목표

- MinIO Tenant 개념과 역할 이해
- **환경별 스토리지 클래스 선택 및 최적화**
- **MinIO 권장 로컬 연결 스토리지 구성**
- 실시간 동적 프로비저닝 과정 관찰
- StatefulSet과 PVC의 관계 학습
- WaitForFirstConsumer 동작 원리 체험
- Erasure Coding 설정 및 검증

## ⏱️ 예상 소요시간
20-30분 (환경 설정 포함)

## 🔧 사전 준비사항

- Lab 1 완료 (MinIO Operator 설치)
- kubectl 명령어 도구
- 충분한 클러스터 리소스 (최소 2GB RAM, 2 CPU)

---

## Step 1: 환경 확인 및 스토리지 전략 결정

### 💡 개념 설명

MinIO는 **워커 노드의 로컬 연결 스토리지 사용을 강력히 권장**합니다. 환경에 따라 적절한 스토리지 전략을 선택해야 합니다.

**MinIO 권장사항**:
- ✅ **로컬 연결 스토리지** (Locally Attached Storage)
- ✅ **워커 노드 전용 배포** (Control Plane 제외)
- ✅ **직접 디스크 액세스** (네트워크 스토리지 회피)
- ✅ **노드별 분산 배치** (고가용성)

### 🔍 현재 환경 확인

```bash
echo "=== 클러스터 환경 분석 ==="

# 1. 노드 구성 확인
echo "1. 노드 구성:"
kubectl get nodes -o wide

# 2. 워커 노드 수 계산
WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)
echo -e "\n워커 노드 수: $WORKER_COUNT"

# 3. 현재 스토리지 클래스 확인
echo -e "\n2. 현재 스토리지 클래스:"
kubectl get storageclass

# 4. MinIO Operator 상태 확인
echo -e "\n3. MinIO Operator 상태:"
kubectl get pods -n minio-operator
```

### 📋 환경별 스토리지 전략

| 환경 | 워커 노드 수 | 권장 스토리지 | MinIO 권장도 | 특징 |
|------|-------------|---------------|-------------|------|
| **개발/테스트** | 0-1 | local-path | ⭐⭐⭐ | 간단, 빠른 설정 |
| **프로덕션** | 2+ | minio-local-storage | ⭐⭐⭐⭐⭐ | **MinIO 공식 권장** |
| **클라우드** | 2+ | ebs/pd-ssd | ⭐⭐⭐⭐ | 관리형 스토리지 |
| **엔터프라이즈** | 3+ | longhorn/rook-ceph | ⭐⭐⭐ | 고가용성 |

### 🛑 체크포인트
환경 분석 결과를 확인하고 적절한 스토리지 전략을 선택하세요.

---

## Step 2: 환경별 스토리지 클래스 설정

### 💡 개념 설명

환경 분석 결과에 따라 최적화된 스토리지 클래스를 설정합니다.

### 🔧 Option A: 단일 노드 환경 (개발/테스트)

**적용 조건**: 워커 노드 0-1개

```bash
echo "=== 단일 노드 환경 설정 ==="

# Local Path Provisioner 설치 (없는 경우)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# 기본 스토리지 클래스로 설정
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 설정 확인
kubectl get storageclass
```

### 🏢 Option B: 다중 노드 환경 (MinIO 권장 로컬 스토리지)

**적용 조건**: 워커 노드 2개 이상, **MinIO 공식 권장**

#### B-1: MinIO 최적화 스토리지 클래스 생성

```bash
echo "=== MinIO 권장 로컬 스토리지 설정 ==="

# MinIO 최적화 스토리지 클래스 생성
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    minio.min.io/optimized: "true"
    minio.min.io/storage-type: "local-attached"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: false
parameters:
  fsType: "ext4"
EOF
```

#### B-2: 워커 노드별 로컬 PV 생성

```bash
# 워커 노드 목록 가져오기
WORKER_NODES=($(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=":metadata.name"))

echo "워커 노드: ${WORKER_NODES[@]}"

# 각 워커 노드에 스토리지 디렉토리 생성
for node in "${WORKER_NODES[@]}"; do
    echo "노드 $node에 스토리지 디렉토리 생성..."
    
    # Multipass 환경인 경우
    if multipass list | grep -q "$node"; then
        multipass exec "$node" -- sudo mkdir -p /mnt/minio-data/disk1 /mnt/minio-data/disk2
        multipass exec "$node" -- sudo chown -R 1000:1000 /mnt/minio-data/
    else
        # 일반 환경인 경우 (SSH 접근 필요)
        echo "노드 $node에 직접 접근하여 다음 명령어를 실행하세요:"
        echo "sudo mkdir -p /mnt/minio-data/disk1 /mnt/minio-data/disk2"
        echo "sudo chown -R 1000:1000 /mnt/minio-data/"
    fi
done

# Local PV 생성
for i in "${!WORKER_NODES[@]}"; do
    node="${WORKER_NODES[$i]}"
    
    # 각 노드에 2개의 PV 생성
    for disk in 1 2; do
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-local-pv-${node}-${disk}
  labels:
    minio.min.io/node: "${node}"
    minio.min.io/disk: "disk${disk}"
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: minio-local-storage
  local:
    path: /mnt/minio-data/disk${disk}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${node}
EOF
    done
done

echo "Local PV 생성 완료"
```

### 🌐 Option C: 분산 스토리지 환경

**적용 조건**: 고가용성이 필요한 환경

```bash
echo "=== 분산 스토리지 설정 (Longhorn 예시) ==="

# Longhorn 설치
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# 설치 완료 대기
echo "Longhorn 설치 중... (2-3분 소요)"
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s

# 기본 스토리지 클래스로 설정
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 🔍 스토리지 클래스 설정 확인

```bash
echo "=== 스토리지 클래스 설정 확인 ==="

# 스토리지 클래스 확인
kubectl get storageclass

# PV 확인 (Local Storage인 경우)
kubectl get pv

echo "스토리지 클래스 설정 완료!"
```

### 🛑 체크포인트
선택한 환경에 맞는 스토리지 클래스가 설정되고 기본 클래스로 지정되었는지 확인하세요.

---

## Step 3: MinIO Tenant 네임스페이스 및 인증 설정

### 💡 개념 설명

MinIO Tenant를 위한 전용 네임스페이스를 생성하고 인증 정보를 설정합니다.

### 🔍 네임스페이스 생성

```bash
kubectl create namespace minio-tenant
```

### 🔑 인증 시크릿 생성

```bash
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant
```

### 🔍 설정 확인

```bash
echo "=== 네임스페이스 및 시크릿 확인 ==="
kubectl get namespace minio-tenant
kubectl get secret minio-creds-secret -n minio-tenant
```

### 🛑 체크포인트
minio-tenant 네임스페이스와 인증 시크릿이 생성되었는지 확인하세요.

---

## Step 4: 환경별 MinIO Tenant YAML 생성

### 💡 개념 설명

환경에 맞는 최적화된 MinIO Tenant 설정을 생성합니다.

### 🔧 환경별 Tenant 설정

#### A. 단일 노드 환경용 Tenant

```bash
cat << EOF > minio-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
  labels:
    app: minio
    environment: development
spec:
  configuration:
    name: minio-creds-secret
  
  features:
    bucketDNS: false
    domains: {}
  
  users:
    - name: storage-user
  
  podManagementPolicy: Parallel
  
  ## 단일 노드 최적화 설정
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 4
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
    
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
  
  mountPath: /export
  subPath: /data
  requestAutoCert: false
EOF
```

#### B. 다중 노드 환경용 Tenant (MinIO 권장)

```bash
# 워커 노드 수 확인
WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)

cat << EOF > minio-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
  labels:
    app: minio
    environment: production
    storage-type: local-attached
  annotations:
    minio.min.io/storage-type: "locally-attached"
    minio.min.io/deployment-type: "distributed"
spec:
  configuration:
    name: minio-creds-secret
  
  features:
    bucketDNS: false
    domains: {}
  
  users:
    - name: storage-user
  
  podManagementPolicy: Parallel
  
  ## MinIO 권장: 다중 노드 분산 배포
  pools:
  - name: pool-0
    servers: ${WORKER_COUNT}
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
        labels:
          minio.min.io/storage-type: "local-attached"
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
        storageClassName: minio-local-storage
    
    ## 워커 노드에만 배포
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node-role.kubernetes.io/control-plane
              operator: DoesNotExist
      ## 노드별 분산 배치
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: v1.min.io/tenant
              operator: In
              values:
              - minio-tenant
          topologyKey: kubernetes.io/hostname
    
    resources:
      requests:
        memory: 4Gi
        cpu: 2000m
      limits:
        memory: 8Gi
        cpu: 4000m
    
    ## 로컬 스토리지 최적화 환경 변수
    env:
    - name: MINIO_STORAGE_CLASS_STANDARD
      value: "EC:2"
    - name: MINIO_API_REQUESTS_MAX
      value: "1600"
  
  mountPath: /export
  subPath: /data
  requestAutoCert: false
EOF
```

### 🔍 생성된 YAML 확인

```bash
echo "=== 생성된 MinIO Tenant 설정 ==="
cat minio-tenant.yaml
```

### 🛑 체크포인트
환경에 맞는 MinIO Tenant YAML 파일이 생성되었는지 확인하세요.

---

## Step 5: 동적 프로비저닝 관찰 준비

### 💡 개념 설명

Tenant 배포 전에 현재 상태를 확인하여 동적 프로비저닝 과정을 관찰할 준비를 합니다.

### 🔍 배포 전 상태 확인

```bash
echo "=== 배포 전 상태 확인 ==="

echo "1. 현재 PV 상태:"
kubectl get pv

echo -e "\n2. 현재 PVC 상태:"
kubectl get pvc -n minio-tenant

echo -e "\n3. 현재 Pod 상태:"
kubectl get pods -n minio-tenant
```

### 📊 실시간 모니터링 설정

별도 터미널에서 실시간 모니터링을 위해 다음 명령어를 실행하세요:

**터미널 1 (PV 모니터링)**:
```bash
watch -n 2 'kubectl get pv'
```

**터미널 2 (PVC 모니터링)**:
```bash
watch -n 2 'kubectl get pvc -n minio-tenant'
```

**터미널 3 (Pod 모니터링)**:
```bash
watch -n 2 'kubectl get pods -n minio-tenant -o wide'
```

### 🛑 체크포인트
모니터링 창이 준비되고 현재 상태가 확인되었는지 점검하세요.

---

## Step 6: MinIO Tenant 배포 및 실시간 관찰

### 💡 개념 설명

이제 실제 Tenant를 배포하면서 동적 프로비저닝 과정을 실시간으로 관찰합니다.

**예상 진행 순서**:
1. **Tenant 생성**: CRD 리소스 생성
2. **PVC 생성**: 환경에 따른 PVC 생성 (Pending 상태)
3. **StatefulSet 생성**: MinIO Pod 정의
4. **Pod 스케줄링**: Pod가 노드에 배치 결정
5. **PV 바인딩**: PVC와 PV 연결 (Local Storage) 또는 PV 자동 생성
6. **Pod 시작**: 볼륨 마운트 후 MinIO 시작

### 🚀 Tenant 배포 실행

```bash
echo "=== MinIO Tenant 배포 시작 ==="
kubectl apply -f minio-tenant.yaml
```

### 📊 단계별 상태 관찰

#### 1단계: PVC 생성 확인 (즉시)
```bash
kubectl get pvc -n minio-tenant
```

**예상 출력**:
```
NAME                         STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-tenant-pool-0-0   Pending   -        -          -              minio-local-storage     5s
data-minio-tenant-pool-0-1   Pending   -        -          -              minio-local-storage     5s
...
```

#### 2단계: StatefulSet 및 Pod 생성 확인
```bash
kubectl get statefulset -n minio-tenant
kubectl get pods -n minio-tenant
```

#### 3단계: PV 바인딩 관찰
```bash
kubectl get pv
kubectl get pvc -n minio-tenant
```

#### 4단계: Pod 실행 확인
```bash
kubectl get pods -n minio-tenant -o wide
```

### 🛑 체크포인트
모든 PVC가 "Bound" 상태이고 MinIO Pod가 "Running" 상태인지 확인하세요.

---

## Step 7: 배포 검증 및 서비스 접근

### 💡 개념 설명

배포된 MinIO Tenant의 상태를 종합적으로 확인하고 서비스에 접근합니다.

### 🔍 종합 상태 확인

```bash
echo "=== MinIO Tenant 배포 상태 확인 ==="

echo "1. Tenant 리소스:"
kubectl get tenant -n minio-tenant

echo -e "\n2. StatefulSet:"
kubectl get statefulset -n minio-tenant

echo -e "\n3. Pod 상태:"
kubectl get pods -n minio-tenant -o wide

echo -e "\n4. PVC 상태:"
kubectl get pvc -n minio-tenant

echo -e "\n5. 서비스:"
kubectl get service -n minio-tenant

echo -e "\n6. MinIO 로그 확인:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 --tail=10
```

### 🌐 서비스 접근 설정

```bash
echo "=== 포트 포워딩 설정 ==="

# MinIO API 포트 포워딩
kubectl port-forward -n minio-tenant svc/minio-tenant-hl 9000:9000 &

# MinIO Console 포트 포워딩
kubectl port-forward -n minio-tenant svc/minio-tenant-console 9001:9090 &

echo "포트 포워딩 설정 완료"
echo "MinIO API: http://localhost:9000"
echo "MinIO Console: http://localhost:9001"
echo "사용자명: admin"
echo "패스워드: password123"
```

### 🔍 연결 테스트

```bash
echo "=== MinIO API 연결 테스트 ==="
curl -I http://localhost:9000/minio/health/live
```

### 🛑 체크포인트
MinIO API가 정상 응답하고 웹 콘솔에 접근할 수 있는지 확인하세요.

---

## 🎯 배포 성공 확인 및 학습 성과

### ✅ 성공 기준 체크리스트

**인프라 레벨**:
- [ ] **네임스페이스**: minio-tenant가 Active 상태
- [ ] **시크릿**: minio-creds-secret 생성됨
- [ ] **Tenant**: minio-tenant 리소스가 Initialized 상태
- [ ] **StatefulSet**: 모든 Pod가 Ready 상태
- [ ] **Pod**: 모든 MinIO Pod가 Running 상태

**스토리지 레벨**:
- [ ] **PVC**: 모든 PVC가 Bound 상태
- [ ] **PV**: 모든 PV가 Bound 상태 (또는 자동 생성)
- [ ] **동적 프로비저닝**: WaitForFirstConsumer 모드 정상 동작
- [ ] **실제 경로**: 호스트 파일시스템에 데이터 디렉토리 생성

**애플리케이션 레벨**:
- [ ] **MinIO 로그**: "X Online, 0 Offline" 상태
- [ ] **서비스**: API 및 Console 서비스 생성
- [ ] **포트 포워딩**: 9000, 9001 포트 접근 가능
- [ ] **API 테스트**: Health check 응답 정상
- [ ] **웹 콘솔**: 로그인 및 대시보드 접근 성공

### 🧠 학습 성과 확인

#### 📋 이해도 점검 질문

1. **환경별 스토리지 클래스 선택 기준을 설명할 수 있나요?**
2. **MinIO가 로컬 연결 스토리지를 권장하는 이유를 알고 있나요?**
3. **WaitForFirstConsumer 모드의 동작 원리를 이해했나요?**
4. **다중 노드 환경에서 Anti-Affinity 설정의 중요성을 알고 있나요?**
5. **동적 프로비저닝과 정적 프로비저닝의 차이점을 설명할 수 있나요?**

#### 🎓 핵심 개념 정리

**환경별 최적화**:
- 단일 노드: 개발/테스트 환경, 리소스 효율성
- 다중 노드: 프로덕션 환경, MinIO 권장 로컬 스토리지
- 분산 스토리지: 고가용성, 자동 복제

**MinIO 권장사항**:
- 로컬 연결 스토리지 사용
- 워커 노드 전용 배포
- 노드별 분산 배치
- 직접 디스크 액세스

**동적 프로비저닝**:
- WaitForFirstConsumer 모드
- Pod 스케줄링 시점의 PV 생성/바인딩
- 최적화된 노드 배치

---

## 🚀 다음 단계

MinIO Tenant 배포가 성공적으로 완료되었습니다! 이제 실제 MinIO Client를 설정하고 S3 API를 사용해보겠습니다.

**Lab 3: MinIO Client 및 기본 사용법**에서 학습할 내용:
- MinIO Client (mc) 설치 및 설정
- S3 호환 API를 통한 버킷 및 객체 관리
- 실제 데이터 업로드/다운로드 테스트
- 데이터 무결성 검증 및 실제 저장 위치 확인

### 🧹 정리 명령어 (필요한 경우)

```bash
# Tenant 제거 (다음 Lab 진행 전에는 실행하지 마세요)
kubectl delete tenant minio-tenant -n minio-tenant
kubectl delete namespace minio-tenant

# 포트 포워딩 종료
pkill -f "kubectl port-forward"
```

---

축하합니다! 환경에 최적화된 MinIO Tenant가 성공적으로 배포되었고, MinIO의 권장사항을 준수한 고성능 객체 스토리지 시스템이 구축되었습니다.
