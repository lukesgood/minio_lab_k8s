# Lab 0: 환경 사전 검증 - Lab Guide

## 📚 개요

이 실습에서는 MinIO 배포를 위한 Kubernetes 환경을 체계적으로 검증합니다. 동적 프로비저닝의 핵심 개념과 WaitForFirstConsumer 동작 원리를 실제로 관찰하며 학습합니다.

## 🎯 학습 목표

- Kubernetes 클러스터 연결 및 상태 확인
- 스토리지 프로비저너 동작 원리 이해
- 동적 vs 정적 프로비저닝 개념 학습
- PV/PVC 생성 과정 실제 관찰
- 환경별 최적화 방법 습득

## ⏱️ 예상 소요시간
5-10분

## 🔧 사전 준비사항

- Kubernetes 클러스터 (Minikube, Kind, K3s, 또는 실제 클러스터)
- kubectl 명령어 도구
- 터미널 접근 권한

---

## Step 1: kubectl 설치 및 버전 확인

### 💡 개념 설명
kubectl은 Kubernetes 클러스터와 통신하는 명령줄 도구입니다:
- **클러스터 상태 확인**: 노드, Pod, 서비스 등의 상태 모니터링
- **리소스 관리**: 생성, 수정, 삭제 작업
- **애플리케이션 배포**: YAML 파일을 통한 선언적 배포
- **디버깅**: 로그 확인, 문제 진단

### 🔍 실행할 명령어
```bash
kubectl version --client
```

### 📋 명령어 설명
- `kubectl version`: kubectl과 클러스터의 버전 정보 확인
- `--client`: 클라이언트(kubectl) 버전만 표시 (클러스터 연결 불필요)

### ✅ 예상 출력
```
Client Version: version.Info{Major:"1", Minor:"28", GitVersion:"v1.28.2", GitCommit:"89a4ea3e1e4ddd7f7572286090359983e0387b2f", GitTreeState:"clean", BuildDate:"2023-09-13T09:35:06Z", GoVersion:"go1.20.8", Compiler:"gc", Platform:"linux/amd64"}
```

### 📚 출력 정보 해석
- **Major/Minor**: Kubernetes API 버전 (1.28)
- **GitVersion**: 정확한 릴리스 버전 (v1.28.2)
- **BuildDate**: 빌드 날짜
- **Platform**: 운영체제 및 아키텍처

### 🚨 문제 해결

#### 문제: "kubectl: command not found"
**원인**: kubectl이 설치되지 않음

**해결 방법**:
```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl

# Windows
choco install kubernetes-cli
```

### 🛑 체크포인트
kubectl 버전 정보가 정상적으로 출력되었는지 확인하세요. 다음 단계로 진행하기 전에 kubectl이 정상 작동하는지 검증이 완료되어야 합니다.

---

## Step 2: Kubernetes 클러스터 연결 확인

### 💡 개념 설명
Kubernetes 클러스터는 여러 구성 요소로 이루어져 있습니다:

- **API Server**: 클러스터의 '뇌' 역할, 모든 REST API 요청 처리
- **etcd**: 클러스터 상태 정보를 저장하는 분산 키-값 데이터베이스
- **CoreDNS**: 클러스터 내부 서비스 이름 해석 (Service Discovery)
- **Controller Manager**: 다양한 컨트롤러들을 관리
- **Scheduler**: Pod를 적절한 노드에 배치

### 🔍 실행할 명령어
```bash
kubectl cluster-info
```

### 📋 명령어 설명
- `kubectl cluster-info`: 클러스터의 주요 구성 요소 엔드포인트 정보 표시
- 클러스터와의 연결 상태를 확인하는 가장 기본적인 명령어

### ✅ 예상 출력
```
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### 📚 출력 정보 해석
- **control plane**: API 서버의 주소 (클러스터 접근점)
- **CoreDNS**: 클러스터 내부 DNS 서비스 엔드포인트
- **포트 6443**: Kubernetes API 서버의 기본 HTTPS 포트

### 🚨 문제 해결

#### 문제: "The connection to the server localhost:8080 was refused"
**원인**: kubeconfig 파일이 설정되지 않음

**해결 방법**:
```bash
# kubeconfig 파일 위치 확인
ls -la ~/.kube/config

# Minikube 사용 시
minikube start

# K3s 사용 시
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

#### 문제: "Unable to connect to the server"
**원인**: 클러스터가 실행되지 않거나 네트워크 문제

