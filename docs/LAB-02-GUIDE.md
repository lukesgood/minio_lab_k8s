# Lab 2: MinIO Tenant 배포 - 단계별 실습 가이드

## 📚 개요

이 실습에서는 MinIO Operator를 사용하여 실제 MinIO Tenant를 배포합니다. 동적 프로비저닝 과정을 실시간으로 관찰하고, WaitForFirstConsumer 모드의 동작 원리를 실제로 경험합니다.

## 🎯 학습 목표

- MinIO Tenant 개념과 역할 이해
- 실시간 동적 프로비저닝 과정 관찰
- StatefulSet과 PVC의 관계 학습
- WaitForFirstConsumer 동작 원리 체험
- Erasure Coding 설정 및 검증
- 실제 스토리지 경로 확인

## ⏱️ 예상 소요시간
15-20분

## 🔧 사전 준비사항

- Lab 1 완료 (MinIO Operator 설치)
- 스토리지 클래스 설정 완료
- kubectl 명령어 도구
- 충분한 클러스터 리소스 (최소 2GB RAM, 2 CPU)

---

## Step 1: 사전 요구사항 확인

### 💡 개념 설명
MinIO Tenant 배포 전 환경 상태를 재확인합니다:

**확인 항목**:
- **MinIO Operator**: 정상 실행 상태
- **스토리지 클래스**: 동적 프로비저닝 준비 상태
- **클러스터 리소스**: 충분한 CPU/메모리
- **네임스페이스**: Tenant 배포용 네임스페이스

### 🔍 MinIO Operator 상태 확인
```bash
kubectl get pods -n minio-operator
```

### ✅ 예상 출력
```
NAME                              READY   STATUS    RESTARTS   AGE
minio-operator-7d4c8b5f9b-xyz12   1/1     Running   0          10m
```

### 📚 상태 해석
- **READY**: 1/1 (정상)
- **STATUS**: Running (실행 중)
- **RESTARTS**: 0 (안정적)

### 🔍 스토리지 클래스 확인
```bash
kubectl get storageclass
```

### ✅ 예상 출력
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default) rancher.io/local-path      Delete          WaitForFirstConsumer   false                  1h
```

### 📚 중요 설정 확인
- **(default)**: 기본 스토리지 클래스 설정됨
- **VOLUMEBINDINGMODE**: WaitForFirstConsumer (핵심!)
- **PROVISIONER**: 동적 프로비저닝 담당 컴포넌트

### 🚨 문제 해결

#### 문제: Operator Pod가 Running이 아님
**해결 방법**: Lab 1로 돌아가서 Operator 재설치

#### 문제: 기본 스토리지 클래스 없음
**해결 방법**:
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 🛑 체크포인트
Operator가 Running 상태이고 기본 스토리지 클래스가 설정되었는지 확인하세요.

---

## Step 2: MinIO Tenant 개념 이해

### 💡 개념 설명

**MinIO Tenant란?**
MinIO Operator에서 관리하는 MinIO 클러스터의 인스턴스입니다.

**Tenant vs Instance 비교**:
| 구분 | 전통적인 Instance | MinIO Tenant |
|------|-------------------|--------------|
| **관리 방식** | 수동 설정 | 선언적 정의 |
| **확장** | 수동 스케일링 | 자동 스케일링 |
| **업그레이드** | 수동 절차 | 자동 롤링 업데이트 |
| **복구** | 수동 개입 | 자동 복구 |
| **모니터링** | 별도 도구 | 통합 대시보드 |

### 📊 MinIO Tenant 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    MinIO Tenant                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Pool 1    │    │   Pool 2    │    │   Pool N    │     │
│  │             │    │             │    │             │     │
│  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │     │
│  │ │ Server 1│ │    │ │ Server 1│ │    │ │ Server 1│ │     │
│  │ │ Server 2│ │    │ │ Server 2│ │    │ │ Server 2│ │     │
│  │ │ Server 3│ │    │ │ Server 3│ │    │ │ Server 3│ │     │
│  │ │ Server 4│ │    │ │ Server 4│ │    │ │ Server 4│ │     │
│  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Resources                        │
├─────────────────────────────────────────────────────────────┤
│  StatefulSet │ Services │ ConfigMaps │ Secrets │ PVCs      │
└─────────────────────────────────────────────────────────────┘
```

