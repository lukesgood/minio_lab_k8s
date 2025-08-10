#!/bin/bash

echo "=== MinIO Kubernetes Lab - 대화형 단계별 가이드 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 사용자 진행 확인 함수
wait_for_user() {
    echo ""
    echo -e "${YELLOW}🛑 CHECKPOINT: $1${NC}"
    echo -e "${CYAN}다음 단계로 진행하려면 Enter를 누르세요...${NC}"
    read -r
    echo ""
}

# 명령어 실행 및 설명 함수
explain_and_run() {
    local command="$1"
    local explanation="$2"
    local expected="$3"
    
    echo -e "${BLUE}💡 설명: $explanation${NC}"
    echo ""
    echo -e "${GREEN}실행할 명령어:${NC}"
    echo "$ $command"
    echo ""
    
    if [ -n "$expected" ]; then
        echo -e "${CYAN}예상 결과:${NC}"
        echo "$expected"
        echo ""
    fi
    
    echo -e "${YELLOW}명령어를 실행하고 결과를 확인하세요.${NC}"
    echo ""
}

# 개념 설명 함수
explain_concept() {
    local title="$1"
    local content="$2"
    
    echo -e "${BLUE}📚 개념 설명: $title${NC}"
    echo ""
    echo "$content"
    echo ""
}

# 메인 실습 시작
echo -e "${GREEN}🎯 MinIO Kubernetes Lab에 오신 것을 환영합니다!${NC}"
echo ""
echo "이 대화형 가이드는 단계별로 MinIO를 Kubernetes에 배포하는 과정을 안내합니다."
echo "각 단계마다 개념 설명과 체크포인트가 있어 확실히 이해하고 넘어갈 수 있습니다."
echo ""

wait_for_user "실습을 시작하시겠습니까?"

# Step 1: kubectl 확인
echo -e "${GREEN}📋 Step 1: kubectl 설치 및 연결 확인${NC}"
echo ""

explain_concept "kubectl이란?" \
"kubectl은 Kubernetes 클러스터와 통신하는 명령줄 도구입니다.
- 클러스터 상태 확인
- 리소스 생성/수정/삭제  
- 애플리케이션 배포 및 관리
- 로그 확인 및 디버깅"

explain_and_run "kubectl version --client" \
"kubectl이 설치되어 있고 정상 작동하는지 확인합니다." \
"Client Version: v1.28.0 (또는 다른 버전)
GitVersion: v1.28.0
..."

wait_for_user "kubectl 버전 정보를 확인했나요? 정상적으로 표시되었나요?"

# Step 2: 클러스터 연결 확인
echo -e "${GREEN}📋 Step 2: Kubernetes 클러스터 연결 확인${NC}"
echo ""

explain_concept "Kubernetes 클러스터 구성 요소" \
"Kubernetes 클러스터는 여러 구성 요소로 이루어져 있습니다:
- API Server: 클러스터의 '뇌' 역할, 모든 요청을 처리
- etcd: 클러스터 상태 정보를 저장하는 데이터베이스  
- CoreDNS: 클러스터 내부 서비스 이름 해석
- kubelet: 각 노드에서 Pod를 관리하는 에이전트"

explain_and_run "kubectl cluster-info" \
"kubectl이 클러스터와 통신할 수 있는지 확인합니다." \
"Kubernetes control plane is running at https://...
CoreDNS is running at https://..."

wait_for_user "클러스터 정보가 정상적으로 표시되었나요? API Server와 CoreDNS 주소가 보이나요?"

# Step 3: 노드 상태 확인
echo -e "${GREEN}📋 Step 3: 클러스터 노드 상태 확인${NC}"
echo ""

explain_concept "Kubernetes 노드 유형" \
"Kubernetes 노드는 실제 워크로드가 실행되는 컴퓨터입니다:
- Control-plane: 클러스터 관리 기능 (API 서버, etcd 등)
- Worker nodes: 실제 애플리케이션 Pod가 실행되는 노드
- Single-node: 하나의 노드가 모든 역할을 담당 (학습용)
- Multi-node: 역할이 분리된 프로덕션 환경"

explain_and_run "kubectl get nodes" \
"클러스터의 노드 수와 상태를 확인합니다." \
"NAME           STATUS   ROLES           AGE   VERSION
node-name      Ready    control-plane   1d    v1.28.0"

echo -e "${YELLOW}결과를 확인하고 다음 질문에 답해주세요:${NC}"
echo "1. 몇 개의 노드가 보이나요?"
echo "2. STATUS가 'Ready'인가요?"
echo "3. ROLES 컬럼에 'control-plane'이 있나요?"
echo ""

wait_for_user "노드 정보를 확인했나요? 단일 노드인지 다중 노드인지 파악했나요?"

# Step 4: 스토리지 클래스 확인
echo -e "${GREEN}📋 Step 4: 스토리지 클래스 확인${NC}"
echo ""

explain_concept "동적 프로비저닝 vs 정적 프로비저닝" \
"스토리지 프로비저닝 방식:
- 정적 프로비저닝: 관리자가 미리 PV 생성 → 사용자가 PVC 생성 → 바인딩
- 동적 프로비저닝: 사용자가 PVC 생성 → 프로비저너가 자동으로 PV 생성 → 바인딩

MinIO는 데이터 저장을 위해 영구 스토리지(Persistent Storage)가 필요합니다."

explain_and_run "kubectl get storageclass" \
"동적 프로비저닝을 위한 스토리지 클래스 존재를 확인합니다." \
"NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer"