**해결 방법**:
```bash
# 클러스터 상태 확인
systemctl status kubelet  # 일반 클러스터
minikube status           # Minikube
k3s check-config          # K3s

# 클러스터 재시작
minikube start            # Minikube
sudo systemctl restart k3s  # K3s
```

### 🛑 체크포인트
클러스터 정보가 정상적으로 출력되고 "control plane is running" 메시지가 표시되는지 확인하세요.

---

## Step 3: 클러스터 노드 상태 확인

### 💡 개념 설명
Kubernetes 노드는 실제 워크로드가 실행되는 물리적 또는 가상 머신입니다:

**노드 유형**:
- **Control-plane**: 클러스터 관리 기능 (API 서버, etcd, 스케줄러 등)
- **Worker nodes**: 실제 애플리케이션 Pod가 실행되는 노드

**환경 유형**:
- **Single-node**: 하나의 노드가 모든 역할 담당 (학습/개발용)
- **Multi-node**: 역할이 분리된 프로덕션 환경

### 🔍 실행할 명령어
```bash
kubectl get nodes
```

### 📋 명령어 설명
- `kubectl get nodes`: 클러스터의 모든 노드 목록과 상태 표시
- 노드의 역할, 상태, 버전 정보 확인 가능

### ✅ 예상 출력

**단일 노드 환경**:
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5d    v1.28.3
```

**다중 노드 환경**:
```
NAME           STATUS   ROLES           AGE   VERSION
master-node    Ready    control-plane   5d    v1.28.3
worker-node-1  Ready    <none>          5d    v1.28.3
worker-node-2  Ready    <none>          5d    v1.28.3
```

### 📚 출력 정보 해석
- **NAME**: 노드 이름 (호스트명 또는 설정된 이름)
- **STATUS**: 
  - `Ready`: 노드가 정상 작동 중
  - `NotReady`: 노드에 문제 발생
- **ROLES**: 
  - `control-plane`: 마스터 노드 (클러스터 관리)
  - `<none>`: 워커 노드 (애플리케이션 실행)
- **AGE**: 노드가 클러스터에 조인된 시간
- **VERSION**: 해당 노드의 kubelet 버전

### 🔍 환경 유형 판별

#### 단일 노드 클러스터 특징
- **장점**: 
  - 리소스 요구사항 낮음
  - 설정 간단
  - 학습 및 개발에 적합
- **단점**: 
  - 고가용성 없음
  - 확장성 제한
  - 프로덕션 부적합

#### 다중 노드 클러스터 특징
- **장점**: 
  - 고가용성 제공
  - 확장성 우수
  - 프로덕션 환경 적합
- **단점**: 
  - 복잡한 설정
  - 높은 리소스 요구사항
  - 네트워크 설정 복잡

### 🚨 문제 해결

#### 문제: 노드 상태가 "NotReady"
**원인**: kubelet 서비스 문제, 네트워크 문제, 리소스 부족

**해결 방법**:
```bash
# 노드 상세 정보 확인
kubectl describe node <node-name>

# kubelet 로그 확인
journalctl -u kubelet -f

# kubelet 재시작
sudo systemctl restart kubelet
```

### 🛑 체크포인트
모든 노드의 STATUS가 "Ready" 상태인지 확인하고, 환경 유형(단일/다중 노드)을 파악하세요.

---

## Step 4: 스토리지 클래스 확인

### 💡 개념 설명
스토리지 클래스는 동적 프로비저닝의 핵심 구성 요소입니다:

**동적 프로비저닝**:
- PVC 생성 시 자동으로 PV 생성
- 스토리지 프로비저너가 실제 스토리지 할당
- 개발자는 스토리지 세부사항을 몰라도 됨

**정적 프로비저닝**:
- 관리자가 미리 PV 생성
- PVC가 기존 PV와 바인딩
- 수동 관리 필요

### 🔍 실행할 명령어
```bash
kubectl get storageclass
```

### 📋 명령어 설명
- `kubectl get storageclass`: 클러스터에 설정된 스토리지 클래스 목록 표시
- 동적 프로비저닝 가능 여부 확인

### ✅ 예상 출력

**스토리지 클래스가 있는 경우**:
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default) rancher.io/local-path      Delete          WaitForFirstConsumer   false                  5d
```

**스토리지 클래스가 없는 경우**:
```
No resources found
```