### 🔍 Tenant 구성 요소

**1. Pool (풀)**
- MinIO 서버들의 논리적 그룹
- 독립적인 Erasure Coding 도메인
- 확장 시 새로운 Pool 추가 가능

**2. Server (서버)**
- 실제 MinIO 프로세스가 실행되는 Pod
- 각 서버는 여러 볼륨을 가질 수 있음
- StatefulSet으로 관리됨

**3. Volume (볼륨)**
- 실제 데이터가 저장되는 스토리지
- PVC (PersistentVolumeClaim)로 관리
- 동적 프로비저닝으로 자동 생성

### 📋 Erasure Coding 개념

**Erasure Coding이란?**
데이터를 여러 조각으로 나누어 저장하고, 일부 조각이 손실되어도 복구할 수 있는 기술입니다.

**EC:4 설정 예시** (8개 드라이브):
```
┌─────────┬─────────┬─────────┬─────────┐
│ Data 1  │ Data 2  │ Data 3  │ Data 4  │  ← 데이터 조각
├─────────┼─────────┼─────────┼─────────┤
│Parity 1 │Parity 2 │Parity 3 │Parity 4 │  ← 패리티 조각
└─────────┴─────────┴─────────┴─────────┘

- 4개 드라이브까지 장애 허용
- 스토리지 효율: 50% (4/8)
- 높은 데이터 보호 수준
```

### 🛑 체크포인트
MinIO Tenant의 구조와 Erasure Coding 개념을 이해했는지 확인하세요.

---

## Step 3: Tenant 네임스페이스 생성

### 💡 개념 설명
Tenant는 별도의 네임스페이스에 배포하여 격리와 관리를 용이하게 합니다:

**네임스페이스 분리 이유**:
- **격리**: Operator와 Tenant 분리
- **보안**: 네임스페이스별 권한 관리
- **관리**: 리소스 그룹화 및 정리
- **멀티테넌시**: 여러 Tenant 독립 운영

### 🔍 실행할 명령어
```bash
kubectl create namespace minio-tenant
```

### ✅ 예상 출력
```
namespace/minio-tenant created
```

### 🔍 네임스페이스 확인
```bash
kubectl get namespaces
```

### ✅ 확인 결과
```
NAME              STATUS   AGE
default           Active   1d
kube-node-lease   Active   1d
kube-public       Active   1d
kube-system       Active   1d
minio-operator    Active   30m
minio-tenant      Active   10s
```

### 📚 네임스페이스 구조
- **minio-operator**: Operator 관련 리소스
- **minio-tenant**: Tenant 관련 리소스 (새로 생성)

### 🛑 체크포인트
minio-tenant 네임스페이스가 "Active" 상태로 생성되었는지 확인하세요.

---

## Step 4: Tenant 인증 시크릿 생성

### 💡 개념 설명
MinIO Tenant는 관리자 계정 정보를 Kubernetes Secret으로 관리합니다:

**시크릿 필요성**:
- **보안**: 평문 패스워드 저장 방지
- **관리**: Kubernetes 네이티브 시크릿 관리
- **자동화**: Operator가 자동으로 시크릿 참조
- **회전**: 패스워드 변경 시 자동 적용

### 🔍 실행할 명령어
```bash
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant
```

### ✅ 예상 출력
```
secret/minio-creds-secret created
```

### 📋 명령어 설명
- `kubectl create secret generic`: 일반 시크릿 생성
- `minio-creds-secret`: 시크릿 이름
- `--from-literal`: 리터럴 값으로 시크릿 생성
- `config.env`: MinIO 환경 변수 설정
- `-n minio-tenant`: 대상 네임스페이스

### 🔍 시크릿 확인
```bash
kubectl get secret minio-creds-secret -n minio-tenant
```

### ✅ 확인 결과
```
NAME                 TYPE     DATA   AGE
minio-creds-secret   Opaque   1      10s
```

### 📚 시크릿 내용 확인 (디버깅용)
```bash
kubectl get secret minio-creds-secret -n minio-tenant -o yaml
```

