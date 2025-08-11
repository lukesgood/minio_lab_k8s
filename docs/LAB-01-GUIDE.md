# Lab 1: MinIO Operator 설치 - 단계별 실습 가이드

## 📚 개요

이 실습에서는 Kubernetes Operator 패턴을 학습하고 MinIO Operator를 설치합니다. Operator는 Kubernetes 네이티브 방식으로 복잡한 애플리케이션을 자동화하여 관리하는 핵심 기술입니다.

## 🎯 학습 목표

- Kubernetes Operator 패턴의 이해
- CRD (Custom Resource Definition) 개념 학습
- MinIO Operator의 역할과 기능 파악
- Operator 설치 과정과 검증 방법 습득
- 단일/다중 노드 환경별 최적화 방법

## ⏱️ 예상 소요시간
10-15분

## 🔧 사전 준비사항

- Lab 0 완료 (환경 검증)
- kubectl 명령어 도구
- 클러스터 관리자 권한
- 인터넷 연결 (Operator 이미지 다운로드)

---

## Step 1: 사전 요구사항 확인

### 💡 개념 설명
MinIO Operator 설치 전 클러스터 상태를 재확인합니다:

**확인 항목**:
- **클러스터 연결**: kubectl이 정상적으로 클러스터와 통신
- **권한**: Operator 설치에 필요한 클러스터 관리자 권한
- **리소스**: Operator 실행에 필요한 최소 리소스
- **네트워크**: 컨테이너 이미지 다운로드를 위한 인터넷 연결

### 🔍 실행할 명령어
```bash
kubectl cluster-info
```

### ✅ 예상 출력
```
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 📚 출력 정보 해석
- **control plane running**: API 서버가 정상 작동
- **CoreDNS running**: 클러스터 내부 DNS 서비스 정상
- 이 두 서비스가 정상이면 Operator 설치 가능

### 🚨 문제 해결
문제 발생 시 Lab 0으로 돌아가서 환경 재검증을 수행하세요.

### 🛑 체크포인트
클러스터 정보가 정상적으로 출력되는지 확인하세요.

---

## Step 2: 노드 상태 및 환경 유형 확인

### 💡 개념 설명
노드 상태와 환경 유형에 따라 Operator 설치 전략이 달라집니다:

**환경 유형별 특징**:
- **단일 노드**: 간단한 설정, 리소스 효율적, 학습용
- **다중 노드**: 고가용성, 확장성, 프로덕션용

### 🔍 실행할 명령어
```bash
kubectl get nodes -o wide
```

### ✅ 예상 출력

**단일 노드 환경**:
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
minikube   Ready    control-plane   5d    v1.28.3   192.168.49.2  <none>        Ubuntu 22.04.3 LTS   5.15.0-78-generic   docker://24.0.4
```

**다중 노드 환경**:
```
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master-node    Ready    control-plane   5d    v1.28.3   10.0.0.10      <none>        Ubuntu 22.04.3 LTS   5.15.0-78-generic   containerd://1.6.12
worker-node-1  Ready    <none>          5d    v1.28.3   10.0.0.11      <none>        Ubuntu 22.04.3 LTS   5.15.0-78-generic   containerd://1.6.12
worker-node-2  Ready    <none>          5d    v1.28.3   10.0.0.12      <none>        Ubuntu 22.04.3 LTS   5.15.0-78-generic   containerd://1.6.12
```

### 📚 출력 정보 해석
- **STATUS**: 모든 노드가 "Ready" 상태여야 함
- **ROLES**: control-plane(마스터) vs <none>(워커) 구분
- **VERSION**: 모든 노드의 Kubernetes 버전 확인
- **INTERNAL-IP**: 클러스터 내부 통신 주소

### 🔍 환경 유형 판별
```bash
# 노드 수 확인
kubectl get nodes --no-headers | wc -l
```

**결과 해석**:
- **1개**: 단일 노드 환경 → 특별 설정 필요
- **2개 이상**: 다중 노드 환경 → 표준 설정 사용

### 🛑 체크포인트
모든 노드가 "Ready" 상태이고 환경 유형을 파악했는지 확인하세요.

---