### 📚 출력 정보 해석
- **NAME**: 스토리지 클래스 이름
- **(default)**: 기본 스토리지 클래스 표시
- **PROVISIONER**: 스토리지 프로비저너 (실제 스토리지 생성 담당)
- **RECLAIMPOLICY**: PV 삭제 정책
  - `Delete`: PVC 삭제 시 PV도 삭제
  - `Retain`: PVC 삭제 후에도 PV 유지
- **VOLUMEBINDINGMODE**: 볼륨 바인딩 모드
  - `Immediate`: PVC 생성 즉시 PV 생성
  - `WaitForFirstConsumer`: Pod가 PVC 사용할 때까지 대기
- **ALLOWVOLUMEEXPANSION**: 볼륨 확장 허용 여부

### 🔍 WaitForFirstConsumer 동작 원리

이 모드는 MinIO 배포에서 중요한 개념입니다:

1. **PVC 생성**: PV가 즉시 생성되지 않음 (Pending 상태)
2. **Pod 스케줄링**: Pod가 특정 노드에 배치될 때
3. **PV 생성**: 해당 노드에 PV 생성 및 바인딩
4. **최적화**: 노드 로컬 스토리지 활용으로 성능 향상

### 🚨 문제 해결

#### 문제: "No resources found" (스토리지 클래스 없음)
**원인**: 동적 프로비저닝을 위한 스토리지 클래스 미설정

**해결 방법**:

**Local Path Provisioner 설치** (단일 노드 권장):
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

**기본 스토리지 클래스 설정**:
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**설치 확인**:
```bash
kubectl get storageclass
kubectl get pods -n local-path-storage
```

### 🛑 체크포인트
스토리지 클래스가 존재하고 "(default)" 표시가 있는지 확인하세요. 이는 동적 프로비저닝의 전제 조건입니다.

---

## Step 5: 동적 프로비저닝 테스트

### 💡 개념 설명
실제 PVC를 생성하여 동적 프로비저닝 과정을 관찰합니다. 이는 MinIO Tenant 배포 시 일어나는 과정과 동일합니다.

### 🔍 실행할 명령어

**테스트 PVC 생성**:
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

### 📋 YAML 파일 설명
- **apiVersion**: PVC API 버전
- **kind**: 리소스 유형 (PersistentVolumeClaim)
- **metadata**: 메타데이터 (이름, 네임스페이스)
- **spec**: PVC 사양
  - **accessModes**: 접근 모드 (ReadWriteOnce = 단일 노드 읽기/쓰기)
  - **resources**: 요청 스토리지 크기

### ✅ PVC 상태 확인
```bash
kubectl get pvc test-pvc
```

**WaitForFirstConsumer 모드에서의 예상 출력**:
```
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc   Pending   -        -          -              local-path     10s
```

### 📚 상태 해석
- **STATUS: Pending**: 정상 상태 (WaitForFirstConsumer 모드)
- **VOLUME: -**: 아직 PV가 생성되지 않음
- 이는 오류가 아닌 설계된 동작입니다!

### 🔍 테스트 Pod 생성으로 프로비저닝 트리거
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
EOF
```

### ✅ 동적 프로비저닝 관찰
```bash
# PVC 상태 재확인
kubectl get pvc test-pvc

# PV 자동 생성 확인
kubectl get pv

# Pod 상태 확인
kubectl get pod test-pod
```

**프로비저닝 완료 후 예상 출력**:
```
# PVC 상태
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc   Bound    pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO            local-path     2m

