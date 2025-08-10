# Lab 0: 환경 사전 검증 - 핵심 개념 상세 설명

## 📚 개요

Lab 0에서는 MinIO 배포를 위한 Kubernetes 환경의 기본 요소들을 검증하고, 동적 프로비저닝의 핵심 개념들을 학습합니다.

## 🔍 핵심 개념 1: 동적 프로비저닝 vs 정적 프로비저닝

### 정적 프로비저닝 (Static Provisioning)
```
관리자 작업 → 사용자 요청 → 바인딩
     ↓            ↓         ↓
  PV 미리 생성 → PVC 생성 → 기존 PV와 매칭
```

**특징:**
- ✅ **예측 가능한 리소스**: 관리자가 미리 정의한 스토리지만 사용
- ✅ **세밀한 제어**: 각 PV의 속성을 정확히 지정 가능
- ❌ **관리 부담**: 모든 PV를 수동으로 생성/관리
- ❌ **리소스 낭비**: 사용되지 않는 PV가 존재할 수 있음

**예시:**
```yaml
# 관리자가 미리 생성하는 PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv-1
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  local:
    path: /mnt/data/pv1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker-node-1
```

### 동적 프로비저닝 (Dynamic Provisioning)
```
사용자 요청 → 자동 생성 → 바인딩
     ↓           ↓        ↓
  PVC 생성 → 프로비저너가 → PVC와 새 PV
            PV 자동 생성    자동 바인딩
```

**특징:**
- ✅ **자동화**: 필요할 때 자동으로 PV 생성
- ✅ **효율성**: 실제 필요한 만큼만 리소스 사용
- ✅ **확장성**: 무제한 PV 생성 가능
- ✅ **관리 편의성**: 프로비저너가 모든 것을 자동 처리

**구성 요소:**
```yaml
# 스토리지 클래스 (프로비저너 정의)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

## 🔍 핵심 개념 2: WaitForFirstConsumer 메커니즘

### 일반적인 동적 프로비저닝
```
PVC 생성 → 즉시 PV 생성 → 바인딩 완료
```

### WaitForFirstConsumer 방식
```
PVC 생성 → Pending 상태 → Pod 생성 → PV 생성 → 바인딩 완료
```

**WaitForFirstConsumer의 장점:**

#### 1. 최적 노드 선택
```yaml
# Pod가 스케줄링될 노드를 고려하여 PV 생성
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  nodeSelector:
    zone: us-west-1a  # 특정 존에 스케줄링
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-pvc  # 이 PVC의 PV는 같은 존에 생성됨
```

#### 2. 리소스 효율성
- **불필요한 PV 생성 방지**: 실제 사용될 때만 생성
- **노드 리소스 최적화**: Pod와 같은 노드에 스토리지 생성

#### 3. 스케줄링 최적화
```
기존 방식: PV 위치 → Pod 스케줄링 제약
WaitForFirstConsumer: Pod 스케줄링 → PV 생성 위치 결정
```

### 상태 변화 과정
```bash
# 1. PVC 생성 직후
$ kubectl get pvc
NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
app-pvc   Pending   ""       ""         ""             local-path

# 2. Pod 생성 후 (PV 자동 생성됨)
$ kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES
app-pvc   Bound    pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO
```

## 🔍 핵심 개념 3: 스토리지 클래스 구성

### 스토리지 클래스의 역할
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # 기본 SC 지정
provisioner: rancher.io/local-path  # 어떤 프로비저너 사용할지
volumeBindingMode: WaitForFirstConsumer  # 언제 PV를 생성할지
reclaimPolicy: Delete  # PVC 삭제 시 PV 처리 방법
allowVolumeExpansion: true  # 볼륨 확장 허용 여부
parameters:  # 프로비저너별 설정
  path: /opt/local-path-provisioner
```

### 주요 설정 옵션

#### volumeBindingMode
- **Immediate**: PVC 생성 즉시 PV 생성
- **WaitForFirstConsumer**: Pod 생성 시 PV 생성

#### reclaimPolicy
- **Delete**: PVC 삭제 시 PV도 자동 삭제
- **Retain**: PVC 삭제 후에도 PV 유지

#### allowVolumeExpansion
- **true**: 볼륨 크기 확장 가능
- **false**: 볼륨 크기 고정

## 🔍 핵심 개념 4: 스토리지 경로 설정