### ⚠️ 보안 주의사항
- **프로덕션 환경**: 강력한 패스워드 사용
- **시크릿 관리**: 적절한 RBAC 설정
- **백업**: 시크릿 백업 및 복구 계획

### 🛑 체크포인트
minio-creds-secret이 성공적으로 생성되었는지 확인하세요.

---

## Step 5: 동적 프로비저닝 관찰 준비

### 💡 개념 설명
Tenant 배포 전에 현재 PV 상태를 확인하여 동적 프로비저닝 과정을 관찰할 준비를 합니다.

**관찰 포인트**:
- **배포 전**: PV가 존재하지 않음
- **PVC 생성**: PV가 아직 생성되지 않음 (WaitForFirstConsumer)
- **Pod 스케줄링**: PV가 자동으로 생성됨
- **바인딩**: PVC와 PV가 연결됨

### 🔍 현재 PV 상태 확인
```bash
echo "=== 배포 전 PV 상태 ==="
kubectl get pv
```

### ✅ 예상 출력 (배포 전)
```
No resources found
```

### 🔍 현재 PVC 상태 확인
```bash
echo "=== 배포 전 PVC 상태 ==="
kubectl get pvc -n minio-tenant
```

### ✅ 예상 출력 (배포 전)
```
No resources found in minio-tenant namespace.
```

### 📊 모니터링 창 준비
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
watch -n 2 'kubectl get pods -n minio-tenant'
```

### 🛑 체크포인트
모니터링 창이 준비되었고 현재 PV/PVC가 없는 상태임을 확인하세요.

---

## Step 6: MinIO Tenant YAML 정의

### 💡 개념 설명
MinIO Tenant는 CRD를 통해 선언적으로 정의됩니다. YAML 파일에 원하는 상태를 기술하면 Operator가 자동으로 구현합니다.

### 🔍 Tenant YAML 파일 생성
```bash
cat << EOF > minio-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2023-08-04T17-40-21Z
  credsSecret:
    name: minio-creds-secret
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
            storage: 1Gi
        storageClassName: local-path
  mountPath: /export
  subPath: /data
  requestAutoCert: false
