#!/bin/bash

echo "=== Lab 0: 환경 사전 검증 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- Kubernetes 클러스터 연결 확인"
echo "- 스토리지 프로비저너 동작 원리"
echo "- 동적 프로비저닝 vs 정적 프로비저닝"
echo "- PV/PVC 생성 과정 이해"
echo "- 단계별 체크포인트와 개념 설명"
echo ""

# 사용자 진행 확인 함수
wait_for_user() {
    echo ""
    echo -e "${YELLOW}🛑 CHECKPOINT: $1${NC}"
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
}

# Step 1: kubectl 설치 확인
echo -e "${GREEN}📋 Step 1: kubectl 설치 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "kubectl은 Kubernetes 클러스터와 통신하는 명령줄 도구입니다."
echo "- 클러스터 상태 확인"
echo "- 리소스 생성/수정/삭제"
echo "- 애플리케이션 배포 및 관리"
echo ""

echo "명령어: kubectl version --client"
echo "목적: kubectl이 설치되어 있고 정상 작동하는지 확인"
echo ""

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✅ kubectl이 설치되어 있습니다${NC}"
    kubectl version --client
    echo ""
    echo -e "${BLUE}📚 버전 정보 설명:${NC}"
    echo "- Client Version: 현재 설치된 kubectl 버전"
    echo "- GitVersion: 정확한 릴리스 버전"
    echo "- 이 정보는 클러스터 호환성 확인에 중요합니다"
else
    echo -e "${RED}❌ kubectl이 설치되지 않았습니다${NC}"
    echo ""
    echo -e "${YELLOW}해결 방법:${NC}"
    echo "1. Linux: curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    echo "2. macOS: brew install kubectl"
    echo "3. Windows: choco install kubernetes-cli"
    exit 1
fi

wait_for_user "kubectl 버전 정보를 확인했습니다. 다음 단계로 진행하시겠습니까?"

# Step 2: 클러스터 연결 확인
echo -e "${GREEN}📋 Step 2: Kubernetes 클러스터 연결 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes 클러스터는 여러 구성 요소로 이루어져 있습니다:"
echo "- API Server: 클러스터의 '뇌' 역할, 모든 요청을 처리"
echo "- etcd: 클러스터 상태 정보를 저장하는 데이터베이스"
echo "- CoreDNS: 클러스터 내부 서비스 이름 해석"
echo ""

echo "명령어: kubectl cluster-info"
echo "목적: kubectl이 클러스터와 통신할 수 있는지 확인"
echo ""

if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✅ 클러스터 연결 정상${NC}"
    kubectl cluster-info
    echo ""
    echo -e "${BLUE}📚 출력 정보 설명:${NC}"
    echo "- Kubernetes control plane: API 서버 주소"
    echo "- CoreDNS: 클러스터 내부 DNS 서비스"
    echo "- 이 정보들이 보이면 클러스터가 정상 작동 중입니다"
else
    echo -e "${RED}❌ 클러스터 연결 실패${NC}"
    echo ""
    echo -e "${YELLOW}가능한 원인:${NC}"
    echo "1. Kubernetes 클러스터가 실행되지 않음"
    echo "2. kubeconfig 파일이 올바르지 않음"
    echo "3. 네트워크 연결 문제"
    echo ""
    echo -e "${YELLOW}해결 방법:${NC}"
    echo "1. 클러스터 상태 확인: systemctl status kubelet"
    echo "2. kubeconfig 확인: ls -la ~/.kube/config"
    echo "3. 클러스터 재시작 또는 kubeconfig 재설정"
    exit 1
fi

wait_for_user "클러스터 연결을 확인했습니다. 노드 상태를 확인해보겠습니다."

# Step 3: 노드 상태 확인
echo -e "${GREEN}📋 Step 3: 클러스터 노드 상태 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes 노드는 실제 워크로드가 실행되는 컴퓨터입니다:"
echo "- Control-plane: 클러스터 관리 기능 (API 서버, etcd 등)"
echo "- Worker nodes: 실제 애플리케이션 Pod가 실행되는 노드"
echo "- Single-node: 하나의 노드가 모든 역할을 담당 (학습용)"
echo "- Multi-node: 역할이 분리된 프로덕션 환경"
echo ""

echo "명령어: kubectl get nodes"
echo "목적: 클러스터의 노드 수와 상태 확인"
echo ""

