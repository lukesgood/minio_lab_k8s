#!/bin/bash

# MinIO Kubernetes Lab 환경 자동 구성 스크립트
# 사용법: ./setup-environment.sh [memory_size]
# 예시: ./setup-environment.sh 16G

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 메모리 크기에 따른 VM 구성 결정
determine_vm_config() {
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local memory_arg=${1:-"auto"}
    
    log_info "시스템 메모리: ${total_mem}GB"
    
    if [[ "$memory_arg" == "auto" ]]; then
        if [[ $total_mem -ge 32 ]]; then
            VM_CONFIG="multi"
            VM_MEMORY="4G"
            log_info "32GB+ 메모리 감지: 멀티 노드 구성 선택"
        elif [[ $total_mem -ge 16 ]]; then
            VM_CONFIG="single"
            VM_MEMORY="6G"
            log_info "16GB 메모리 감지: 단일 노드 구성 선택"
        else
            VM_CONFIG="minimal"
            VM_MEMORY="4G"
            log_warning "8GB 메모리 감지: 최소 구성 선택"
        fi
    else
        case $memory_arg in
            "32G"|"multi")
                VM_CONFIG="multi"
                VM_MEMORY="4G"
                ;;
            "16G"|"single")
                VM_CONFIG="single"
                VM_MEMORY="6G"
                ;;
            "8G"|"minimal")
                VM_CONFIG="minimal"
                VM_MEMORY="4G"
                ;;
            *)
                log_error "지원하지 않는 메모리 크기: $memory_arg"
                exit 1
                ;;
        esac
    fi
    
    log_info "선택된 구성: $VM_CONFIG (VM 메모리: $VM_MEMORY)"
}

# Multipass 설치 확인
check_multipass() {
    log_info "Multipass 설치 확인 중..."
    
    if ! command -v multipass &> /dev/null; then
        log_error "Multipass가 설치되지 않았습니다."
        log_info "설치 방법:"
        log_info "  Ubuntu/Debian: sudo snap install multipass"
        log_info "  macOS: brew install --cask multipass"
        log_info "  Windows: Microsoft Store에서 설치"
        exit 1
    fi
    
    log_success "Multipass 설치 확인됨: $(multipass version | head -1)"
}

# VM 생성
create_vms() {
    log_info "VM 생성 시작..."
    
    case $VM_CONFIG in
        "multi")
            log_info "멀티 노드 구성으로 VM 생성 중..."
            multipass launch --name k8s-master --cpus 2 --mem 4G --disk 20G 22.04 &
            multipass launch --name k8s-worker1 --cpus 2 --mem 4G --disk 30G 22.04 &
            multipass launch --name k8s-worker2 --cpus 2 --mem 4G --disk 30G 22.04 &
            multipass launch --name k8s-worker3 --cpus 2 --mem 4G --disk 30G 22.04 &
            wait
            VM_NAME="k8s-master"
            ;;
        "single")
            log_info "단일 노드 구성으로 VM 생성 중..."
            multipass launch --name minio-k8s --cpus 4 --mem 6G --disk 40G 22.04
            VM_NAME="minio-k8s"
            ;;
        "minimal")
            log_info "최소 구성으로 VM 생성 중..."
            multipass launch --name minio-k8s --cpus 2 --mem 4G --disk 30G 22.04
            VM_NAME="minio-k8s"
            ;;
    esac
    
    log_success "VM 생성 완료"
    multipass list
}

# VM 내부 설정 스크립트 생성
create_vm_setup_script() {
    log_info "VM 설정 스크립트 생성 중..."
    
    cat > /tmp/vm-setup.sh << 'EOF'
#!/bin/bash
set -e

echo "[INFO] 시스템 업데이트 시작..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "[INFO] containerd 설치 중..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[INFO] Kubernetes 패키지 설치 중..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[INFO] 시스템 설정 중..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOL | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOL

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOL | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOL

sudo sysctl --system

echo "[INFO] Kubernetes 클러스터 초기화 중..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

echo "[INFO] kubectl 설정 중..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[INFO] CNI 플러그인 설치 중..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "[INFO] 단일 노드 설정 중..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "[INFO] 클러스터 상태 확인 중..."
kubectl get nodes
kubectl get pods -n kube-system

echo "[SUCCESS] Kubernetes 클러스터 설정 완료!"
EOF

    chmod +x /tmp/vm-setup.sh
}

