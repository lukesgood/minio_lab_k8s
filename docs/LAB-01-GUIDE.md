# Lab 1: MinIO Operator 설치 - Lab Guide

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

## Step 1: 클러스터 연결 확인

### 💡 개념 설명
MinIO Operator 설치 전 클러스터 상태를 재확인합니다.

### 🔍 실행할 명령어
```bash
kubectl cluster-info
```

### ✅ 예상 출력
```
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 🛑 체크포인트
클러스터 연결이 정상적으로 작동하는지 확인하세요.

---

## Step 2: 노드 상태 확인

### 💡 개념 설명
Operator 배포 전 노드 상태와 환경 유형을 파악합니다.

### 🔍 실행할 명령어
```bash
kubectl get nodes
```

### ✅ 예상 출력
**단일 노드 환경:**
```
NAME          STATUS   ROLES           AGE     VERSION
luke-870z5g   Ready    control-plane   2d23h   v1.28.15
```

**다중 노드 환경:**
```
NAME       STATUS   ROLES           AGE   VERSION
master     Ready    control-plane   1d    v1.28.15
worker-1   Ready    <none>          1d    v1.28.15
worker-2   Ready    <none>          1d    v1.28.15
```

### 📚 환경 유형 판단
- **1개 노드**: 단일 노드 환경 → Anti-Affinity 조정 필요
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
│  Controller (Deployment)                                   │
│  ├── Tenant CRD 관리                                       │
│  ├── 자동 스케일링                                         │
│  ├── 업그레이드 관리                                       │
│  └── 장애 복구                                             │
├─────────────────────────────────────────────────────────────┤
│  Services                                                   │
│  ├── operator (4221/TCP) - 내부 API                       │
│  └── sts (4223/TCP) - Security Token Service              │
└─────────────────────────────────────────────────────────────┘
```

---

## Step 4: MinIO Operator 설치

### 💡 개념 설명
MinIO Operator는 kustomize를 통해 설치할 수 있습니다. 이 방법은 모든 필수 리소스를 자동으로 설치합니다.

**자동 설치되는 리소스**:
- **네임스페이스**: minio-operator 자동 생성
- **CRDs**: Tenant, Policy 등의 사용자 정의 리소스
- **RBAC**: 서비스 계정, 역할, 바인딩
- **Deployment**: Operator 컨트롤러 Pod
- **Service**: Operator API 및 STS 서비스

### 🔍 실행할 명령어
```bash
# 공식 MinIO Operator v7.1.1 설치 (GitHub 공식 방법)
kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
```

### ✅ 예상 출력
```
namespace/minio-operator created
customresourcedefinition.apiextensions.k8s.io/policybindings.sts.min.io created
customresourcedefinition.apiextensions.k8s.io/tenants.minio.min.io created
serviceaccount/minio-operator created
clusterrole.rbac.authorization.k8s.io/minio-operator-role created
clusterrolebinding.rbac.authorization.k8s.io/minio-operator-binding created
service/operator created
service/sts created
deployment.apps/minio-operator created
```

### 📚 설치 방법 설명

**공식 GitHub 기준 설치**:
- **공식 릴리스**: v7.1.1 (GitHub 공식 최신 버전)
- **공식 방법**: GitHub README.md에 명시된 정확한 설치 방법
- **검증된 설정**: 공식 테스트를 거친 구성
- **자동 네임스페이스**: minio-operator 네임스페이스 자동 생성
- **완전한 설치**: 모든 필수 리소스 포함

**실제 설치되는 이미지 버전**:
- **공식 릴리스 태그**: v7.1.1 (GitHub 공식)
- **실제 컨테이너 이미지**: minio/operator:v7.1.1
- **일치성**: 태그와 컨테이너 이미지가 완전히 일치

**버전 확인 방법**:
```bash
# 설치 후 실제 이미지 확인
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
# 출력: minio/operator:v7.1.1
```

### ⚠️ 중요 참고사항
- **이전 URL 사용 금지**: `https://raw.githubusercontent.com/minio/operator/master/resources/operator.yaml`은 더 이상 사용할 수 없습니다
- **kustomize 필수**: Kubernetes 1.14+ 버전에서 기본 제공되는 kustomize를 사용합니다
- **단일 노드 환경**: 설치 후 replica 조정이 필요할 수 있습니다

### 🛑 체크포인트
모든 리소스가 성공적으로 생성되었는지 확인하세요.

---

## Step 5: Operator 배포 상태 확인

### 💡 개념 설명
Operator는 Kubernetes Deployment로 실행되며, 지속적으로 클러스터 상태를 모니터링합니다.

### 🔍 실행할 명령어
```bash
kubectl get deployment -n minio-operator
```

### ✅ 예상 출력
**다중 노드 환경:**
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
minio-operator   2/2     2            2           2m
```

**단일 노드 환경 (초기):**
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
minio-operator   1/2     2            1           2m
```

### 📚 출력 정보 해석
- **READY**: 준비된 Pod 수 / 원하는 Pod 수
- **UP-TO-DATE**: 최신 버전으로 업데이트된 Pod 수
- **AVAILABLE**: 사용 가능한 Pod 수
- **AGE**: Deployment 생성 시간