## Step 3: Kubernetes Operator 패턴 이해

### 💡 개념 설명

**Operator 패턴이란?**
Kubernetes에서 복잡한 애플리케이션을 자동화하여 관리하는 방법입니다.

**전통적인 방법 vs Operator 패턴**:

| 구분 | 전통적인 방법 | Operator 패턴 |
|------|---------------|---------------|
| **배포** | 수동 YAML 작성 | 선언적 CRD 사용 |
| **관리** | 수동 스크립트 | 자동화된 컨트롤러 |
| **업그레이드** | 수동 절차 | 자동 롤링 업데이트 |
| **장애 복구** | 수동 개입 | 자동 복구 |
| **확장** | 수동 설정 | 자동 스케일링 |

### 🔍 Operator의 핵심 구성 요소

**1. Custom Resource Definition (CRD)**
- Kubernetes API를 확장하는 사용자 정의 리소스
- 애플리케이션별 설정을 Kubernetes 네이티브 방식으로 관리

**2. Controller**
- CRD로 정의된 리소스의 상태를 지속적으로 모니터링
- 원하는 상태(Desired State)와 현재 상태(Current State) 비교
- 차이점 발견 시 자동으로 조정 작업 수행

**3. Operator**
- CRD + Controller + 도메인 지식의 결합
- 애플리케이션 전문가의 운영 지식을 코드로 구현

### 📊 MinIO Operator 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    MinIO Operator                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │    CRDs     │    │ Controller  │    │   Console   │     │
│  │             │    │             │    │             │     │
│  │ • Tenant    │───▶│ • Reconcile │───▶│ • Web UI    │     │
│  │ • Policy    │    │ • Monitor   │    │ • Management│     │
│  │ • User      │    │ • Heal      │    │ • Dashboard │     │
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

### 🔍 MinIO Operator의 주요 기능

**1. 자동화된 배포**
- Tenant 리소스 정의만으로 전체 MinIO 클러스터 배포
- 복잡한 StatefulSet, Service, ConfigMap 자동 생성

**2. 라이프사이클 관리**
- 자동 업그레이드 및 롤백
- 설정 변경 시 자동 재배포
- 장애 시 자동 복구

**3. 스토리지 관리**
- 동적 볼륨 프로비저닝
- Erasure Coding 자동 설정
- 스토리지 확장 자동화

**4. 보안 관리**
- TLS 인증서 자동 생성 및 갱신
- IAM 정책 자동 적용
- 시크릿 자동 관리

### 🛑 체크포인트
Operator 패턴의 개념과 MinIO Operator의 역할을 이해했는지 확인하세요.

---

## Step 4: MinIO Operator 네임스페이스 생성

### 💡 개념 설명
네임스페이스는 Kubernetes 클러스터 내에서 리소스를 논리적으로 분리하는 방법입니다:

**네임스페이스 사용 이유**:
- **격리**: 다른 애플리케이션과 분리
- **보안**: 네임스페이스별 권한 관리
- **관리**: 리소스 그룹화 및 정리
- **멀티테넌시**: 여러 팀/프로젝트 분리

### 🔍 실행할 명령어
```bash
kubectl create namespace minio-operator
```

### ✅ 예상 출력
```
namespace/minio-operator created
```

### 📋 명령어 설명
- `kubectl create namespace`: 새로운 네임스페이스 생성
- `minio-operator`: MinIO Operator 전용 네임스페이스 이름

### 🔍 네임스페이스 확인
```bash
kubectl get namespaces
```

### ✅ 확인 결과
```
NAME              STATUS   AGE
default           Active   5d
kube-node-lease   Active   5d
kube-public       Active   5d
kube-system       Active   5d
minio-operator    Active   10s
```

### 📚 네임스페이스 설명
- **default**: 기본 네임스페이스
- **kube-system**: 시스템 구성 요소
- **kube-public**: 공개 리소스
- **kube-node-lease**: 노드 하트비트
- **minio-operator**: 새로 생성된 MinIO Operator 네임스페이스

### 🛑 체크포인트
minio-operator 네임스페이스가 "Active" 상태로 생성되었는지 확인하세요.

---

## Step 5: MinIO Operator 설치