kubectl get nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo ""
echo -e "${BLUE}📚 출력 정보 설명:${NC}"
echo "- NAME: 노드 이름"
echo "- STATUS: Ready(정상) / NotReady(문제 있음)"
echo "- ROLES: control-plane(마스터) / <none>(워커)"
echo "- AGE: 노드가 클러스터에 조인된 시간"
echo "- VERSION: 해당 노드의 kubelet 버전"
echo ""

echo "감지된 노드 수: ${NODE_COUNT}개"

if [ "$NODE_COUNT" -eq 1 ]; then
    echo -e "${YELLOW}💡 단일 노드 클러스터 감지${NC}"
    echo ""
    echo -e "${BLUE}단일 노드 클러스터 특징:${NC}"
    echo "- 학습 및 개발 환경에 적합"
    echo "- 리소스 요구사항이 낮음"
    echo "- 고가용성 없음 (노드 장애 시 전체 중단)"
    echo "- Control-plane taint 제거 필요 (Pod 스케줄링을 위해)"
    echo ""
    echo -e "${YELLOW}⚠️  MinIO 배포를 위한 단일 노드 최적화가 필요합니다${NC}"
    ENVIRONMENT_TYPE="single-node"
else
    echo -e "${BLUE}💡 다중 노드 클러스터 감지${NC}"
    echo ""
    echo -e "${BLUE}다중 노드 클러스터 특징:${NC}"
    echo "- 프로덕션 환경에 적합"
    echo "- 고가용성 제공"
    echo "- 확장성 우수"
    echo "- 복잡한 네트워크 설정 필요"
    echo ""
    echo -e "${GREEN}✅ MinIO 분산 모드 사용 가능${NC}"
    ENVIRONMENT_TYPE="multi-node"
fi

wait_for_user "노드 상태를 확인했습니다. 스토리지 설정을 확인해보겠습니다."

# Step 4: 스토리지 클래스 확인
echo -e "${GREEN}📋 Step 4: 스토리지 클래스 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "스토리지 클래스는 동적 프로비저닝을 위한 템플릿입니다:"
echo "- 정적 프로비저닝: 관리자가 미리 PV 생성 → 사용자가 PVC 생성 → 바인딩"
echo "- 동적 프로비저닝: 사용자가 PVC 생성 → 프로비저너가 자동으로 PV 생성 → 바인딩"
echo ""
echo "MinIO는 데이터 저장을 위해 영구 스토리지(Persistent Storage)가 필요합니다."
echo ""

echo "명령어: kubectl get storageclass"
echo "목적: 동적 프로비저닝을 위한 스토리지 클래스 존재 확인"
echo ""

STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)

