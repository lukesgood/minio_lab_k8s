# Lab 2: MinIO Tenant 배포 - 핵심 개념 상세 설명

## 📚 개요

Lab 2에서는 MinIO Tenant를 배포하면서 실시간 동적 프로비저닝 과정을 관찰하고, StatefulSet과 PVC의 관계, 그리고 WaitForFirstConsumer의 실제 동작을 학습합니다.

## 🏷️ 버전 정보

### MinIO Operator 기준 Tenant
- **CRD API 버전**: minio.min.io/v2
- **기본 MinIO 서버 이미지**: minio/minio (공식 기본값)
- **사이드카 이미지**: quay.io/minio/operator-sidecar
- **공식 예제 기준**: GitHub examples/kustomization/base/tenant.yaml

### 지원하는 주요 기능
- **features 섹션**: bucketDNS, domains 등 고급 기능
- **users 섹션**: 자동 사용자 생성
- **podManagementPolicy**: Pod 관리 정책 설정
- **공식 어노테이션**: Prometheus 모니터링 지원

## 🔍 핵심 개념 1: MinIO Tenant 아키텍처

### Tenant란?
MinIO에서 **Tenant**는 독립적인 MinIO 클러스터 인스턴스를 의미합니다.

```yaml
# 공식 v7.1.1 Tenant 리소스 구조
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
  # 공식 예제 라벨
  labels:
    app: minio
  # 공식 모니터링 어노테이션
  annotations:
    prometheus.io/path: /minio/v2/metrics/cluster
    prometheus.io/port: "9000"
    prometheus.io/scrape: "true"
spec:
  # 클러스터 전체 설정
  image: minio/minio:RELEASE.2025-04-08T15-41-24Z
  configuration:
    name: minio-creds-secret
  
  # 스토리지 풀 정의
  pools:
  - name: pool-0
    servers: 1              # 서버 수
    volumesPerServer: 2     # 서버당 볼륨 수
    volumeClaimTemplate:    # PVC 템플릿
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 2Gi
        storageClassName: local-path
```

### Tenant vs 전통적인 MinIO 배포

#### 전통적인 방식
```yaml
# 수동으로 각 구성 요소 생성
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
spec:
  serviceName: minio-headless
  replicas: 4
  template:
    spec:
      containers:
      - name: minio
        image: minio/minio
        command: ["/bin/sh"]
        args:
        - -c
        - minio server http://minio-{0...3}.minio-headless.default.svc.cluster.local/data{0...1}
        volumeMounts:
        - name: data-0
          mountPath: /data0
        - name: data-1
          mountPath: /data1
  volumeClaimTemplates:
  - metadata:
      name: data-0
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
  - metadata:
      name: data-1
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: minio-headless
spec:
  clusterIP: None
  selector:
    app: minio
  ports:
  - port: 9000
---
apiVersion: v1
kind: Service
metadata:
  name: minio-api
spec:
  selector:
    app: minio
  ports:
  - port: 9000
    targetPort: 9000
```

**문제점:**
- ❌ **복잡성**: 수많은 YAML 파일과 설정
- ❌ **오류 가능성**: 수동 설정으로 인한 실수
- ❌ **유지보수**: 업그레이드, 스케일링 등 수동 작업
- ❌ **일관성**: 환경별로 다른 설정

#### Tenant 방식
```yaml
# 단일 Tenant 리소스로 전체 클러스터 정의
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
spec:
  pools:
  - servers: 4
    volumesPerServer: 2
    volumeClaimTemplate:
      spec:
        resources:
          requests:
            storage: 10Gi
```

**장점:**
- ✅ **단순성**: 하나의 YAML로 전체 클러스터 정의
- ✅ **자동화**: Operator가 모든 구성 요소 자동 생성
- ✅ **최적화**: MinIO 전용 최적화 설정 자동 적용
- ✅ **일관성**: 모든 환경에서 동일한 방식

## 🔍 핵심 개념 2: StatefulSet과 PVC 관계

### StatefulSet의 특징

#### 1. 안정적인 네트워크 식별자
```bash
# StatefulSet Pod 이름 패턴
minio-tenant-pool-0-0  # 첫 번째 Pod
minio-tenant-pool-0-1  # 두 번째 Pod (다중 서버 시)
minio-tenant-pool-0-2  # 세 번째 Pod
```