### Local Path Provisioner 경로 구조
```
기본 경로: /opt/local-path-provisioner/
├── pvc-12345678-1234-1234-1234-123456789012/  # PV별 고유 디렉토리
│   ├── .minio.sys/                            # MinIO 시스템 파일
│   ├── bucket1/                               # 사용자 버킷
│   └── bucket2/
└── pvc-87654321-4321-4321-4321-210987654321/
    ├── .minio.sys/
    └── data/
```

### 경로 커스터마이징
```yaml
# ConfigMap으로 경로 설정
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/mnt/minio-storage", "/var/lib/minio"]
        },
        {
          "node": "worker-node-1",
          "paths": ["/ssd/minio-data"]
        }
      ]
    }
```

**경로 선택 우선순위:**
1. 노드별 특정 경로 (nodePathMap에서 노드명 매칭)
2. 기본 경로 (DEFAULT_PATH_FOR_NON_LISTED_NODES)
3. 프로비저너 기본값 (/opt/local-path-provisioner)

## 🔍 핵심 개념 5: 동적 프로비저닝 준비 상태

### 필수 구성 요소 체크리스트

#### 1. 스토리지 프로비저너 실행 상태
```bash
# 프로비저너 Pod 확인
$ kubectl get pods -n local-path-storage
NAME                                     READY   STATUS    RESTARTS   AGE
local-path-provisioner-556d4466c8-xyz   1/1     Running   0          1h

# 프로비저너 로그 확인
$ kubectl logs -n local-path-storage deployment/local-path-provisioner
```

#### 2. 스토리지 클래스 설정
```bash
# 스토리지 클래스 존재 확인
$ kubectl get storageclass
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false

# 기본 스토리지 클래스 확인
$ kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
local-path
```

#### 3. 노드 스케줄링 가능 상태
```bash
# 스케줄링 가능한 노드 확인
$ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
master-node    Ready    control-plane   1d    v1.28.0
worker-node-1  Ready    <none>          1d    v1.28.0

# Taint 확인 (단일 노드의 경우)
$ kubectl describe node master-node | grep Taints
Taints:             <none>  # 스케줄링 가능
```

#### 4. 디스크 공간 확인
```bash
# 노드별 디스크 사용량 확인
$ df -h /opt/local-path-provisioner
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       100G   20G   80G  20% /
```

## 🎯 실습에서 확인할 수 있는 것들

### 1. PV 상태 변화 관찰
```bash
# MinIO 배포 전: PV 없음
$ kubectl get pv
No resources found

# MinIO 배포 후: PV 자동 생성
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-0
pvc-87654321-4321-4321-4321-210987654321   2Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-1
```

### 2. 스토리지 경로 확인
```bash
# 실제 생성된 스토리지 경로
$ kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path
NAME                                       PATH
pvc-12345678-1234-1234-1234-123456789012   /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012
pvc-87654321-4321-4321-4321-210987654321   /opt/local-path-provisioner/pvc-87654321-4321-4321-4321-210987654321
```

### 3. WaitForFirstConsumer 동작 확인
```bash
# PVC 생성 직후 (Pending 상태)
$ kubectl get pvc -n minio-tenant
NAME                           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
data-minio-tenant-pool-0-0     Pending   ""       ""         ""             local-path

# Pod 시작 후 (Bound 상태)
$ kubectl get pvc -n minio-tenant
NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES
data-minio-tenant-pool-0-0     Bound    pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO
```

## 🚨 일반적인 문제와 해결 방법

### 1. PVC가 계속 Pending 상태
**원인:** 스토리지 프로비저너 미설치 또는 오작동
```bash
# 해결 방법
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

### 2. 기본 스토리지 클래스 없음
**원인:** 기본 스토리지 클래스 미지정
```bash
# 해결 방법
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 3. 노드에 Pod 스케줄링 불가
**원인:** Control-plane taint (단일 노드 환경)
```bash
# 해결 방법
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## 📖 추가 학습 자료

### 공식 문서
- [Kubernetes Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)

### 실습 명령어
```bash
# 환경 검증 실행
./lab-00-env-check.sh

# 스토리지 클래스 상세 확인
kubectl describe storageclass local-path

# 프로비저너 설정 확인
kubectl get configmap local-path-config -n local-path-storage -o yaml
```

이 개념들을 이해하면 MinIO 배포 과정에서 일어나는 모든 스토리지 관련 동작을 완전히 이해할 수 있습니다.