EOF
```

### 📚 YAML 구성 요소 설명

**메타데이터**:
- `apiVersion`: minio.min.io/v2 (MinIO Operator API 버전)
- `kind`: Tenant (리소스 유형)
- `name`: minio-tenant (Tenant 이름)
- `namespace`: minio-tenant (배포 네임스페이스)

**스펙 (spec)**:
- `image`: MinIO 컨테이너 이미지 버전
- `credsSecret`: 인증 정보 시크릿 참조
- `pools`: MinIO 서버 풀 정의
- `mountPath`: 컨테이너 내 마운트 경로
- `subPath`: 실제 데이터 저장 하위 경로
- `requestAutoCert`: TLS 인증서 자동 생성 (false = HTTP)

**풀 설정 (pools)**:
- `servers`: 1 (단일 노드 환경용)
- `name`: pool-0 (풀 이름)
- `volumesPerServer`: 4 (서버당 볼륨 수)
- `volumeClaimTemplate`: PVC 템플릿 정의

**볼륨 클레임 템플릿**:
- `accessModes`: ReadWriteOnce (단일 노드 읽기/쓰기)
- `storage`: 1Gi (볼륨당 크기)
- `storageClassName`: local-path (스토리지 클래스)

### 🔍 YAML 파일 확인
```bash
cat minio-tenant.yaml
```

### 🛑 체크포인트
YAML 파일이 올바르게 생성되었는지 확인하세요.

---

## Step 7: Tenant 배포 및 실시간 프로비저닝 관찰

### 💡 개념 설명
이제 실제 Tenant를 배포하면서 동적 프로비저닝 과정을 실시간으로 관찰합니다.

**예상 진행 순서**:
1. **Tenant 생성**: CRD 리소스 생성
2. **PVC 생성**: 4개의 PVC 생성 (Pending 상태)
3. **StatefulSet 생성**: MinIO Pod 정의
4. **Pod 스케줄링**: Pod가 노드에 배치 결정
5. **PV 자동 생성**: 프로비저너가 PV 생성
6. **바인딩**: PVC와 PV 연결
7. **Pod 시작**: 볼륨 마운트 후 MinIO 시작

### 🔍 Tenant 배포 실행
```bash
kubectl apply -f minio-tenant.yaml
```

### ✅ 예상 출력
```
tenant.minio.min.io/minio-tenant created
```

### 📊 실시간 관찰 포인트

**1단계: PVC 생성 확인 (즉시)**
```bash
kubectl get pvc -n minio-tenant
```

**예상 출력**:
```
NAME           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-tenant-pool-0-0   Pending   -        -          -              local-path     5s
data-minio-tenant-pool-0-1   Pending   -        -          -              local-path     5s
data-minio-tenant-pool-0-2   Pending   -        -          -              local-path     5s
data-minio-tenant-pool-0-3   Pending   -        -          -              local-path     5s
```

**📚 중요 관찰 사항**:
- **STATUS: Pending**: 정상 상태! (WaitForFirstConsumer 모드)
- **VOLUME: -**: 아직 PV가 생성되지 않음
- **4개 PVC**: volumesPerServer 설정에 따라 생성

**2단계: StatefulSet 생성 확인**
```bash
kubectl get statefulset -n minio-tenant
```

**예상 출력**:
```
NAME                     READY   AGE
minio-tenant-pool-0      0/1     10s
```

**3단계: Pod 상태 확인**
```bash
kubectl get pods -n minio-tenant
```

**예상 출력 (초기)**:
```
NAME                       READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0      0/1     Pending   0          15s
```

**4단계: PV 자동 생성 관찰 (Pod 스케줄링 후)**
```bash
kubectl get pv
```

**예상 출력 (프로비저닝 후)**:
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                      STORAGECLASS   REASON   AGE
pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-0   local-path              30s
pvc-23456789-2345-2345-2345-234567890123   1Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-1   local-path              30s
pvc-34567890-3456-3456-3456-345678901234   1Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-2   local-path              30s
pvc-45678901-4567-4567-4567-456789012345   1Gi        RWO            Delete           Bound    minio-tenant/data-minio-tenant-pool-0-3   local-path              30s
```

**5단계: PVC 바인딩 확인**
```bash
kubectl get pvc -n minio-tenant
```

**예상 출력 (바인딩 후)**:
```
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-tenant-pool-0-0   Bound    pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO            local-path     1m
data-minio-tenant-pool-0-1   Bound    pvc-23456789-2345-2345-2345-234567890123   1Gi        RWO            local-path     1m
data-minio-tenant-pool-0-2   Bound    pvc-34567890-3456-3456-3456-345678901234   1Gi        RWO            local-path     1m
data-minio-tenant-pool-0-3   Bound    pvc-45678901-4567-4567-4567-456789012345   1Gi        RWO            local-path     1m
```

**6단계: Pod 실행 확인**
```bash
kubectl get pods -n minio-tenant
```

**예상 출력 (최종)**:
```
NAME                       READY   STATUS    RESTARTS   AGE
minio-tenant-pool-0-0      1/1     Running   0          2m
```

### 🛑 체크포인트
모든 PVC가 "Bound" 상태이고 MinIO Pod가 "Running" 상태인지 확인하세요.

---

이것은 Lab 02 가이드의 첫 번째 부분입니다. 계속해서 나머지 단계들을 추가하겠습니다.
## Step 8: 배포 상태 종합 확인

### 💡 개념 설명
Tenant 배포가 완료되면 모든 구성 요소의 상태를 종합적으로 확인해야 합니다.

### 🔍 종합 상태 확인 명령어
```bash
echo "=== MinIO Tenant 배포 상태 확인 ==="
echo ""

echo "1. Tenant 리소스:"
kubectl get tenant -n minio-tenant

echo -e "\n2. StatefulSet:"
kubectl get statefulset -n minio-tenant

echo -e "\n3. Pod 상태:"
kubectl get pods -n minio-tenant -o wide

echo -e "\n4. PVC 상태:"
kubectl get pvc -n minio-tenant

echo -e "\n5. PV 상태:"
kubectl get pv

echo -e "\n6. 서비스:"
kubectl get service -n minio-tenant
```