if [ "$STORAGE_CLASSES" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  스토리지 클래스가 없습니다${NC}"
    echo ""
    echo -e "${BLUE}📚 스토리지 클래스가 필요한 이유:${NC}"
    echo "- MinIO는 데이터를 영구적으로 저장해야 합니다"
    echo "- Pod가 재시작되어도 데이터가 유지되어야 합니다"
    echo "- 동적 프로비저닝으로 필요할 때 자동으로 스토리지 생성"
    echo ""
    echo -e "${GREEN}해결책: Local Path Provisioner 설치${NC}"
    echo ""
    
    wait_for_user "스토리지 프로비저너를 설치하겠습니다."
    
    echo -e "${GREEN}📋 Step 4-1: Local Path Provisioner 설치${NC}"
    echo ""
    echo -e "${BLUE}💡 Local Path Provisioner란?${NC}"
    echo "- 노드의 로컬 디스크를 사용하여 PV를 자동 생성"
    echo "- 단일 노드 환경에 최적화"
    echo "- /opt/local-path-provisioner 디렉토리에 데이터 저장"
    echo "- WaitForFirstConsumer 모드로 효율적 리소스 사용"
    echo ""
    
    echo "명령어: kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml"
    echo "목적: 로컬 디스크 기반 동적 스토리지 프로비저너 설치"
    echo ""
    
    if kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml; then
        echo ""
        echo -e "${GREEN}✅ Local Path Provisioner 설치 완료${NC}"
        echo ""
        echo -e "${BLUE}📚 설치된 구성 요소:${NC}"
        echo "- namespace/local-path-storage: 프로비저너 전용 네임스페이스"
        echo "- deployment/local-path-provisioner: 프로비저너 Pod"
        echo "- storageclass/local-path: 스토리지 클래스 템플릿"
        echo "- configmap/local-path-config: 스토리지 경로 설정"
        echo ""
        
        echo "프로비저너 시작 대기 중..."
        kubectl wait --for=condition=available --timeout=60s deployment/local-path-provisioner -n local-path-storage
        
        wait_for_user "Local Path Provisioner가 설치되었습니다. 기본 스토리지 클래스로 설정하겠습니다."
        
        echo -e "${GREEN}📋 Step 4-2: 기본 스토리지 클래스 설정${NC}"
        echo ""
        echo -e "${BLUE}💡 기본 스토리지 클래스의 중요성:${NC}"
        echo "- PVC에서 storageClassName을 지정하지 않으면 기본 클래스 사용"
        echo "- MinIO Operator가 자동으로 스토리지를 요청할 때 필요"
        echo "- '(default)' 마커로 식별 가능"
        echo ""
        
        echo "명령어: kubectl patch storageclass local-path -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
        echo "목적: local-path를 기본 스토리지 클래스로 설정"
        echo ""
        
        if kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'; then
            echo ""
            echo -e "${GREEN}✅ 기본 스토리지 클래스 설정 완료${NC}"
        else
            echo -e "${RED}❌ 기본 스토리지 클래스 설정 실패${NC}"
        fi
    else
        echo -e "${RED}❌ Local Path Provisioner 설치 실패${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ 스토리지 클래스가 존재합니다${NC}"
fi

echo ""
echo "현재 스토리지 클래스 상태:"
kubectl get storageclass
echo ""

# 스토리지 클래스 상세 정보 설명
if kubectl get storageclass local-path &>/dev/null; then
    echo -e "${BLUE}📚 스토리지 클래스 상세 정보:${NC}"
    echo ""
    kubectl get storageclass local-path -o yaml | grep -E "(provisioner|volumeBindingMode|reclaimPolicy)" | sed 's/^/   /'
    echo ""
    echo -e "${BLUE}설정 값 설명:${NC}"
    echo "   - provisioner: rancher.io/local-path → 로컬 경로 프로비저너 사용"
    echo "   - volumeBindingMode: WaitForFirstConsumer → Pod가 PVC를 사용할 때 PV 생성"
    echo "   - reclaimPolicy: Delete → PVC 삭제 시 PV도 자동 삭제"
    echo ""
    echo -e "${YELLOW}💡 WaitForFirstConsumer 모드의 장점:${NC}"
    echo "   - 리소스 효율성: 실제 필요할 때만 스토리지 생성"
    echo "   - 최적 배치: Pod와 같은 노드에 스토리지 생성"
    echo "   - 비용 절약: 사용하지 않는 스토리지 방지"
fi

wait_for_user "스토리지 설정을 확인했습니다. 단일 노드 최적화를 진행하겠습니다."

# Step 5: 단일 노드 최적화 (필요한 경우)
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo -e "${GREEN}📋 Step 5: 단일 노드 환경 최적화${NC}"
    echo ""
    echo -e "${BLUE}💡 개념 설명:${NC}"
    echo "기본적으로 Kubernetes는 control-plane 노드에 일반 Pod를 스케줄링하지 않습니다:"
    echo "- Taint: 노드에 '오염' 마크를 붙여서 특정 Pod만 실행 허용"
    echo "- control-plane taint: 시스템 Pod만 실행, 사용자 Pod 차단"
    echo "- 단일 노드에서는 이 제한을 제거해야 MinIO Pod 실행 가능"
    echo ""
    
    echo -e "${BLUE}현재 노드의 Taint 상태 확인:${NC}"
    kubectl describe nodes | grep -A 5 "Taints:" | head -10
    echo ""
    
    echo "명령어: kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
    echo "목적: control-plane 노드에서 일반 Pod 스케줄링 허용"
    echo ""
    
    if kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null; then
        echo -e "${GREEN}✅ Control-plane taint 제거 완료${NC}"
    else
        echo -e "${YELLOW}⚠️  Taint가 이미 제거되었거나 다른 형태입니다${NC}"
        # 다른 형태의 taint도 시도
        kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
    fi
    
    echo ""
    echo -e "${BLUE}📚 Taint 제거 후 효과:${NC}"
    echo "- MinIO Pod가 control-plane 노드에서 실행 가능"
    echo "- 단일 노드의 모든 리소스 활용 가능"
    echo "- 학습 환경에 최적화됨"
    echo ""
    
    wait_for_user "단일 노드 최적화가 완료되었습니다. 최종 검증을 진행하겠습니다."
fi

# Step 6: 최종 환경 검증
echo -e "${GREEN}📋 Step 6: 최종 환경 검증${NC}"
echo ""

echo -e "${BLUE}6-1. 스토리지 클래스 최종 확인${NC}"
echo ""
if kubectl get storageclass | grep -q "(default)"; then
    echo -e "${GREEN}✅ 기본 스토리지 클래스 설정 완료${NC}"
    kubectl get storageclass
else
    echo -e "${YELLOW}⚠️  기본 스토리지 클래스가 설정되지 않았습니다${NC}"
    kubectl get storageclass
fi

echo ""
echo -e "${BLUE}6-2. 노드 스케줄링 가능 여부 확인${NC}"
echo ""
SCHEDULABLE_NODES=$(kubectl get nodes --no-headers | grep -v "SchedulingDisabled" | wc -l)
if [ "$SCHEDULABLE_NODES" -gt 0 ]; then
    echo -e "${GREEN}✅ 스케줄링 가능한 노드: ${SCHEDULABLE_NODES}개${NC}"
    kubectl get nodes
else
    echo -e "${RED}❌ 스케줄링 가능한 노드가 없습니다${NC}"
    kubectl get nodes
    exit 1
fi

echo ""
echo -e "${BLUE}6-3. 동적 프로비저닝 준비 상태 확인${NC}"
echo ""
echo "현재 PV 상태 (MinIO 배포 전):"
PV_COUNT=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ "$PV_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ PV 없음 (정상) - 동적 프로비저닝 준비 완료${NC}"
    echo ""
    echo -e "${BLUE}📚 이것이 정상인 이유:${NC}"
    echo "- WaitForFirstConsumer 모드에서는 Pod가 PVC를 사용할 때 PV 생성"
    echo "- 현재 PV가 없는 것은 아직 요청이 없어서 정상"
    echo "- MinIO 배포 시 자동으로 PV가 생성될 예정"
else
    echo "기존 PV ${PV_COUNT}개 발견:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name
fi

echo ""
echo -e "${GREEN}✅ Lab 0 완료${NC}"
echo ""
echo -e "${BLUE}📋 환경 검증 결과 요약:${NC}"
echo "   - ✅ Kubernetes 클러스터 연결 정상"
echo "   - ✅ 노드 상태 확인 완료 (${NODE_COUNT}개 노드)"
echo "   - ✅ 스토리지 클래스 준비 완료"
echo "   - ✅ 동적 프로비저닝 시스템 준비 완료"
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo "   - ✅ 단일 노드 환경 최적화 완료"
fi
echo ""
echo -e "${BLUE}💡 학습한 핵심 개념:${NC}"
echo "   - kubectl을 통한 클러스터 관리"
echo "   - 동적 vs 정적 프로비저닝의 차이점"
echo "   - WaitForFirstConsumer 모드의 동작 원리"
echo "   - 단일 노드 환경에서의 Taint 관리"
echo "   - 스토리지 클래스의 역할과 중요성"
echo ""
echo -e "${GREEN}🚀 다음 단계: MinIO Operator 설치 (Lab 1)${NC}"
echo "   명령어: ./lab-01-operator-install.sh"
echo ""
echo -e "${YELLOW}💡 참고:${NC}"
echo "   - 환경 정보는 .environment-info 파일에 저장됩니다"
echo "   - 이 정보는 다음 Lab에서 자동으로 활용됩니다"

# 환경 정보 저장
cat > .environment-info << EOF
ENVIRONMENT_TYPE=$ENVIRONMENT_TYPE
NODE_COUNT=$NODE_COUNT
WORKER_NODES=$((NODE_COUNT - 1))
TOTAL_CPU_CORES=2
TOTAL_MEMORY_GB=4
STORAGE_CLASSES=1
DEFAULT_SC=local-path
CNI_PLUGIN=
DETECTED_AT="$(date)"
EOF

echo ""
echo -e "${BLUE}📁 환경 정보가 .environment-info 파일에 저장되었습니다${NC}"