**특징:**
- **예측 가능한 이름**: `{StatefulSet명}-{순서번호}`
- **순차적 생성**: 0번부터 순서대로 생성
- **안정적 DNS**: 각 Pod는 고유한 DNS 이름 보유

#### 2. 안정적인 스토리지
```yaml
# StatefulSet의 volumeClaimTemplates
spec:
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 2Gi
      storageClassName: local-path
```

**동작 방식:**
```bash
# 각 Pod마다 고유한 PVC 생성
data-minio-tenant-pool-0-0  # 첫 번째 Pod의 PVC
data-minio-tenant-pool-0-1  # 두 번째 Pod의 PVC
```

### PVC 생성 과정

#### 1. Tenant 생성 시
```yaml
# Operator가 StatefulSet 생성
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio-tenant-pool-0
spec:
  replicas: 1
  volumeClaimTemplates:
  - metadata:
      name: data-0
  - metadata:
      name: data-1
```

#### 2. StatefulSet Controller 동작
```bash
# StatefulSet Controller가 PVC 자동 생성
$ kubectl get pvc -n minio-tenant
NAME                               STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
data-0-minio-tenant-pool-0-0       Pending   ""       ""         ""             local-path
data-1-minio-tenant-pool-0-0       Pending   ""       ""         ""             local-path
```

#### 3. Pod 생성 시도
```bash
# Pod 생성 시 PVC 마운트 시도
$ kubectl get pods -n minio-tenant
NAME                     READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0    0/2     Pending   0          30s
```

#### 4. 동적 프로비저닝 트리거
```bash
# WaitForFirstConsumer로 인해 이때 PV 생성
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO            Delete           Bound    minio-tenant/data-0-minio-tenant-pool-0-0
pvc-87654321-4321-4321-4321-210987654321   2Gi        RWO            Delete           Bound    minio-tenant/data-1-minio-tenant-pool-0-0
```

## 🔍 핵심 개념 3: WaitForFirstConsumer 실제 동작

### 동작 시나리오 상세 분석

#### 시나리오 1: Immediate 모드 (비교용)
```yaml
# Immediate 모드 스토리지 클래스
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-storage
provisioner: rancher.io/local-path
volumeBindingMode: Immediate  # 즉시 바인딩
```

**동작 순서:**
```bash
# 1. PVC 생성
$ kubectl apply -f pvc.yaml
persistentvolumeclaim/test-pvc created

# 2. 즉시 PV 생성 및 바인딩
$ kubectl get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES
test-pvc   Bound    pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO

# 3. Pod 생성 시 이미 바인딩된 PV 사용
$ kubectl apply -f pod.yaml
pod/test-pod created
```

#### 시나리오 2: WaitForFirstConsumer 모드
```yaml
# WaitForFirstConsumer 모드 스토리지 클래스
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer  # 첫 소비자 대기
```

**동작 순서:**
```bash
# 1. PVC 생성
$ kubectl apply -f pvc.yaml
persistentvolumeclaim/test-pvc created

# 2. PV 생성되지 않음, Pending 상태 유지
$ kubectl get pvc
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
test-pvc   Pending   ""       ""         ""             local-path

# 3. Pod 생성 시에야 PV 생성 및 바인딩
$ kubectl apply -f pod.yaml
pod/test-pod created

$ kubectl get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES
test-pvc   Bound    pvc-87654321-4321-4321-4321-210987654321   1Gi        RWO
```

### WaitForFirstConsumer의 장점

#### 1. 최적 노드 선택
```yaml
# Pod에 노드 선택 조건이 있는 경우
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  nodeSelector:
    zone: us-west-1a
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-pvc
```

**Immediate 모드 문제:**
```bash
# PV가 다른 존에 생성될 수 있음
$ kubectl get pv -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],ZONE:.metadata.labels.topology\.kubernetes\.io/zone
NAME                                       NODE           ZONE
pvc-12345678-1234-1234-1234-123456789012   worker-node-2  us-west-1b  # 다른 존!

# Pod 스케줄링 실패
$ kubectl describe pod app-pod
Events:
  Warning  FailedScheduling  pod didn't fit on any node: node(s) had volume node affinity conflict
```