### 🚨 단일 노드 환경 문제 해결

**증상**: `1/2 Ready` 상태로 표시되는 경우

**원인**: Pod Anti-Affinity 규칙으로 인해 같은 노드에 두 개의 Pod를 배치할 수 없음

**해결 방법**:
```bash
# 단일 노드 환경에서는 replica를 1로 조정
kubectl scale deployment minio-operator -n minio-operator --replicas=1
```

**해결 후 예상 출력:**
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
minio-operator   1/1     1            1           3m
```

### 🛑 체크포인트
Deployment가 `1/1 Ready` 상태인지 확인하세요.

---

## Step 6: Operator Pod 상태 확인

### 💡 개념 설명
Pod 상태를 통해 Operator의 실제 실행 상태를 확인합니다.

### 🔍 실행할 명령어
```bash
kubectl get pods -n minio-operator
```

### ✅ 예상 출력
```
NAME                              READY   STATUS    RESTARTS   AGE
minio-operator-784dc55945-l2nqm   1/1     Running   0          3m
```

### 📚 출력 정보 해석
- **READY**: 1/1 (준비된 컨테이너 수 / 전체 컨테이너 수)
- **STATUS**: Running (정상 실행 중)
- **RESTARTS**: 0 (재시작 횟수, 낮을수록 좋음)
- **AGE**: Pod 실행 시간

### 🔍 Pod 상세 정보 확인 (문제 발생 시)
```bash
kubectl describe pod -n minio-operator -l name=minio-operator
```

### 🛑 체크포인트
Pod가 `Running` 상태이고 재시작 횟수가 0인지 확인하세요.

---

## Step 7: Operator 서비스 확인

### 💡 개념 설명
MinIO Operator는 두 개의 서비스를 제공합니다.

### 🔍 실행할 명령어
```bash
kubectl get svc -n minio-operator
```

### ✅ 예상 출력
```
NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
operator   ClusterIP   10.109.26.96   <none>        4221/TCP   5m
sts        ClusterIP   10.110.16.37   <none>        4223/TCP   5m
```

### 📚 서비스 설명
- **operator (4221/TCP)**: Operator API 서버 (내부 관리용)
- **sts (4223/TCP)**: Security Token Service (인증 관리)

### 🔍 서비스 연결 상태 확인
```bash
kubectl get endpoints -n minio-operator
```

### ✅ 예상 출력
```
NAME       ENDPOINTS          AGE
operator   10.244.0.61:4221   5m
sts        10.244.0.61:4223   5m
```

### 📚 결과 해석
- **ENDPOINTS 존재**: Operator Pod가 정상적으로 서비스에 연결됨
- **IP:PORT 표시**: 내부 네트워크에서 API 서버 접근 가능

### 🛑 체크포인트
두 서비스 모두 엔드포인트가 정상적으로 설정되었는지 확인하세요.

---

## Step 8: CRD (Custom Resource Definition) 확인

### 💡 개념 설명
MinIO Operator는 Tenant라는 사용자 정의 리소스를 제공합니다.

### 🔍 실행할 명령어
```bash
kubectl get crd | grep minio
```

### ✅ 예상 출력
```
tenants.minio.min.io        2025-08-11T04:34:03Z
```

### 📚 CRD 상세 정보 확인
```bash
kubectl api-resources | grep minio
```

### ✅ 예상 출력
```
tenants       tenant    minio.min.io/v2    true    Tenant
```

### 🔍 추가 CRD 확인
MinIO Operator는 추가로 STS 관련 CRD도 생성합니다:
```bash
kubectl get crd | grep -E "(minio|sts)"
```

### ✅ 전체 CRD 출력
```
policybindings.sts.min.io   2025-08-11T04:34:03Z
tenants.minio.min.io        2025-08-11T04:34:03Z
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

## Step 9: Operator 로그 확인

### 💡 개념 설명
Operator 로그를 통해 정상 작동 여부를 최종 확인합니다.

### 🔍 실행할 명령어
```bash
kubectl logs -n minio-operator -l name=minio-operator --tail=10
```

### ✅ 예상 출력 (예시)
```
I0811 03:49:21.351690       1 main-controller.go:577] minio-operator-xxx: I am the leader
I0811 03:49:21.351825       1 main-controller.go:432] Starting Tenant controller
I0811 03:49:21.351834       1 main-controller.go:435] Waiting for informer caches to sync
I0811 03:49:22.252375       1 main-controller.go:456] STS Autocert is enabled
I0811 03:49:27.578188       1 tls.go:130] Waiting for the sts certificates to be issued
```

### 📚 로그 해석
- **Leader election**: Operator가 리더로 선출됨
- **Tenant controller**: Tenant 관리 컨트롤러 시작
- **STS Autocert**: 자동 인증서 설정 활성화
- **오류 없음**: ERROR나 FATAL 메시지가 없어야 함

### 🛑 체크포인트
로그에 오류 메시지가 없고 정상적인 시작 메시지가 보이는지 확인하세요.

---

## Step 10: 설치 완료 종합 확인