### ✅ 성공적인 배포 상태

**1. Tenant 리소스**:
```
NAME           STATE         AGE
minio-tenant   Initialized   3m
```

**2. StatefulSet**:
```
NAME                     READY   AGE
minio-tenant-pool-0      1/1     3m
```

**3. Pod 상태**:
```
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE
minio-tenant-pool-0-0      1/1     Running   0          3m    10.244.0.5   minikube
```

**4. PVC 상태**:
```
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-tenant-pool-0-0   Bound    pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO            local-path     3m
data-minio-tenant-pool-0-1   Bound    pvc-23456789-2345-2345-2345-234567890123   1Gi        RWO            local-path     3m
data-minio-tenant-pool-0-2   Bound    pvc-34567890-3456-3456-3456-345678901234   1Gi        RWO            local-path     3m
data-minio-tenant-pool-0-3   Bound    pvc-45678901-4567-4567-4567-456789012345   1Gi        RWO            local-path     3m
```

**5. 서비스**:
```
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
minio-tenant-console        ClusterIP   10.96.123.45    <none>        9090/TCP   3m
minio-tenant-hl             ClusterIP   None            <none>        9000/TCP   3m
```

### 📚 서비스 설명
- **minio-tenant-console**: MinIO 웹 콘솔 서비스
- **minio-tenant-hl**: MinIO API 서비스 (Headless)

### 🛑 체크포인트
모든 구성 요소가 정상 상태인지 확인하세요.

---

## Step 9: MinIO Pod 로그 확인

### 💡 개념 설명
MinIO Pod의 로그를 통해 서버가 정상적으로 시작되었는지 확인합니다.

### 🔍 실행할 명령어
```bash
kubectl logs -n minio-tenant minio-tenant-pool-0-0
```

### ✅ 예상 출력 (정상 시작)
```
MinIO Object Storage Server
Copyright: 2015-2023 MinIO, Inc.
License: GNU AGPLv3 <https://www.gnu.org/licenses/agpl-3.0.html>
Version: RELEASE.2023-08-04T17-40-21Z (go1.20.6 linux/amd64)

Status:         4 Online, 0 Offline. 
API: http://10.244.0.5:9000  http://127.0.0.1:9000   
Console: http://10.244.0.5:9001 http://127.0.0.1:9001 

Documentation: https://min.io/docs/minio/linux/index.html
Warning: The standard parity is set to 2. This can lead to data loss.
```

### 📚 로그 메시지 해석
- **Status**: 4 Online (4개 볼륨 모두 온라인)
- **API**: MinIO S3 API 엔드포인트
- **Console**: MinIO 웹 콘솔 엔드포인트
- **Warning**: 단일 노드 환경에서의 패리티 경고 (정상)

### 🔍 실시간 로그 모니터링
```bash
kubectl logs -n minio-tenant minio-tenant-pool-0-0 -f
```

### 🚨 문제 해결

#### 문제: "No such file or directory" 오류
**원인**: 볼륨 마운트 실패

**해결 방법**:
```bash
# Pod 상세 정보 확인
kubectl describe pod -n minio-tenant minio-tenant-pool-0-0

# PVC 상태 재확인
kubectl get pvc -n minio-tenant
```

#### 문제: "Permission denied" 오류
**원인**: 볼륨 권한 문제

**해결 방법**:
```bash
# Pod 내부 권한 확인
kubectl exec -n minio-tenant minio-tenant-pool-0-0 -- ls -la /export
```

### 🛑 체크포인트
MinIO 서버가 정상적으로 시작되고 "4 Online" 상태인지 확인하세요.

---

## Step 10: 실제 스토리지 경로 확인

### 💡 개념 설명
동적 프로비저닝으로 생성된 PV의 실제 저장 위치를 확인하여 데이터가 어디에 저장되는지 이해합니다.

### 🔍 PV 상세 정보 확인
```bash
kubectl describe pv | grep -A 5 -B 5 "local-path"
```