**WaitForFirstConsumer 해결:**
```bash
# Pod 스케줄링 후 같은 노드/존에 PV 생성
$ kubectl get pv -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],ZONE:.metadata.labels.topology\.kubernetes\.io/zone
NAME                                       NODE           ZONE
pvc-87654321-4321-4321-4321-210987654321   worker-node-1  us-west-1a  # 같은 존!
```

#### 2. 리소스 효율성
```bash
# 불필요한 PV 생성 방지
$ kubectl apply -f pvc.yaml
$ kubectl delete -f pvc.yaml  # PVC 즉시 삭제

# Immediate 모드: PV가 이미 생성되어 정리 필요
# WaitForFirstConsumer: PV가 생성되지 않아 정리 불필요
```

## 🔍 핵심 개념 4: 실시간 프로비저닝 모니터링

### 모니터링 포인트

#### 1. Tenant 상태 변화
```bash
# Tenant 생성 직후
$ kubectl get tenant -n minio-tenant
NAME           STATE         AGE
minio-tenant   Initializing  30s

# 배포 진행 중
$ kubectl get tenant -n minio-tenant
NAME           STATE         AGE
minio-tenant   Provisioned   2m

# 배포 완료
$ kubectl get tenant -n minio-tenant
NAME           STATE         AGE
minio-tenant   Initialized   5m
```

#### 2. PVC 상태 변화
```bash
# 초기 상태 (WaitForFirstConsumer)
$ kubectl get pvc -n minio-tenant
NAME                               STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
data-0-minio-tenant-pool-0-0       Pending   ""       ""         ""             local-path
data-1-minio-tenant-pool-0-0       Pending   ""       ""         ""             local-path

# Pod 시작 후 (동적 프로비저닝 발생)
$ kubectl get pvc -n minio-tenant
NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES
data-0-minio-tenant-pool-0-0       Bound    pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO
data-1-minio-tenant-pool-0-0       Bound    pvc-87654321-4321-4321-4321-210987654321   2Gi        RWO
```

#### 3. PV 생성 과정
```bash
# 배포 전: PV 없음
$ kubectl get pv
No resources found

# 배포 중: PV 생성됨
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO            Delete           Bound    minio-tenant/data-0-minio-tenant-pool-0-0
pvc-87654321-4321-4321-4321-210987654321   2Gi        RWO            Delete           Bound    minio-tenant/data-1-minio-tenant-pool-0-0

# 실제 스토리지 경로 확인
$ kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path
NAME                                       PATH
pvc-12345678-1234-1234-1234-123456789012   /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012
pvc-87654321-4321-4321-4321-210987654321   /opt/local-path-provisioner/pvc-87654321-4321-4321-4321-210987654321
```

#### 4. Pod 상태 변화
```bash
# 초기 상태 (볼륨 마운트 대기)
$ kubectl get pods -n minio-tenant
NAME                     READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0    0/2     Pending   0          1m

# 볼륨 바인딩 후 (컨테이너 시작)
$ kubectl get pods -n minio-tenant
NAME                     READY   STATUS     RESTARTS   AGE
minio-tenant-pool-0-0    0/2     Init:0/1   0          2m

# 초기화 완료 후 (서비스 준비)
$ kubectl get pods -n minio-tenant
NAME                     READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0    2/2     Running   0          3m
```

### 이벤트 기반 모니터링
```bash
# 실시간 이벤트 모니터링
$ kubectl get events -n minio-tenant --sort-by=.metadata.creationTimestamp -w

# 주요 이벤트 예시
LAST SEEN   TYPE     REASON              OBJECT                        MESSAGE
30s         Normal   Scheduled           pod/minio-tenant-pool-0-0     Successfully assigned minio-tenant/minio-tenant-pool-0-0 to worker-node-1
25s         Normal   ProvisioningSucceeded  persistentvolumeclaim/data-0-minio-tenant-pool-0-0  Successfully provisioned volume pvc-12345678-1234-1234-1234-123456789012
20s         Normal   Pulled              pod/minio-tenant-pool-0-0     Container image "minio/minio:RELEASE.2025-04-08T15-41-24Z" already present on machine
15s         Normal   Created             pod/minio-tenant-pool-0-0     Created container minio
10s         Normal   Started             pod/minio-tenant-pool-0-0     Started container minio
```