### 💡 개념 설명
MinIO Operator는 공식 YAML 매니페스트를 통해 설치할 수 있습니다. 이 매니페스트에는 다음이 포함됩니다:

**포함된 리소스**:
- **CRDs**: Tenant, Policy 등의 사용자 정의 리소스
- **RBAC**: 서비스 계정, 역할, 바인딩
- **Deployment**: Operator 컨트롤러 Pod
- **Service**: Operator 웹 콘솔 서비스

### 🔍 실행할 명령어
```bash
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/resources/operator.yaml
```

### ✅ 예상 출력
```
customresourcedefinition.apiextensions.k8s.io/tenants.minio.min.io created
serviceaccount/minio-operator created
clusterrole.rbac.authorization.k8s.io/minio-operator-role created
clusterrolebinding.rbac.authorization.k8s.io/minio-operator-binding created
deployment.apps/minio-operator created
service/minio-operator created
```

### 📚 설치된 리소스 설명

**1. CustomResourceDefinition (CRD)**
```bash
kubectl get crd | grep minio
```
예상 출력:
```
tenants.minio.min.io                          2023-08-10T10:30:00Z
```

**2. ServiceAccount & RBAC**
```bash
kubectl get serviceaccount -n minio-operator
kubectl get clusterrole | grep minio
kubectl get clusterrolebinding | grep minio
```

**3. Deployment**
```bash
kubectl get deployment -n minio-operator
```
예상 출력:
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
minio-operator   1/1     1            1           30s
```

**4. Service**
```bash
kubectl get service -n minio-operator
```
예상 출력:
```
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
minio-operator   ClusterIP   10.96.123.45    <none>        9090/TCP   30s
```

### 🛑 체크포인트
모든 리소스가 성공적으로 생성되었는지 확인하세요.

---

이것은 Lab 01 가이드의 첫 번째 부분입니다. 계속해서 나머지 단계들을 추가하겠습니다.
## Step 6: Operator Pod 상태 확인

### 💡 개념 설명
Operator는 Kubernetes Deployment로 실행되며, 지속적으로 클러스터 상태를 모니터링합니다.

**Pod 상태 확인 중요성**:
- **Running**: Operator가 정상 작동 중
- **Pending**: 스케줄링 대기 (리소스 부족 또는 제약 조건)
- **CrashLoopBackOff**: 반복적인 실패 (설정 오류 또는 권한 문제)

### 🔍 실행할 명령어
```bash
kubectl get pods -n minio-operator
```

### ✅ 예상 출력
```
NAME                              READY   STATUS    RESTARTS   AGE
minio-operator-7d4c8b5f9b-xyz12   1/1     Running   0          2m
```

### 📚 출력 정보 해석
- **READY**: 1/1 (준비된 컨테이너 수 / 전체 컨테이너 수)
- **STATUS**: Running (정상 실행 중)
- **RESTARTS**: 0 (재시작 횟수, 낮을수록 좋음)
- **AGE**: Pod 실행 시간

### 🔍 Pod 상세 정보 확인
```bash
kubectl describe pod -n minio-operator -l name=minio-operator
```

### 📊 주요 확인 사항
- **Events**: Pod 생성 과정의 이벤트 로그
- **Conditions**: Pod 상태 조건
- **Containers**: 컨테이너 상태 및 설정

### 🚨 문제 해결

#### 문제: Pod가 Pending 상태
**원인**: 스케줄링 불가 (리소스 부족, taint, 노드 선택기)

**해결 방법**:
```bash
# Pod 상세 정보 확인
kubectl describe pod -n minio-operator -l name=minio-operator

# 노드 리소스 확인
kubectl top nodes  # metrics-server 필요

# 단일 노드 환경에서 taint 확인
kubectl describe node | grep -i taint
```

#### 문제: Pod가 CrashLoopBackOff 상태
**원인**: 애플리케이션 오류, 권한 문제, 설정 오류

**해결 방법**:
```bash
# Pod 로그 확인
kubectl logs -n minio-operator -l name=minio-operator