### ✅ 예상 출력
```
Name:              pvc-12345678-1234-1234-1234-123456789012
Labels:            <none>
Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
Finalizers:        [kubernetes.io/pv-protection]
StorageClass:      local-path
Status:            Bound
Claim:             minio-tenant/data-minio-tenant-pool-0-0
Reclaim Policy:    Delete
Access Modes:      RWO
VolumeMode:        Filesystem
Capacity:          1Gi
Node Affinity:     
  Required Terms:  
    Term 0:        kubernetes.io/hostname in [minikube]
Message:           
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /opt/local-path-provisioner/pvc-12345678-1234-1234-1234-123456789012_minio-tenant_data-minio-tenant-pool-0-0
    HostPathType:  DirectoryOrCreate
```

### 📚 중요 정보 해석
- **Path**: 실제 호스트 경로
- **HostPathType**: DirectoryOrCreate (디렉토리 자동 생성)
- **Node Affinity**: 특정 노드에 바인딩됨

### 🔍 실제 파일시스템 확인 (단일 노드 환경)
```bash
# 노드에 직접 접근 가능한 경우
sudo ls -la /opt/local-path-provisioner/

# Minikube 환경인 경우
minikube ssh
sudo ls -la /opt/local-path-provisioner/
```

### ✅ 예상 출력
```
drwxr-xr-x 2 root root 4096 Aug 10 10:30 pvc-12345678-1234-1234-1234-123456789012_minio-tenant_data-minio-tenant-pool-0-0
drwxr-xr-x 2 root root 4096 Aug 10 10:30 pvc-23456789-2345-2345-2345-234567890123_minio-tenant_data-minio-tenant-pool-0-1
drwxr-xr-x 2 root root 4096 Aug 10 10:30 pvc-34567890-3456-3456-3456-345678901234_minio-tenant_data-minio-tenant-pool-0-2
drwxr-xr-x 2 root root 4096 Aug 10 10:30 pvc-45678901-4567-4567-4567-456789012345_minio-tenant_data-minio-tenant-pool-0-3
```

### 🔍 MinIO 데이터 구조 확인
```bash
# Pod 내부에서 데이터 구조 확인
kubectl exec -n minio-tenant minio-tenant-pool-0-0 -- ls -la /export/
```

### ✅ 예상 출력
```
total 16
drwxr-xr-x 6 minio minio 4096 Aug 10 10:30 .
drwxr-xr-x 1 root  root  4096 Aug 10 10:30 ..
drwxr-xr-x 2 minio minio 4096 Aug 10 10:30 data1
drwxr-xr-x 2 minio minio 4096 Aug 10 10:30 data2
drwxr-xr-x 2 minio minio 4096 Aug 10 10:30 data3
drwxr-xr-x 2 minio minio 4096 Aug 10 10:30 data4
```

### 📚 MinIO 데이터 구조 이해
- **data1-4**: 각 볼륨에 대응하는 데이터 디렉토리
- **minio 사용자**: MinIO 프로세스 소유자
- **Erasure Coding**: 데이터가 4개 디렉토리에 분산 저장

### 🛑 체크포인트
실제 스토리지 경로와 MinIO 데이터 구조를 확인했는지 점검하세요.

---

## Step 11: MinIO 서비스 접근 설정

### 💡 개념 설명
배포된 MinIO에 접근하기 위해 포트 포워딩을 설정합니다.

### 🔍 서비스 확인
```bash
kubectl get service -n minio-tenant
```

### ✅ 예상 출력
```
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
minio-tenant-console        ClusterIP   10.96.123.45    <none>        9090/TCP   5m
minio-tenant-hl             ClusterIP   None            <none>        9000/TCP   5m
```

### 🔍 MinIO API 포트 포워딩
```bash
kubectl port-forward -n minio-tenant svc/minio-tenant-hl 9000:9000 &
```

### 🔍 MinIO Console 포트 포워딩
```bash
kubectl port-forward -n minio-tenant svc/minio-tenant-console 9001:9090 &
```

### ✅ 포트 포워딩 확인
```
Forwarding from 127.0.0.1:9000 -> 9000
Forwarding from [::1]:9000 -> 9000
Forwarding from 127.0.0.1:9001 -> 9090
Forwarding from [::1]:9001 -> 9090
```

### 🌐 접근 주소
- **MinIO API**: http://localhost:9000
- **MinIO Console**: http://localhost:9001