### 💡 개념 설명
모든 구성 요소가 정상적으로 설치되고 작동하는지 종합적으로 확인합니다.

### 🔍 실행할 명령어
```bash
echo "=== MinIO Operator 설치 완료 확인 ==="
echo ""
echo "1. Deployment 상태:"
kubectl get deployment -n minio-operator
echo ""
echo "2. Pod 상태:"
kubectl get pods -n minio-operator
echo ""
echo "3. 서비스 상태:"
kubectl get svc -n minio-operator
echo ""
echo "4. CRD 등록 상태:"
kubectl get crd | grep minio
echo ""
echo "5. 네임스페이스 상태:"
kubectl get ns minio-operator
```

### ✅ 설치 완료 기준
다음 조건들이 모두 만족되면 LAB-01이 성공적으로 완료된 것입니다:

- ✅ **Namespace**: `minio-operator Active`
- ✅ **Deployment**: `minio-operator 1/1 Ready` (단일 노드) 또는 `2/2 Ready` (다중 노드)
- ✅ **Pod**: `Running` 상태, 재시작 횟수 0
- ✅ **Services**: `operator`, `sts` 서비스 생성됨
- ✅ **CRDs**: `tenants.minio.min.io`, `policybindings.sts.min.io` 등록됨
- ✅ **Container Image**: `minio/operator:v7.1.1` 실행 중 (공식 버전)

### 🔍 실제 컨테이너 이미지 확인
```bash
kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### ✅ 예상 출력
```
minio/operator:v7.1.1
```

### 📚 공식 GitHub 기준 확인
- **설치 방법**: GitHub 공식 README.md 기준
- **버전 일치**: 릴리스 태그와 컨테이너 이미지 완전 일치
- **정상 동작**: 모든 구성 요소가 공식 사양대로 작동

---

## 🎉 LAB-01 완료!

### 🎯 학습 성과

**이론적 이해:**
- ✅ Kubernetes Operator 패턴 이해
- ✅ CRD와 Controller의 역할 파악
- ✅ MinIO Operator 아키텍처 이해

**실무 기술:**
- ✅ kustomize를 통한 Operator 설치
- ✅ kubectl을 통한 리소스 상태 확인
- ✅ 단일 노드 환경 최적화 경험
- ✅ 트러블슈팅 기술 습득

### 🚀 다음 단계

MinIO Operator 설치가 완료되었습니다! 이제 다음 단계로 진행할 수 있습니다:

**LAB-02: MinIO Tenant 배포**
- MinIO 스토리지 클러스터 생성
- 실시간 동적 프로비저닝 관찰
- MinIO 웹 콘솔 접근 (실제 웹 UI 사용 가능!)

**LAB-03: MinIO Client 설정**
- 명령줄 도구를 통한 관리
- S3 호환 API 사용법

### 💡 관리 방법 안내

**현재 사용 가능한 관리 방법:**
- **kubectl**: Tenant 리소스 관리
- **로그 확인**: Operator 상태 모니터링

**LAB-02 완료 후 추가 가능:**
- **MinIO Tenant 웹 콘솔**: 완전한 웹 기반 관리 인터페이스
- **MinIO Client (mc)**: 명령줄 관리 도구

---

**다음 Lab 시작:**
```bash
cat docs/LAB-02-GUIDE.md
```

---

## 🧹 LAB-01 정리 (선택사항)

### 💡 언제 사용하나요?
- LAB-01을 다시 처음부터 테스트하고 싶을 때
- 설치 과정에서 문제가 발생하여 깨끗하게 재시작하고 싶을 때
- 다른 버전의 MinIO Operator를 테스트하고 싶을 때

### 🔍 완전 삭제 명령어
```bash
# 1. MinIO Operator 네임스페이스 삭제 (모든 리소스 포함)
kubectl delete namespace minio-operator

# 2. CRDs 삭제
kubectl delete crd tenants.minio.min.io
kubectl delete crd policybindings.sts.min.io

# 3. ClusterRole 삭제
kubectl delete clusterrole minio-operator-role

# 4. ClusterRoleBinding 삭제
kubectl delete clusterrolebinding minio-operator-binding
```

### ✅ 삭제 확인
```bash
echo "=== MinIO Operator 삭제 확인 ==="
kubectl get ns | grep minio || echo "✅ 네임스페이스 삭제됨"
kubectl get crd | grep -E "(minio|sts)" || echo "✅ CRDs 삭제됨"
kubectl get clusterrole | grep minio || echo "✅ ClusterRole 삭제됨"
kubectl get clusterrolebinding | grep minio || echo "✅ ClusterRoleBinding 삭제됨"
```

### ⚠️ 주의사항
- 이 명령어들은 MinIO Operator와 관련된 모든 설정을 삭제합니다
- 삭제 후에는 LAB-01부터 다시 시작해야 합니다
- 실제 운영 환경에서는 신중하게 사용하세요

---

## 📚 참고 자료

- [MinIO Operator 공식 문서](https://min.io/docs/minio/kubernetes/upstream/)
- [Kubernetes Operator 패턴](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Custom Resource Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