# 이전 컨테이너 로그 확인 (재시작된 경우)
kubectl logs -n minio-operator -l name=minio-operator --previous
```

### 🛑 체크포인트
Operator Pod가 "Running" 상태이고 READY가 "1/1"인지 확인하세요.

---

## Step 7: Operator 로그 확인

### 💡 개념 설명
Operator 로그를 통해 설치 상태와 동작을 확인할 수 있습니다:

**로그 확인 목적**:
- **설치 검증**: Operator가 정상적으로 시작되었는지 확인
- **CRD 등록**: 사용자 정의 리소스가 등록되었는지 확인
- **권한 검증**: 필요한 권한이 올바르게 설정되었는지 확인
- **문제 진단**: 오류 발생 시 원인 파악

### 🔍 실행할 명령어
```bash
kubectl logs -n minio-operator -l name=minio-operator --tail=20
```

### ✅ 예상 출력 (정상 상태)
```
2023-08-10T10:30:15.123Z INFO    controller-runtime.metrics      Starting metrics server
2023-08-10T10:30:15.124Z INFO    controller-runtime.builder       Registering a mutating webhook
2023-08-10T10:30:15.125Z INFO    controller-runtime.webhook       Starting webhook server
2023-08-10T10:30:15.126Z INFO    controller-runtime.certwatcher   Updated current TLS certificate
2023-08-10T10:30:15.127Z INFO    controller-runtime.webhook       Serving webhook server
2023-08-10T10:30:15.128Z INFO    controller-runtime.manager       Starting manager
2023-08-10T10:30:15.129Z INFO    Starting EventSource             controller=tenant
2023-08-10T10:30:15.130Z INFO    Starting Controller              controller=tenant
2023-08-10T10:30:15.131Z INFO    Starting workers                 controller=tenant worker count=1
```

### 📚 로그 메시지 해석
- **metrics server**: 모니터링 메트릭 서버 시작
- **webhook**: 검증 및 변형 웹훅 서버 시작
- **manager**: 컨트롤러 매니저 시작
- **EventSource**: 이벤트 소스 시작 (Tenant 리소스 감시)
- **Controller**: Tenant 컨트롤러 시작
- **workers**: 워커 프로세스 시작

### 🔍 실시간 로그 모니터링
```bash
kubectl logs -n minio-operator -l name=minio-operator -f
```

**참고**: `-f` 옵션으로 실시간 로그 스트리밍 (Ctrl+C로 종료)

### 🚨 문제 해결

#### 문제: 권한 관련 오류
**로그 예시**:
```
ERROR   controller-runtime.manager  unable to create controller: failed to create client: Unauthorized
```

**해결 방법**:
```bash
# RBAC 설정 확인
kubectl get clusterrolebinding | grep minio-operator
kubectl describe clusterrolebinding minio-operator-binding
```

#### 문제: CRD 등록 실패
**로그 예시**:
```
ERROR   controller-runtime.builder  unable to register CRD: customresourcedefinitions.apiextensions.k8s.io is forbidden
```

**해결 방법**:
```bash
# CRD 상태 확인
kubectl get crd | grep minio
kubectl describe crd tenants.minio.min.io
```

### 🛑 체크포인트
로그에서 오류 메시지 없이 "Starting workers" 메시지가 표시되는지 확인하세요.

---

## Step 8: CRD (Custom Resource Definition) 확인

### 💡 개념 설명
CRD는 Kubernetes API를 확장하여 사용자 정의 리소스를 생성할 수 있게 해줍니다:

**MinIO Operator CRDs**:
- **Tenant**: MinIO 클러스터 인스턴스 정의
- **Policy**: IAM 정책 정의 (선택적)
- **User**: IAM 사용자 정의 (선택적)

### 🔍 실행할 명령어
```bash
kubectl get crd | grep minio
```

### ✅ 예상 출력
```
tenants.minio.min.io                          2023-08-10T10:30:00Z
```

### 📋 CRD 상세 정보 확인
```bash
kubectl describe crd tenants.minio.min.io
```

### 📚 CRD 구조 이해

**Tenant CRD 주요 필드**:
```yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: my-tenant
spec:
  image: minio/minio:RELEASE.2023-08-04T17-40-21Z
  pools:
  - servers: 4
    volumesPerServer: 4
    volumeClaimTemplate:
      spec:
        accessModes: [ "ReadWriteOnce" ]
        resources:
          requests:
            storage: 10Gi
