# Kubernetes 환경 구성 가이드

## 📋 개요

MinIO Kubernetes Lab을 시작하기 전에 Kubernetes 클러스터를 구성하는 방법을 안내합니다. 다양한 환경에 맞는 설치 방법을 제공합니다.

## 🎯 환경별 선택 가이드

### 학습/개발 환경 (권장)
- **Minikube**: 가장 간단한 로컬 클러스터
- **Kind**: Docker 기반 경량 클러스터
- **K3s**: 경량 프로덕션급 클러스터

### 프로덕션 환경
- **kubeadm**: 표준 클러스터 구성 도구
- **클라우드 서비스**: EKS, GKE, AKS 등

## 🚀 방법 1: Minikube (가장 간단)

### 시스템 요구사항
- CPU: 2코어 이상
- 메모리: 4GB 이상
- 디스크: 20GB 이상
- Docker 또는 VirtualBox

### 설치 과정

#### 1. Minikube 설치
```bash
# Linux x86-64
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# macOS
brew install minikube

# Windows (PowerShell as Administrator)
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
```

#### 2. kubectl 설치
```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Windows
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

#### 3. Minikube 클러스터 시작
```bash
# 기본 설정으로 시작
minikube start

# 리소스 지정하여 시작 (권장)
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Docker 드라이버 사용 (권장)
minikube start --driver=docker --cpus=4 --memory=8192
```

#### 4. 설치 확인
```bash
# 클러스터 상태 확인
kubectl cluster-info

# 노드 확인
kubectl get nodes

# Minikube 상태 확인
minikube status
```

## 🐳 방법 2: Kind (Docker 기반)

### 시스템 요구사항
- Docker 설치 필요
- CPU: 2코어 이상
- 메모리: 4GB 이상

### 설치 과정

#### 1. Kind 설치
```bash
# Linux
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS
brew install kind

# Windows
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

#### 2. 클러스터 설정 파일 생성
```bash
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 9000
    hostPort: 9000
    protocol: TCP
  - containerPort: 9001
    hostPort: 9001
    protocol: TCP
EOF
```

#### 3. 클러스터 생성
```bash
# 설정 파일로 클러스터 생성
kind create cluster --config=kind-config.yaml --name=minio-lab

# 기본 설정으로 생성
kind create cluster --name=minio-lab
```

#### 4. kubectl 컨텍스트 설정
```bash
# Kind 클러스터로 컨텍스트 변경
kubectl cluster-info --context kind-minio-lab
```

## 🐄 방법 3: K3s (경량 프로덕션급)

### 시스템 요구사항
- Linux 시스템
- CPU: 1코어 이상
- 메모리: 512MB 이상

### 설치 과정

#### 1. K3s 설치
```bash
# 기본 설치
curl -sfL https://get.k3s.io | sh -

# 특정 옵션으로 설치
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
```

#### 2. kubectl 설정
```bash
# kubeconfig 복사
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# 또는 환경변수 설정
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

#### 3. 설치 확인
```bash
# 노드 확인
kubectl get nodes

# 시스템 Pod 확인
kubectl get pods -A
```

## ⚙️ 방법 4: kubeadm (프로덕션 환경)

### 시스템 요구사항
- Linux 시스템 (Ubuntu 20.04+ 권장)
- CPU: 2코어 이상
- 메모리: 2GB 이상
- 네트워크 연결

### 설치 과정

#### 1. 사전 준비
```bash
# 스왑 비활성화
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 필수 모듈 로드
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 네트워크 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 2. 컨테이너 런타임 설치 (containerd)
```bash
# Docker 공식 GPG 키 추가
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker 저장소 추가
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# containerd 설치
sudo apt-get update
sudo apt-get install -y containerd.io

# containerd 설정
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

#### 3. kubeadm, kubelet, kubectl 설치
```bash
# Kubernetes 저장소 추가
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Kubernetes 도구 설치
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

#### 4. 클러스터 초기화
```bash
# 마스터 노드 초기화
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# kubectl 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 5. 네트워크 플러그인 설치 (Flannel)
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

#### 6. 단일 노드 클러스터 설정 (선택사항)
```bash
# Control-plane에서 Pod 스케줄링 허용
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## ☁️ 방법 5: 클라우드 서비스

### AWS EKS
```bash
# eksctl 설치
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# 클러스터 생성
eksctl create cluster --name=minio-lab --nodes=3 --node-type=t3.medium --region=us-west-2
```

### Google GKE
```bash
# gcloud CLI 설치 후
gcloud container clusters create minio-lab \
    --num-nodes=3 \
    --machine-type=e2-standard-4 \
    --zone=us-central1-a
```

### Azure AKS
```bash
# Azure CLI 설치 후
az aks create \
    --resource-group myResourceGroup \
    --name minio-lab \
    --node-count 3 \
    --node-vm-size Standard_D2s_v3 \
    --generate-ssh-keys
```

## 🔧 환경 구성 자동화 스크립트

MinIO Lab에서 제공하는 자동화 스크립트를 사용할 수 있습니다:

```bash
# 환경 자동 감지 및 설정
./detect-environment.sh
./setup-environment.sh

# 또는 Kubernetes 환경 구성 스크립트 실행
./setup-k8s-environment.sh
```

## ✅ 설치 완료 확인

모든 방법으로 설치 후 다음 명령어로 확인:

```bash
# 클러스터 정보 확인
kubectl cluster-info

# 노드 상태 확인
kubectl get nodes

# 시스템 Pod 확인
kubectl get pods -A

# 버전 확인
kubectl version --short
```

## 🚨 일반적인 문제 해결

### 1. kubectl 명령어 인식 안됨
```bash
# PATH 확인
echo $PATH

# kubectl 위치 확인
which kubectl

# 권한 확인
ls -la ~/.kube/config
```

### 2. 노드가 Ready 상태가 아님
```bash
# 노드 상세 정보 확인
kubectl describe node

# 시스템 Pod 상태 확인
kubectl get pods -n kube-system

# 로그 확인
journalctl -u kubelet
```

### 3. 네트워크 문제
```bash
# CNI 플러그인 확인
kubectl get pods -n kube-system | grep -E "(flannel|calico|weave)"

# 네트워크 정책 확인
kubectl get networkpolicies -A
```

## 📖 다음 단계

Kubernetes 클러스터 구성이 완료되면:

1. **MinIO Lab 시작**: `./detect-environment.sh`
2. **환경 설정**: `./setup-environment.sh`
3. **실습 진행**: Lab Guide를 순서대로 따라하며 실습 진행 (docs/LAB-00-GUIDE.md부터 시작)

## 🔗 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Minikube 문서](https://minikube.sigs.k8s.io/docs/)
- [Kind 문서](https://kind.sigs.k8s.io/)
- [K3s 문서](https://k3s.io/)
- [kubeadm 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)

---

**💡 권장사항**: 처음 사용하는 경우 Minikube로 시작하여 Kubernetes 기본 개념을 익힌 후, 필요에 따라 다른 방법으로 확장하는 것을 권장합니다.
