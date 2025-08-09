#!/bin/bash

echo "=== Kubernetes 환경 구성 자동화 스크립트 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OS 감지
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        fi
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# 메뉴 표시
show_menu() {
    echo -e "${BLUE}🚀 Kubernetes 환경 구성 방법을 선택하세요:${NC}"
    echo ""
    echo -e "${GREEN}=== 학습/개발 환경 (권장) ===${NC}"
    echo "1) Minikube - 가장 간단한 로컬 클러스터"
    echo "2) Kind - Docker 기반 경량 클러스터"
    echo "3) K3s - 경량 프로덕션급 클러스터"
    echo ""
    echo -e "${YELLOW}=== 프로덕션 환경 ===${NC}"
    echo "4) kubeadm - 표준 클러스터 구성"
    echo ""
    echo -e "${BLUE}=== 기타 ===${NC}"
    echo "5) 기존 클러스터 확인"
    echo "6) kubectl만 설치"
    echo "h) 도움말"
    echo "q) 종료"
    echo ""
}

# kubectl 설치
install_kubectl() {
    echo "kubectl 설치 중..."
    OS_TYPE=$(detect_os)
    
    case $OS_TYPE in
        "linux")
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install kubectl
            else
                echo -e "${YELLOW}Homebrew가 설치되지 않았습니다. 수동 설치를 진행합니다.${NC}"
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
            fi
            ;;
        *)
            echo -e "${RED}❌ 지원하지 않는 OS입니다.${NC}"
            return 1
            ;;
    esac
    
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}✅ kubectl 설치 완료${NC}"
        kubectl version --client
    else
        echo -e "${RED}❌ kubectl 설치 실패${NC}"
        return 1
    fi
}

# Minikube 설치
install_minikube() {
    echo -e "${GREEN}=== Minikube 설치 ===${NC}"
    OS_TYPE=$(detect_os)
    
    # kubectl 설치 확인
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl이 설치되지 않았습니다. 먼저 설치합니다..."
        install_kubectl
    fi
    
    # Minikube 설치
    case $OS_TYPE in
        "linux")
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install minikube
            else
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
                sudo install minikube-darwin-amd64 /usr/local/bin/minikube
                rm minikube-darwin-amd64
            fi
            ;;
        *)
            echo -e "${RED}❌ 지원하지 않는 OS입니다.${NC}"
            return 1
            ;;
    esac
    
    # Docker 설치 확인
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}⚠️  Docker가 설치되지 않았습니다.${NC}"
        echo "Docker를 설치하거나 VirtualBox를 사용하세요."
        echo "Docker 설치: https://docs.docker.com/get-docker/"
    fi
    
    # Minikube 클러스터 시작
    echo ""
    echo "Minikube 클러스터를 시작합니다..."
    echo "리소스 설정: CPU 4코어, 메모리 8GB, 디스크 20GB"
    
    if minikube start --cpus=4 --memory=8192 --disk-size=20g --driver=docker; then
        echo -e "${GREEN}✅ Minikube 클러스터 시작 완료${NC}"
        
        # 상태 확인
        echo ""
        echo "클러스터 상태 확인:"
        kubectl cluster-info
        kubectl get nodes
        minikube status
    else
        echo -e "${RED}❌ Minikube 시작 실패${NC}"
        echo "다음 명령어로 수동 시작을 시도하세요:"
        echo "minikube start --driver=virtualbox"
        return 1
    fi
}

# Kind 설치
install_kind() {
    echo -e "${GREEN}=== Kind 설치 ===${NC}"
    OS_TYPE=$(detect_os)
    
    # kubectl 설치 확인
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl이 설치되지 않았습니다. 먼저 설치합니다..."
        install_kubectl
    fi
    
    # Docker 확인
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker가 설치되지 않았습니다.${NC}"
        echo "Kind는 Docker가 필요합니다. Docker를 먼저 설치하세요."
        echo "Docker 설치: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    # Kind 설치
    case $OS_TYPE in
        "linux")
            [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install kind
            else
                [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
            ;;
        *)
            echo -e "${RED}❌ 지원하지 않는 OS입니다.${NC}"
            return 1
            ;;
    esac
    
    # Kind 설정 파일 생성
    echo ""
    echo "Kind 클러스터 설정 파일 생성..."
    cat > kind-config.yaml << 'EOF'
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
    
    # Kind 클러스터 생성
    echo "Kind 클러스터 생성 중..."
    if kind create cluster --config=kind-config.yaml --name=minio-lab; then
        echo -e "${GREEN}✅ Kind 클러스터 생성 완료${NC}"
        
        # 상태 확인
        echo ""
        echo "클러스터 상태 확인:"
        kubectl cluster-info --context kind-minio-lab
        kubectl get nodes
        
        # 컨텍스트 설정
        kubectl config use-context kind-minio-lab
    else
        echo -e "${RED}❌ Kind 클러스터 생성 실패${NC}"
        return 1
    fi
    
    # 설정 파일 정리
    rm -f kind-config.yaml
}

# K3s 설치
install_k3s() {
    echo -e "${GREEN}=== K3s 설치 ===${NC}"
    
    if [[ $(detect_os) != "linux" ]]; then
        echo -e "${RED}❌ K3s는 Linux 환경에서만 지원됩니다.${NC}"
        return 1
    fi
    
    # K3s 설치
    echo "K3s 설치 중..."
    if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -; then
        echo -e "${GREEN}✅ K3s 설치 완료${NC}"
        
        # kubectl 설정
        echo "kubectl 설정 중..."
        mkdir -p ~/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
        sudo chown $USER:$USER ~/.kube/config
        
        # 상태 확인
        echo ""
        echo "클러스터 상태 확인:"
        kubectl cluster-info
        kubectl get nodes
        kubectl get pods -A
    else
        echo -e "${RED}❌ K3s 설치 실패${NC}"
        return 1
    fi
}