# PV 상태
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS   REASON   AGE
pvc-12345678-1234-1234-1234-123456789012   1Gi        RWO            Delete           Bound    default/test-pvc   local-path              1m
```

### 📚 프로비저닝 과정 이해
1. **PVC 생성**: Pending 상태로 대기
2. **Pod 스케줄링**: 특정 노드에 Pod 배치 결정
3. **PV 자동 생성**: 프로비저너가 해당 노드에 PV 생성
4. **바인딩**: PVC와 PV 자동 연결
5. **Pod 시작**: 볼륨 마운트 후 Pod 실행

### 🧹 테스트 리소스 정리
```bash
kubectl delete pod test-pod
kubectl delete pvc test-pvc
```

### 🛑 체크포인트
동적 프로비저닝 과정을 성공적으로 관찰했는지 확인하세요. 이 과정은 MinIO Tenant 배포 시에도 동일하게 발생합니다.

---

## Step 6: 단일 노드 환경 최적화 (해당하는 경우)

### 💡 개념 설명
단일 노드 클러스터에서는 control-plane 노드에 taint가 설정되어 있어 일반 Pod 스케줄링이 제한됩니다.

**Taint란?**
- 노드에 설정된 "기피 조건"
- 특정 조건을 만족하는 Pod만 스케줄링 허용
- control-plane 노드 보호 목적

### 🔍 Taint 확인
```bash
kubectl describe node | grep -i taint
```

### ✅ 예상 출력
```
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
```

### 📚 Taint 해석
- **NoSchedule**: 일반 Pod 스케줄링 금지
- **control-plane**: control-plane 노드임을 표시

### 🔍 Taint 제거 (단일 노드 환경에서만)
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

### ✅ 제거 확인
```bash
kubectl describe node | grep -i taint
```

**성공 시 출력**:
```
Taints:             <none>
```

### ⚠️ 주의사항
- **단일 노드 환경에서만** taint 제거
- **다중 노드 환경에서는 제거하지 마세요**
- 프로덕션 환경에서는 control-plane 보호가 중요

### 🛑 체크포인트
단일 노드 환경인 경우 taint가 제거되었는지 확인하세요. 다중 노드 환경인 경우 이 단계를 건너뛰세요.

---

## Step 7: 환경 정보 요약

### 🔍 최종 환경 확인
```bash
echo "=== 환경 정보 요약 ==="
echo "클러스터 정보:"
kubectl cluster-info

echo -e "\n노드 정보:"
kubectl get nodes

echo -e "\n스토리지 클래스:"
kubectl get storageclass

echo -e "\n네임스페이스 목록:"
kubectl get namespaces
```

### 📊 환경 유형 판별 결과

**단일 노드 환경 특징**:
- ✅ 학습 및 개발에 적합
- ✅ 리소스 효율적
- ⚠️ 고가용성 없음
- ⚠️ MinIO 단일 인스턴스 모드

**다중 노드 환경 특징**:
- ✅ 프로덕션 환경 적합
- ✅ 고가용성 제공
- ✅ MinIO 분산 모드 가능
- ⚠️ 복잡한 설정 필요

---

## 🎯 학습 성과 확인

### ✅ 완료해야 할 체크리스트

- [ ] kubectl 설치 및 버전 확인 완료
- [ ] 클러스터 연결 상태 정상 확인
- [ ] 모든 노드 상태 "Ready" 확인
- [ ] 스토리지 클래스 존재 및 기본 설정 확인
- [ ] 동적 프로비저닝 과정 관찰 완료
- [ ] 환경 유형 (단일/다중 노드) 파악 완료
- [ ] 단일 노드인 경우 taint 제거 완료

### 🧠 핵심 개념 이해도 점검

1. **동적 프로비저닝과 정적 프로비저닝의 차이점을 설명할 수 있나요?**
2. **WaitForFirstConsumer 모드가 왜 유용한지 이해했나요?**
3. **PVC가 Pending 상태인 것이 정상인 경우를 구분할 수 있나요?**
4. **단일 노드 환경에서 taint 제거가 필요한 이유를 알고 있나요?**

---

## 🚀 다음 단계

환경 검증이 완료되었습니다! 이제 다음 실습으로 진행할 수 있습니다:

**Lab 1: MinIO Operator 설치**
- Kubernetes Operator 패턴 학습
- CRD (Custom Resource Definition) 이해
- MinIO Operator 배포 및 확인

### 🔗 관련 문서
- [Lab 1 Lab Guide: MinIO Operator 설치](LAB-01-GUIDE.md)
- [동적 프로비저닝 상세 개념](LAB-00-CONCEPTS.md)
- [환경별 최적화 가이드](../SELECT_ENVIRONMENT.md)

---

## 📝 문제 해결 요약

### 자주 발생하는 문제들

| 문제 | 원인 | 해결 방법 |
|------|------|-----------|
| kubectl 명령어 없음 | kubectl 미설치 | kubectl 설치 |
| 클러스터 연결 실패 | kubeconfig 문제 | kubeconfig 재설정 |
| 노드 NotReady | kubelet 문제 | kubelet 재시작 |
| 스토리지 클래스 없음 | 프로비저너 미설치 | local-path-provisioner 설치 |
| PVC Pending | 정상 동작 | Pod 생성 시 자동 해결 |
| Pod 스케줄링 실패 | control-plane taint | taint 제거 (단일 노드만) |

이 가이드를 통해 MinIO 배포를 위한 견고한 기반을 구축했습니다. 다음 실습에서는 실제 MinIO Operator를 설치하고 운영해보겠습니다.