## 🔍 핵심 개념 5: Erasure Coding 설정

### Erasure Coding 기본 개념

#### 전통적인 복제 방식
```
데이터 복제 (Replication):
원본 데이터: [A] [B] [C] [D]
복제본 1:   [A] [B] [C] [D]
복제본 2:   [A] [B] [C] [D]

스토리지 효율: 33% (3개 중 1개만 실제 데이터)
장애 허용: 2개 복제본 손실까지 허용
```

#### Erasure Coding 방식
```
Erasure Coding (EC:4):
데이터 블록:   [A] [B] [C] [D]
패리티 블록:   [P1] [P2] [P3] [P4]

스토리지 효율: 50% (8개 중 4개가 실제 데이터)
장애 허용: 4개 블록 손실까지 허용
```

### MinIO의 Erasure Coding 설정

#### 1. 서버 수에 따른 EC 설정
```yaml
# 단일 서버 (EC 비활성화)
spec:
  pools:
  - servers: 1
    volumesPerServer: 2  # 로컬 중복성만 제공
```

```yaml
# 4서버 (EC:2 - 2개 패리티)
spec:
  pools:
  - servers: 4
    volumesPerServer: 1
    # 자동으로 EC:2 설정 (4개 중 2개 패리티)
```

```yaml
# 8서버 (EC:4 - 4개 패리티)
spec:
  pools:
  - servers: 8
    volumesPerServer: 1
    # 자동으로 EC:4 설정 (8개 중 4개 패리티)
```

#### 2. volumesPerServer의 역할
```yaml
# 단일 서버, 다중 볼륨
spec:
  pools:
  - servers: 1
    volumesPerServer: 4  # 4개 볼륨으로 로컬 분산
```

**효과:**
- **성능 향상**: 여러 디스크에 I/O 분산
- **로컬 중복성**: 한 볼륨 장애 시에도 데이터 보호
- **확장성**: 볼륨별로 독립적인 스토리지 관리

### EC 설정 확인 방법
```bash
# MinIO 서버 로그에서 EC 설정 확인
$ kubectl logs -n minio-tenant minio-tenant-pool-0-0 -c minio | grep -i erasure

# MinIO 클라이언트로 서버 정보 확인
$ mc admin info local
●  minio-tenant-pool-0-0.minio-tenant-hl.minio-tenant.svc.cluster.local:9000
   Uptime: 5 minutes
   Version: 2024-01-16T16:07:38Z
   Network: 1/1 OK
   Drives: 2/2 OK
   Pool: 1
```

## 🔍 핵심 개념 6: 실제 스토리지 경로 확인

### 스토리지 경로 구조

#### 1. PV 경로 매핑
```bash
# PV와 실제 경로 확인
$ kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path,CLAIM:.spec.claimRef.name
NAME                                       PATH                                                                      CLAIM
pvc-12345678-1234-1234-1234-123456789012   /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012     data-0-minio-tenant-pool-0-0
pvc-87654321-4321-4321-4321-210987654321   /opt/local-path-provisioner/pvc-87654321-4321-4321-4321-210987654321     data-1-minio-tenant-pool-0-0
```

#### 2. MinIO 데이터 구조
```bash
# 실제 파일시스템에서 확인 (노드 접근 가능한 경우)
$ ls -la /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012/
total 12
drwxrwxrwx 3 root root 4096 Jan  1 12:00 .
drwxr-xr-x 5 root root 4096 Jan  1 12:00 ..
drwxr-xr-x 2 root root 4096 Jan  1 12:00 .minio.sys

$ ls -la /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012/.minio.sys/
total 24
drwxr-xr-x 2 root root 4096 Jan  1 12:00 .
drwxrwxrwx 3 root root 4096 Jan  1 12:00 ..
-rw-r--r-- 1 root root   32 Jan  1 12:00 format.json
-rw-r--r-- 1 root root  156 Jan  1 12:00 pool.bin
```