echo -e "${YELLOW}결과를 확인해주세요:${NC}"
echo "- 스토리지 클래스가 보이나요?"
echo "- '(default)' 마커가 있나요?"
echo "- 'No resources found'라고 나오나요?"
echo ""

wait_for_user "스토리지 클래스 상태를 확인했나요?"

# 스토리지 클래스가 없는 경우 설치 안내
echo -e "${BLUE}💡 스토리지 클래스가 없다면 다음 단계를 진행하세요:${NC}"
echo ""

echo -e "${GREEN}📋 Step 4-1: Local Path Provisioner 설치 (필요한 경우)${NC}"
echo ""

explain_concept "Local Path Provisioner" \
"Local Path Provisioner는:
- 노드의 로컬 디스크를 사용하여 PV를 자동 생성
- 단일 노드 환경에 최적화
- /opt/local-path-provisioner 디렉토리에 데이터 저장
- WaitForFirstConsumer 모드로 효율적 리소스 사용"

explain_and_run "kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml" \
"로컬 디스크 기반 동적 스토리지 프로비저너를 설치합니다." \
"namespace/local-path-storage created
serviceaccount/local-path-provisioner-service-account created
...
storageclass.storage.k8s.io/local-path created"

wait_for_user "Local Path Provisioner 설치가 완료되었나요? 여러 리소스가 'created'되었나요?"

echo -e "${GREEN}📋 Step 4-2: 기본 스토리지 클래스 설정${NC}"
echo ""

explain_concept "기본 스토리지 클래스의 중요성" \
"기본 스토리지 클래스가 필요한 이유:
- PVC에서 storageClassName을 지정하지 않으면 기본 클래스 사용
- MinIO Operator가 자동으로 스토리지를 요청할 때 필요
- '(default)' 마커로 식별 가능"

explain_and_run 'kubectl patch storageclass local-path -p '"'"'{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'"'"'' \
"local-path를 기본 스토리지 클래스로 설정합니다." \
"storageclass.storage.k8s.io/local-path patched"

wait_for_user "기본 스토리지 클래스 설정이 완료되었나요?"

# Step 5: 단일 노드 최적화
echo -e "${GREEN}📋 Step 5: 단일 노드 최적화 (단일 노드인 경우)${NC}"
echo ""

explain_concept "Kubernetes Taint와 Toleration" \
"기본적으로 Kubernetes는 control-plane 노드에 일반 Pod를 스케줄링하지 않습니다:
- Taint: 노드에 '오염' 마크를 붙여서 특정 Pod만 실행 허용
- control-plane taint: 시스템 Pod만 실행, 사용자 Pod 차단
- 단일 노드에서는 이 제한을 제거해야 MinIO Pod 실행 가능"

echo -e "${BLUE}현재 노드의 Taint 상태를 확인해보세요:${NC}"
explain_and_run "kubectl describe nodes | grep -A 5 'Taints:'" \
"노드에 설정된 Taint를 확인합니다." \
"Taints: node-role.kubernetes.io/control-plane:NoSchedule"

wait_for_user "Taint 정보를 확인했나요? control-plane:NoSchedule이 있나요?"

explain_and_run "kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-" \
"control-plane 노드에서 일반 Pod 스케줄링을 허용합니다." \
"node/node-name untainted"

wait_for_user "Taint 제거가 완료되었나요?"

# Step 6: 최종 검증
echo -e "${GREEN}📋 Step 6: 최종 환경 검증${NC}"
echo ""

echo -e "${BLUE}모든 설정이 완료되었습니다. 최종 상태를 확인해보겠습니다.${NC}"
echo ""

explain_and_run "kubectl get storageclass" \
"스토리지 클래스가 올바르게 설정되었는지 확인합니다." \
"NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer"

explain_and_run "kubectl get nodes" \
"노드가 스케줄링 가능한 상태인지 확인합니다." \
"NAME           STATUS   ROLES           AGE   VERSION
node-name      Ready    control-plane   1d    v1.28.0"

wait_for_user "모든 설정이 정상적으로 완료되었나요?"

# 완료 및 다음 단계 안내
echo -e "${GREEN}🎉 축하합니다! 환경 설정이 모두 완료되었습니다!${NC}"
echo ""
echo -e "${BLUE}📋 완료된 설정 요약:${NC}"
echo "   ✅ kubectl 설치 및 클러스터 연결 확인"
echo "   ✅ 노드 상태 확인 및 최적화"
echo "   ✅ 스토리지 클래스 설정 완료"
echo "   ✅ 동적 프로비저닝 시스템 준비"
echo ""
echo -e "${BLUE}💡 학습한 핵심 개념:${NC}"
echo "   - kubectl을 통한 클러스터 관리"
echo "   - 동적 vs 정적 프로비저닝의 차이점"
echo "   - WaitForFirstConsumer 모드의 동작 원리"
echo "   - Kubernetes Taint와 노드 스케줄링"
echo "   - 스토리지 클래스의 역할과 중요성"
echo ""
echo -e "${GREEN}🚀 다음 단계: MinIO Operator 설치${NC}"
echo ""
echo "이제 MinIO Operator를 설치할 준비가 되었습니다."
echo "다음 명령어로 계속 진행하세요:"
echo ""
echo -e "${CYAN}./lab-01-operator-install.sh${NC}"
echo ""
echo "또는 대화형 가이드를 계속 사용하려면:"
echo -e "${CYAN}./interactive-lab-guide.sh --continue-from-lab1${NC}"
echo ""

wait_for_user "실습을 완료했습니다. 다음 단계로 진행하시겠습니까?"

echo -e "${GREEN}감사합니다! MinIO Kubernetes Lab을 계속 진행해보세요! 🚀${NC}"