```

### 🔍 CRD API 버전 확인
```bash
kubectl api-resources | grep minio
```

### ✅ 예상 출력
```
tenants       tenant    minio.min.io/v2    true    Tenant
```

### 📚 출력 정보 해석
- **NAME**: 리소스 이름 (tenants)
- **SHORTNAMES**: 축약 이름 (tenant)
- **APIVERSION**: API 버전 (minio.min.io/v2)
- **NAMESPACED**: 네임스페이스 범위 (true)
- **KIND**: 리소스 종류 (Tenant)

### 🛑 체크포인트
Tenant CRD가 정상적으로 등록되었는지 확인하세요.

---

## Step 9: Operator 웹 콘솔 접근 설정

### 💡 개념 설명
MinIO Operator는 웹 기반 관리 콘솔을 제공합니다:

**웹 콘솔 기능**:
- **Tenant 관리**: 생성, 수정, 삭제
- **모니터링**: 상태, 메트릭, 로그 확인
- **사용자 관리**: IAM 사용자 및 정책 관리
- **설정 관리**: 구성 변경 및 업데이트

### 🔍 Operator 서비스 확인
```bash
kubectl get service -n minio-operator
```

### ✅ 예상 출력
```
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
minio-operator   ClusterIP   10.96.123.45    <none>        9090/TCP   5m
```

### 📋 포트 포워딩 설정
```bash
kubectl port-forward -n minio-operator svc/minio-operator 9090:9090 &
```

### ✅ 포트 포워딩 확인
```
Forwarding from 127.0.0.1:9090 -> 9090
Forwarding from [::1]:9090 -> 9090
```

### 🌐 웹 콘솔 접근
브라우저에서 다음 주소로 접근:
```
http://localhost:9090
```

### 📚 웹 콘솔 초기 화면
- **로그인 페이지**: JWT 토큰 또는 서비스 계정 토큰 필요
- **대시보드**: Tenant 목록 및 상태
- **생성 마법사**: 새 Tenant 생성 인터페이스

### 🔑 서비스 계정 토큰 생성 (웹 콘솔 로그인용)
```bash
# 서비스 계정 토큰 시크릿 생성
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-operator-token
  namespace: minio-operator
  annotations:
    kubernetes.io/service-account.name: minio-operator
type: kubernetes.io/service-account-token
EOF
```

### 🔍 토큰 추출
```bash
kubectl get secret minio-operator-token -n minio-operator -o jsonpath='{.data.token}' | base64 -d
```

### 📋 토큰 사용법
1. 웹 콘솔 접근 (http://localhost:9090)
2. "Login with Service Account" 선택
3. 추출한 토큰 입력
4. "Login" 클릭

### 🛑 체크포인트
웹 콘솔에 성공적으로 접근하고 로그인할 수 있는지 확인하세요.

---

## Step 10: 단일 노드 환경 최적화 (해당하는 경우)

### 💡 개념 설명
단일 노드 환경에서는 추가 최적화가 필요할 수 있습니다:

**최적화 항목**:
- **Taint 제거**: control-plane 노드에서 Pod 스케줄링 허용
- **리소스 제한**: 메모리 및 CPU 사용량 조정
- **스토리지 설정**: 로컬 스토리지 최적화

### 🔍 현재 노드 수 확인
```bash
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "노드 수: $NODE_COUNT"
```

### 🔧 단일 노드 환경 최적화 (NODE_COUNT=1인 경우만)

#### Taint 확인
```bash
kubectl describe node | grep -i taint
```

#### Taint 제거 (필요한 경우)
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

#### 제거 확인
```bash
kubectl describe node | grep -i taint
```

**성공 시 출력**: `Taints: <none>`

### ⚠️ 주의사항
- **단일 노드 환경에서만** taint 제거
- **다중 노드 환경에서는 제거하지 마세요**
- 프로덕션 환경에서는 control-plane 보호가 중요

### 🛑 체크포인트
단일 노드 환경인 경우 taint가 적절히 처리되었는지 확인하세요.

---

## 🎯 설치 검증 및 최종 확인

### 🔍 종합 상태 확인
```bash
echo "=== MinIO Operator 설치 상태 확인 ==="
echo ""