# VM 설정 실행
setup_vm() {
    log_info "VM 내부 설정 시작..."
    
    # 설정 스크립트를 VM으로 복사
    multipass transfer /tmp/vm-setup.sh $VM_NAME:/tmp/vm-setup.sh
    
    # VM 내부에서 설정 스크립트 실행
    multipass exec $VM_NAME -- bash /tmp/vm-setup.sh
    
    log_success "VM 설정 완료"
}

# kubectl 설정 (호스트에서 VM 접근)
setup_kubectl() {
    log_info "kubectl 설정 중..."
    
    # .kube 디렉토리 생성
    mkdir -p ~/.kube
    
    # VM의 kubeconfig를 호스트로 복사
    multipass exec $VM_NAME -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config-minio
    
    # VM IP 주소 확인 및 설정
    VM_IP=$(multipass info $VM_NAME | grep IPv4 | awk '{print $2}')
    log_info "VM IP 주소: $VM_IP"
    
    # kubeconfig 파일에서 서버 주소 수정
    sed -i "s/https:\/\/.*:6443/https:\/\/$VM_IP:6443/g" ~/.kube/config-minio
    
    # kubectl 설정 적용 안내
    log_info "kubectl 사용을 위해 다음 명령어를 실행하세요:"
    echo "export KUBECONFIG=~/.kube/config-minio"
    
    log_success "kubectl 설정 완료"
}

# 환경 검증
verify_environment() {
    log_info "환경 검증 중..."
    
    # kubectl 설정 임시 적용
    export KUBECONFIG=~/.kube/config-minio
    
    # 노드 상태 확인
    if kubectl get nodes | grep -q "Ready"; then
        log_success "노드 상태: Ready"
    else
        log_warning "노드가 아직 Ready 상태가 아닙니다. 잠시 후 다시 확인하세요."
    fi
    
    # 시스템 Pod 확인
    local running_pods=$(kubectl get pods -n kube-system --no-headers | grep Running | wc -l)
    log_info "실행 중인 시스템 Pod: $running_pods개"
    
    # 테스트 Pod 배포
    kubectl run test-pod --image=nginx --restart=Never --timeout=60s
    if kubectl get pod test-pod | grep -q "Running"; then
        log_success "테스트 Pod 배포 성공"
        kubectl delete pod test-pod
    else
        log_warning "테스트 Pod 배포 실패. 수동으로 확인하세요."
    fi
}

# 완료 메시지
show_completion_message() {
    log_success "MinIO Kubernetes Lab 환경 구성 완료!"
    echo
    echo "=== 다음 단계 ==="
    echo "1. kubectl 설정 적용:"
    echo "   export KUBECONFIG=~/.kube/config-minio"
    echo
    echo "2. 클러스터 상태 확인:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -n kube-system"
    echo
    echo "3. MinIO 실습 시작:"
    echo "   ./run-lab.sh"
    echo
    echo "=== VM 관리 명령어 ==="
    echo "VM 접속: multipass shell $VM_NAME"
    echo "VM 중지: multipass stop $VM_NAME"
    echo "VM 시작: multipass start $VM_NAME"
    echo "VM 삭제: multipass delete $VM_NAME && multipass purge"
    echo
}

# 메인 실행 함수
main() {
    log_info "MinIO Kubernetes Lab 환경 구성 시작"
    echo "========================================"
    
    # 메모리 구성 결정
    determine_vm_config $1
    
    # Multipass 확인
    check_multipass
    
    # VM 생성
    create_vms
    
    # VM 설정 스크립트 생성
    create_vm_setup_script
    
    # VM 설정 실행
    setup_vm
    
    # kubectl 설정
    setup_kubectl
    
    # 환경 검증
    verify_environment
    
    # 완료 메시지
    show_completion_message
}

# 스크립트 실행
main $1