#### 3. 버킷 데이터 확인
```bash
# 버킷 생성 후 디렉토리 구조
$ mc mb local/test-bucket
$ echo "Hello MinIO" > test.txt
$ mc cp test.txt local/test-bucket/

# 실제 파일시스템에서 확인
$ find /opt/local-path-provisioner/pvc-*/test-bucket -name "*.xl.meta" | head -5
/opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012/test-bucket/test.txt/xl.meta
```

**MinIO 파일 구조:**
- **xl.meta**: 객체 메타데이터 (크기, 체크섬, 타임스탬프 등)
- **part.1**: 실제 데이터 (Erasure Coding 적용된 경우 분할됨)
- **.minio.sys/**: MinIO 시스템 파일들

## 🎯 실습에서 확인할 수 있는 것들

### 1. 배포 전후 PV 상태 비교
```bash
# 배포 전
$ kubectl get pv
No resources found

# 배포 후
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO            Delete           Bound    minio-tenant/data-0-minio-tenant-pool-0-0
pvc-87654321-4321-4321-4321-210987654321   2Gi        RWO            Delete           Bound    minio-tenant/data-1-minio-tenant-pool-0-0
```

### 2. WaitForFirstConsumer 동작 관찰
```bash
# PVC 생성 직후 (Pending)
$ kubectl get pvc -n minio-tenant
NAME                               STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
data-0-minio-tenant-pool-0-0       Pending   ""       ""         ""             local-path

# Pod 시작 후 (Bound)
$ kubectl get pvc -n minio-tenant
NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES
data-0-minio-tenant-pool-0-0       Bound    pvc-12345678-1234-1234-1234-123456789012   2Gi        RWO
```

### 3. 실제 스토리지 경로 확인
```bash
# 생성된 스토리지 경로
$ kubectl get pv -o jsonpath='{range .items[*]}{.spec.local.path}{"\n"}{end}'
/opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012
/opt/local-path-provisioner/pvc-87654321-4321-4321-4321-210987654321
```

## 🚨 일반적인 문제와 해결 방법

### 1. PVC가 계속 Pending 상태
**원인:** Pod가 생성되지 않아 WaitForFirstConsumer 트리거 안됨
```bash
# Pod 상태 확인
kubectl get pods -n minio-tenant

# Pod 이벤트 확인
kubectl describe pod minio-tenant-pool-0-0 -n minio-tenant
```

### 2. Pod가 Pending 상태
**원인:** 노드 리소스 부족 또는 스케줄링 제약
```bash
# 노드 리소스 확인
kubectl describe nodes

# Pod 스케줄링 이벤트 확인
kubectl describe pod minio-tenant-pool-0-0 -n minio-tenant
```

### 3. 스토리지 공간 부족
**원인:** 노드의 디스크 공간 부족
```bash
# 디스크 사용량 확인
df -h /opt/local-path-provisioner

# PV 크기 조정 (재배포 필요)
kubectl delete tenant minio-tenant -n minio-tenant
# Tenant YAML에서 storage 크기 수정 후 재배포
```

## 📖 추가 학습 자료

### 공식 문서
- [MinIO Tenant Configuration](https://min.io/docs/minio/kubernetes/upstream/operations/install-deploy-manage/deploy-minio-tenant.html)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [MinIO Erasure Coding](https://min.io/docs/minio/linux/operations/concepts/erasure-coding.html)

### 실습 명령어
```bash
# Tenant 배포 실행
./lab-02-tenant-deploy.sh

# 실시간 상태 모니터링
kubectl get pods,pvc,pv -n minio-tenant -w

# 상세 이벤트 확인
kubectl get events -n minio-tenant --sort-by=.metadata.creationTimestamp
```

이 개념들을 이해하면 MinIO Tenant 배포 과정에서 일어나는 모든 동적 프로비저닝과 스토리지 관련 동작을 완전히 이해할 수 있습니다.

---

## 📋 기준 버전 정보

이 문서는 다음 버전을 기준으로 작성되었습니다:

- **MinIO Operator**: v7.1.1 (2025-04-23 릴리스)
- **MinIO Server**: RELEASE.2025-04-08T15-41-24Z
- **Kubernetes**: 1.20+
- **CRD API**: minio.min.io/v2

**공식 저장소**: https://github.com/minio/operator