echo "1. 네임스페이스:"
kubectl get namespace minio-operator

echo -e "\n2. CRD 등록:"
kubectl get crd | grep minio

echo -e "\n3. Operator Pod:"
kubectl get pods -n minio-operator

echo -e "\n4. Operator 서비스:"
kubectl get service -n minio-operator

echo -e "\n5. RBAC 설정:"
kubectl get clusterrolebinding | grep minio-operator
```

### ✅ 성공 기준 체크리스트

- [ ] **네임스페이스**: minio-operator가 Active 상태
- [ ] **CRD**: tenants.minio.min.io가 등록됨
- [ ] **Pod**: minio-operator Pod가 Running 상태
- [ ] **서비스**: minio-operator 서비스가 생성됨
- [ ] **RBAC**: 클러스터 역할 바인딩이 설정됨
- [ ] **로그**: 오류 없이 정상 시작 메시지 확인
- [ ] **웹 콘솔**: 포트 포워딩으로 접근 가능

### 🚨 문제 해결 요약

| 문제 | 증상 | 해결 방법 |
|------|------|-----------|
| Pod Pending | 스케줄링 불가 | taint 제거, 리소스 확인 |
| CrashLoopBackOff | 반복 재시작 | 로그 확인, 권한 검증 |
| CRD 등록 실패 | API 리소스 없음 | 클러스터 권한 확인 |
| 웹 콘솔 접근 불가 | 연결 실패 | 포트 포워딩 재설정 |
| 권한 오류 | Unauthorized | RBAC 설정 확인 |

---

## 🧠 학습 성과 확인

### 📋 이해도 점검 질문

1. **Operator 패턴의 장점을 3가지 이상 설명할 수 있나요?**
2. **CRD가 무엇이고 왜 필요한지 이해했나요?**
3. **MinIO Operator가 관리하는 주요 리소스들을 나열할 수 있나요?**
4. **단일 노드 환경에서 taint 제거가 필요한 이유를 알고 있나요?**
5. **Operator 웹 콘솔의 주요 기능들을 설명할 수 있나요?**

### 🎓 핵심 개념 정리

**Operator 패턴**:
- 복잡한 애플리케이션의 자동화된 관리
- CRD + Controller + 도메인 지식의 결합
- 선언적 설정을 통한 라이프사이클 관리

**MinIO Operator**:
- MinIO 클러스터의 Kubernetes 네이티브 관리
- Tenant 리소스를 통한 선언적 배포
- 자동화된 스케일링, 업그레이드, 복구

**CRD (Custom Resource Definition)**:
- Kubernetes API 확장 메커니즘
- 애플리케이션별 리소스 정의
- kubectl로 네이티브 리소스처럼 관리

---

## 🚀 다음 단계

MinIO Operator 설치가 완료되었습니다! 이제 실제 MinIO Tenant를 배포할 준비가 되었습니다.

**Lab 2: MinIO Tenant 배포**에서 학습할 내용:
- Tenant 리소스 정의 및 배포
- 실시간 동적 프로비저닝 관찰
- StatefulSet과 PVC 관계 이해
- Erasure Coding 설정 및 검증

### 🔗 관련 문서
- [Lab 2 가이드: MinIO Tenant 배포](LAB-02-GUIDE.md)
- [Operator 패턴 상세 개념](LAB-01-CONCEPTS.md)
- [MinIO 공식 Operator 문서](https://docs.min.io/minio/k8s/)

### 🧹 정리 명령어 (필요한 경우)
```bash
# Operator 제거 (다음 Lab 진행 전에는 실행하지 마세요)
kubectl delete -f https://raw.githubusercontent.com/minio/operator/master/resources/operator.yaml
kubectl delete namespace minio-operator
```

---

축하합니다! MinIO Operator가 성공적으로 설치되었습니다. 이제 Kubernetes 클러스터에서 MinIO를 네이티브 방식으로 관리할 수 있는 기반이 마련되었습니다.