### 🔑 로그인 정보
- **사용자명**: admin
- **패스워드**: password123

### 🛑 체크포인트
포트 포워딩이 설정되고 접근 주소가 준비되었는지 확인하세요.

---

## Step 12: 배포 검증 및 기본 테스트

### 💡 개념 설명
MinIO가 정상적으로 작동하는지 기본적인 연결 테스트를 수행합니다.

### 🔍 MinIO API 연결 테스트
```bash
curl -I http://localhost:9000/minio/health/live
```

### ✅ 예상 출력
```
HTTP/1.1 200 OK
Accept-Ranges: bytes
Content-Length: 0
Content-Security-Policy: block-all-mixed-content
Server: MinIO
Strict-Transport-Security: max-age=31536000; includeSubDomains
Vary: Origin
X-Amz-Request-Id: 17C8B2F2F8A2B8E4
X-Content-Type-Options: nosniff
X-Xss-Protection: 1; mode=block
Date: Thu, 10 Aug 2023 10:35:00 GMT
```

### 📚 응답 해석
- **HTTP/1.1 200 OK**: 서버 정상 응답
- **Server: MinIO**: MinIO 서버 확인
- **X-Amz-Request-Id**: AWS S3 호환 헤더

### 🔍 MinIO Console 접근 테스트
브라우저에서 http://localhost:9001 접근:

1. **로그인 페이지**: MinIO 로고와 로그인 폼 표시
2. **사용자명**: admin 입력
3. **패스워드**: password123 입력
4. **로그인**: 대시보드 접근 성공

### 📊 Console 대시보드 확인 사항
- **서버 상태**: Online 표시
- **드라이브 수**: 4개 드라이브 표시
- **용량**: 총 4Gi 용량 표시
- **버킷**: 빈 버킷 목록 (정상)

### 🛑 체크포인트
API 연결 테스트가 성공하고 웹 콘솔에 로그인할 수 있는지 확인하세요.

---

## 🎯 배포 성공 확인 및 최종 검증

### ✅ 성공 기준 체크리스트

**인프라 레벨**:
- [ ] **네임스페이스**: minio-tenant가 Active 상태
- [ ] **시크릿**: minio-creds-secret 생성됨
- [ ] **Tenant**: minio-tenant 리소스가 Initialized 상태
- [ ] **StatefulSet**: minio-tenant-pool-0이 1/1 Ready
- [ ] **Pod**: minio-tenant-pool-0-0이 Running 상태

**스토리지 레벨**:
- [ ] **PVC**: 4개 PVC가 모두 Bound 상태
- [ ] **PV**: 4개 PV가 자동 생성되고 Bound 상태
- [ ] **동적 프로비저닝**: WaitForFirstConsumer 모드 정상 동작
- [ ] **실제 경로**: 호스트 파일시스템에 데이터 디렉토리 생성

**애플리케이션 레벨**:
- [ ] **MinIO 로그**: "4 Online, 0 Offline" 상태
- [ ] **서비스**: API 및 Console 서비스 생성
- [ ] **포트 포워딩**: 9000, 9001 포트 접근 가능
- [ ] **API 테스트**: Health check 응답 정상
- [ ] **웹 콘솔**: 로그인 및 대시보드 접근 성공

### 🔍 최종 상태 확인 명령어
```bash
echo "=== MinIO Tenant 최종 배포 상태 ==="
echo ""

echo "✅ 1. Tenant 상태:"
kubectl get tenant -n minio-tenant -o wide

echo -e "\n✅ 2. 전체 리소스 상태:"
kubectl get all -n minio-tenant

echo -e "\n✅ 3. 스토리지 상태:"
kubectl get pvc,pv -n minio-tenant

echo -e "\n✅ 4. MinIO 서버 상태:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 --tail=5

echo -e "\n✅ 5. 접근 정보:"
echo "MinIO API: http://localhost:9000"
echo "MinIO Console: http://localhost:9001"
echo "사용자명: admin"
echo "패스워드: password123"
```

---

## 🧠 학습 성과 확인

### 📋 이해도 점검 질문

