# MinIO Kubernetes Lab 준비 가이드

이 가이드는 MinIO Field Architect 면접 준비를 위한 실습 환경 구성 방법을 단계별로 안내합니다.

## 📋 시스템 요구사항

### 최소 요구사항
- **메모리**: 16GB RAM (권장: 32GB)
- **디스크**: 50GB 여유 공간
- **CPU**: 4코어 이상
- **OS**: Ubuntu 20.04/22.04, macOS, Windows 10/11

### 필수 소프트웨어
- Multipass (VM 관리)
- Git (소스 코드 관리)
- 터미널 또는 PowerShell

## 🚀 Step 1: 사전 준비

### 1.1 Multipass 설치

#### Ubuntu/Debian
```bash
sudo snap install multipass
```

#### macOS
```bash
brew install --cask multipass
```

#### Windows
```powershell
# Microsoft Store에서 Multipass 설치
# 또는 공식 웹사이트에서 다운로드
```

### 1.2 설치 확인
```bash
# Multipass 버전 확인
multipass version

# 현재 VM 목록 확인
multipass list
```

### 1.3 시스템 리소스 확인
```bash
# 메모리 확인
free -h

# 디스크 공간 확인
df -h

# CPU 코어 수 확인
nproc
```

## 🖥️ Step 2: VM 환경 구성

### 2.1 메모리별 권장 구성

#### 32GB+ 메모리 (이상적 구성)
```bash
# 마스터 노드
multipass launch --name k8s-master --cpus 2 --mem 4G --disk 20G 22.04

# 워커 노드들
multipass launch --name k8s-worker1 --cpus 2 --mem 4G --disk 30G 22.04
multipass launch --name k8s-worker2 --cpus 2 --mem 4G --disk 30G 22.04
multipass launch --name k8s-worker3 --cpus 2 --mem 4G --disk 30G 22.04
```

#### 16GB 메모리 (최적화 구성) - 권장
```bash
# All-in-One 단일 노드
multipass launch --name minio-k8s --cpus 4 --mem 6G --disk 40G 22.04
```

#### 8GB 메모리 (최소 구성)
```bash
# 경량 단일 노드
multipass launch --name minio-k8s --cpus 2 --mem 4G --disk 30G 22.04
```

### 2.2 VM 생성 확인
```bash
# VM 목록 확인
multipass list

# VM 상세 정보 확인
multipass info minio-k8s
```

## 🔧 Step 3: Kubernetes 클러스터 구성

### 3.1 VM 접속
```bash
# VM에 접속
multipass shell minio-k8s
```

### 3.2 시스템 업데이트
```bash
# 패키지 목록 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지 설치
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
```

### 3.3 containerd 설치
```bash
# containerd 설치
sudo apt install -y containerd

# 설정 디렉토리 생성
sudo mkdir -p /etc/containerd

# 기본 설정 파일 생성
sudo containerd config default | sudo tee /etc/containerd/config.toml

# SystemdCgroup 활성화
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# containerd 재시작
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### 3.4 Kubernetes 패키지 설치
```bash
# Kubernetes 서명 키 다운로드
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Kubernetes APT 저장소 추가
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 패키지 목록 업데이트
sudo apt update

# kubeadm, kubelet, kubectl 설치
sudo apt install -y kubelet kubeadm kubectl

# 패키지 자동 업데이트 방지
sudo apt-mark hold kubelet kubeadm kubectl
```

### 3.5 시스템 설정
```bash
# 스왑 비활성화
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 커널 모듈 로드
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl 파라미터 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

### 3.6 클러스터 초기화
```bash
# Kubernetes 클러스터 초기화
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

# kubectl 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 3.7 CNI 플러그인 설치
```bash
# Flannel CNI 설치
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 단일 노드에서 Pod 스케줄링 허용
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### 3.8 클러스터 상태 확인
```bash
# 노드 상태 확인
kubectl get nodes

# 시스템 Pod 확인
kubectl get pods -n kube-system

# 테스트 Pod 배포
kubectl run test-pod --image=nginx --restart=Never
kubectl get pods
```

## 📁 Step 4: MinIO Lab 파일 준비