# kubeadm 설치 (Ubuntu/Debian 기준)
install_kubeadm() {
    echo -e "${GREEN}=== kubeadm 설치 ===${NC}"
    
    if [[ $(detect_os) != "linux" ]]; then
        echo -e "${RED}❌ kubeadm은 Linux 환경에서만 지원됩니다.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}⚠️  kubeadm 설치는 시스템을 변경합니다.${NC}"
    echo "계속하시겠습니까? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "설치가 취소되었습니다."
        return 1
    fi
    
    echo "시스템 사전 준비 중..."
    
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
    
    # containerd 설치
    echo "containerd 설치 중..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y containerd.io
    
    # containerd 설정
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd
    
    # Kubernetes 도구 설치
    echo "Kubernetes 도구 설치 중..."
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # 클러스터 초기화
    echo "클러스터 초기화 중..."
    if sudo kubeadm init --pod-network-cidr=10.244.0.0/16; then
        # kubectl 설정
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Flannel 네트워크 플러그인 설치
        echo "네트워크 플러그인 설치 중..."
        kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
        
        # 단일 노드 클러스터 설정
        echo "단일 노드 클러스터 설정 중..."
        kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
        
        echo -e "${GREEN}✅ kubeadm 클러스터 설치 완료${NC}"
        
        # 상태 확인
        echo ""
        echo "클러스터 상태 확인:"
        kubectl cluster-info
        kubectl get nodes
    else
        echo -e "${RED}❌ kubeadm 클러스터 초기화 실패${NC}"
        return 1
    fi
}

# 기존 클러스터 확인
check_existing_cluster() {
    echo -e "${GREEN}=== 기존 클러스터 확인 ===${NC}"
    
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}✅ kubectl이 설치되어 있습니다.${NC}"
        kubectl version --client
        
        echo ""
        echo "클러스터 연결 테스트 중..."
        if kubectl cluster-info &> /dev/null; then
            echo -e "${GREEN}✅ 클러스터에 연결되었습니다.${NC}"
            
            echo ""
            echo "클러스터 정보:"
            kubectl cluster-info
            
            echo ""
            echo "노드 정보:"
            kubectl get nodes
            
            echo ""
            echo "네임스페이스 목록:"
            kubectl get namespaces
            
            echo ""
            echo -e "${GREEN}🎉 기존 클러스터를 사용할 수 있습니다!${NC}"
            echo "MinIO Lab을 시작하려면 다음 명령어를 실행하세요:"
            echo "./detect-environment.sh"
            echo "./setup-environment.sh"
            echo "./run-lab.sh"
        else
            echo -e "${RED}❌ 클러스터에 연결할 수 없습니다.${NC}"
            echo ""
            echo "가능한 원인:"
            echo "1. 클러스터가 실행되지 않음"
            echo "2. kubeconfig 설정 문제"
            echo "3. 네트워크 연결 문제"
            echo ""
            echo "해결 방법:"
            echo "1. 클러스터 상태 확인 (minikube status, kind get clusters 등)"
            echo "2. kubeconfig 파일 확인 (~/.kube/config)"
            echo "3. 새로운 클러스터 설치"
        fi
    else
        echo -e "${RED}❌ kubectl이 설치되지 않았습니다.${NC}"
        echo "kubectl을 먼저 설치하거나 새로운 클러스터를 설치하세요."
    fi
}

# 도움말
show_help() {
    echo -e "${BLUE}📖 Kubernetes 환경 구성 도움말${NC}"
    echo ""
    echo "각 방법의 특징:"
    echo ""
    echo -e "${GREEN}1. Minikube${NC}"
    echo "   - 가장 간단하고 널리 사용됨"
    echo "   - GUI 도구 제공"
    echo "   - 애드온 지원 (dashboard, ingress 등)"
    echo "   - 권장: 처음 사용자"
    echo ""
    echo -e "${GREEN}2. Kind${NC}"
    echo "   - Docker 컨테이너 기반"
    echo "   - 빠른 시작/종료"
    echo "   - CI/CD 환경에 적합"
    echo "   - 권장: Docker 사용자"
    echo ""
    echo -e "${GREEN}3. K3s${NC}"
    echo "   - 경량 프로덕션급"
    echo "   - 리소스 사용량 적음"
    echo "   - IoT/Edge 환경 적합"
    echo "   - 권장: 리소스 제약 환경"
    echo ""
    echo -e "${GREEN}4. kubeadm${NC}"
    echo "   - 표준 클러스터 구성"
    echo "   - 프로덕션 환경 적합"
    echo "   - 완전한 제어 가능"
    echo "   - 권장: 고급 사용자"
    echo ""
    echo "시스템 요구사항:"
    echo "- CPU: 2코어 이상"
    echo "- 메모리: 4GB 이상"
    echo "- 디스크: 20GB 이상"
    echo ""
}

# 메인 루프
while true; do
    show_menu
    read -p "선택 (1-6, h, q): " choice
    echo ""
    
    case $choice in
        1)
            install_minikube
            ;;
        2)
            install_kind
            ;;
        3)
            install_k3s
            ;;
        4)
            install_kubeadm
            ;;
        5)
            check_existing_cluster
            ;;
        6)
            install_kubectl
            ;;
        h)
            show_help
            ;;
        q)
            echo "스크립트를 종료합니다."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 잘못된 선택입니다. 다시 선택해주세요.${NC}"
            ;;
    esac
    
    echo ""
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
done