1. **WaitForFirstConsumer 모드에서 PVC가 Pending 상태인 것이 정상인 이유를 설명할 수 있나요?**
2. **동적 프로비저닝 과정에서 PV가 언제 생성되는지 알고 있나요?**
3. **MinIO Tenant에서 volumesPerServer 설정의 의미를 이해했나요?**
4. **Erasure Coding이 어떻게 데이터를 보호하는지 설명할 수 있나요?**
5. **실제 데이터가 호스트 파일시스템의 어디에 저장되는지 알고 있나요?**

### 🎓 핵심 개념 정리

**동적 프로비저닝**:
- PVC 생성 시 자동으로 PV 생성
- WaitForFirstConsumer 모드로 최적화된 배치
- 프로비저너가 실제 스토리지 할당 담당

**MinIO Tenant**:
- CRD를 통한 선언적 정의
- Operator가 복잡한 리소스 자동 생성
- StatefulSet 기반의 상태 유지 애플리케이션

**Erasure Coding**:
- 데이터를 여러 조각으로 분산 저장
- 일부 드라이브 장애 시에도 데이터 복구 가능
- 스토리지 효율성과 안정성의 균형

**Kubernetes 네이티브 관리**:
- kubectl로 MinIO 클러스터 관리
- 네임스페이스를 통한 격리
- 시크릿을 통한 보안 정보 관리

---

## 🚨 문제 해결 가이드

### 자주 발생하는 문제들

| 문제 | 증상 | 원인 | 해결 방법 |
|------|------|------|-----------|
| PVC Pending | PVC가 계속 Pending | 정상 동작 (WaitForFirstConsumer) | Pod 생성 대기 |
| Pod Pending | Pod가 스케줄링되지 않음 | 노드 taint, 리소스 부족 | taint 제거, 리소스 확인 |
| 볼륨 마운트 실패 | Pod가 ContainerCreating | PV 생성 실패, 권한 문제 | PV 상태 확인, 권한 수정 |
| MinIO 시작 실패 | Pod가 CrashLoopBackOff | 설정 오류, 볼륨 문제 | 로그 확인, 볼륨 검증 |
| 포트 접근 불가 | 연결 거부 | 포트 포워딩 실패 | 포트 포워딩 재설정 |

### 🔧 디버깅 명령어 모음

```bash
# 전체 상태 확인
kubectl get all -n minio-tenant

# Pod 상세 정보
kubectl describe pod -n minio-tenant minio-tenant-pool-0-0

# PVC 상태 확인
kubectl describe pvc -n minio-tenant

# 이벤트 확인
kubectl get events -n minio-tenant --sort-by='.lastTimestamp'

# 로그 확인
kubectl logs -n minio-tenant minio-tenant-pool-0-0

# 리소스 사용량 확인 (metrics-server 필요)
kubectl top pod -n minio-tenant
```

---

## 🚀 다음 단계

MinIO Tenant 배포가 성공적으로 완료되었습니다! 이제 실제 MinIO Client를 설정하고 S3 API를 사용해보겠습니다.

**Lab 3: MinIO Client 및 기본 사용법**에서 학습할 내용:
- MinIO Client (mc) 설치 및 설정
- S3 호환 API를 통한 버킷 및 객체 관리
- 실제 데이터 업로드/다운로드 테스트
- 데이터 무결성 검증 및 실제 저장 위치 확인

### 🔗 관련 문서
- [Lab 3 가이드: MinIO Client 및 기본 사용법](LAB-03-GUIDE.md)
- [MinIO Tenant 상세 개념](LAB-02-CONCEPTS.md)
- [동적 프로비저닝 심화 학습](LAB-00-CONCEPTS.md)

### 🧹 정리 명령어 (필요한 경우)
```bash
# Tenant 제거 (다음 Lab 진행 전에는 실행하지 마세요)
kubectl delete tenant minio-tenant -n minio-tenant
kubectl delete namespace minio-tenant

# 포트 포워딩 종료
pkill -f "kubectl port-forward"
```

---

축하합니다! MinIO Tenant가 성공적으로 배포되었고, 동적 프로비저닝의 전체 과정을 실제로 관찰했습니다. 이제 Kubernetes에서 MinIO를 네이티브 방식으로 운영할 수 있는 기반이 완전히 구축되었습니다.