### 4.1 Lab 파일 다운로드
```bash
# VM에서 나가기
exit

# 호스트에서 Git 클론
git clone https://github.com/lukesgood/minio_lab_k8s.git
cd minio_lab_k8s

# 실행 권한 부여
chmod +x *.sh
```

### 4.2 kubectl 설정 (호스트에서 VM 접근)
```bash
# VM의 kubeconfig를 호스트로 복사
multipass exec minio-k8s -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config-minio

# VM IP 주소 확인 및 설정
VM_IP=$(multipass info minio-k8s | grep IPv4 | awk '{print $2}')
sed -i "s/https:\/\/.*:6443/https:\/\/$VM_IP:6443/g" ~/.kube/config-minio

# kubectl 설정 적용
export KUBECONFIG=~/.kube/config-minio

# 연결 테스트
kubectl get nodes
```

## ✅ Step 5: 환경 검증

### 5.1 필수 확인 사항
```bash
# 1. 노드 상태 확인
kubectl get nodes
# 결과: Ready 상태여야 함

# 2. 시스템 Pod 확인
kubectl get pods -n kube-system
# 결과: 모든 Pod가 Running 상태여야 함

# 3. 테스트 Pod 확인
kubectl get pods
# 결과: test-pod가 Running 상태여야 함

# 4. Lab 파일 확인
ls -la *.sh
# 결과: 모든 스크립트가 실행 권한(755)을 가져야 함
```

### 5.2 문제 해결 체크리스트

#### 노드가 NotReady 상태인 경우
```bash
# CNI 재설치
kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### Pod가 Pending 상태인 경우
```bash
# 이벤트 확인
kubectl get events --sort-by=.metadata.creationTimestamp

# 노드 리소스 확인
kubectl describe node minio-k8s
```

#### kubectl 연결 실패
```bash
# VM 내부에서 직접 작업
multipass shell minio-k8s
kubectl get nodes
```

## 🎯 Step 6: 실습 시작

### 6.1 실습 메뉴 실행
```bash
# 실습 가이드 실행
./run-lab.sh
```

### 6.2 개별 실습 실행
```bash
# MinIO Operator 설치
./minio-operator-install.sh

# MinIO Tenant 배포
./deploy-tenant.sh

# Helm Chart 설치
./minio-helm-install.sh

# 성능 테스트
./performance-test.sh
```

## 📊 예상 소요 시간

| 단계 | 소요 시간 | 비고 |
|------|-----------|------|
| Multipass 설치 | 5분 | 인터넷 속도에 따라 |
| VM 생성 | 5-10분 | 이미지 다운로드 포함 |
| 시스템 업데이트 | 10-15분 | 패키지 크기에 따라 |
| Kubernetes 설치 | 15-20분 | 컨테이너 이미지 다운로드 |
| 클러스터 초기화 | 5-10분 | 네트워크 속도에 따라 |
| **총 소요 시간** | **40-60분** | 최초 설치 기준 |

## 🚨 주의사항

### 보안 고려사항
- 실습 환경은 학습 목적으로만 사용
- 프로덕션 환경에서는 추가 보안 설정 필요
- 기본 비밀번호 변경 권장

### 리소스 관리
- VM 사용 후 정리: `multipass delete <vm-name> && multipass purge`
- 호스트 시스템 리소스 모니터링
- 장시간 미사용 시 VM 중지: `multipass stop <vm-name>`

### 네트워크 설정
- 방화벽 설정 확인
- 포트 포워딩 충돌 주의
- VPN 사용 시 네트워크 충돌 가능성

## 📚 추가 리소스

### 공식 문서
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [MinIO 공식 문서](https://docs.min.io/)
- [Multipass 공식 문서](https://multipass.run/docs)

### 트러블슈팅
- `troubleshooting-guide.md` 참조
- [Kubernetes 트러블슈팅](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [MinIO 트러블슈팅](https://docs.min.io/docs/minio-troubleshooting-guide.html)

---

**🎉 준비 완료!** 이제 MinIO Field Architect 면접을 위한 실습을 시작할 수 있습니다.

실습 중 문제가 발생하면 각 단계별 확인 사항을 점검하고, 필요시 트러블슈팅 가이드를 참조하세요.
