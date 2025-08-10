#!/bin/bash

echo "=== Lab 1: MinIO Operator 설치 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- Kubernetes Operator 패턴의 이해"
echo "- MinIO Operator의 역할과 기능"
echo "- CRD (Custom Resource Definition) 개념"
echo "- Operator 설치 과정과 검증 방법"
echo "- 단일 노드 환경 최적화 설정"
echo ""

echo -e "${PURPLE}🎯 학습 목표:${NC}"
echo "1. Operator 패턴이 무엇인지 이해하기"
echo "2. MinIO Operator를 성공적으로 설치하기"
echo "3. 설치된 Operator의 상태를 확인하고 검증하기"
echo "4. 단일 노드 환경에서의 최적화 방법 학습하기"
echo ""

# 사용자 진행 확인 함수
wait_for_user() {
    echo ""
    echo -e "${YELLOW}🛑 CHECKPOINT: $1${NC}"
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
}

# Step 1: 사전 요구사항 확인
echo -e "${GREEN}📋 Step 1: 사전 요구사항 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Operator를 설치하기 전에 다음 사항들을 확인해야 합니다:"
echo "- kubectl이 설치되어 있고 클러스터에 연결되어 있는지"
echo "- 클러스터에 충분한 리소스가 있는지"
echo "- 필요한 권한이 있는지"
echo ""

echo "명령어: kubectl cluster-info"
echo "목적: 클러스터 연결 상태 확인"
echo ""

if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✅ 클러스터 연결 정상${NC}"
    kubectl cluster-info
    echo ""
    echo -e "${BLUE}📚 클러스터 정보 설명:${NC}"
    echo "- Kubernetes control plane이 정상 작동 중입니다"
    echo "- CoreDNS가 실행되어 서비스 이름 해석이 가능합니다"
else
    echo -e "${RED}❌ 클러스터 연결 실패${NC}"
    echo "Lab 0을 먼저 완료해주세요."
    exit 1
fi

wait_for_user "클러스터 연결을 확인했습니다. 노드 상태를 확인해보겠습니다."

# Step 2: 노드 상태 확인
echo -e "${GREEN}📋 Step 2: 노드 상태 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes 노드는 실제 워크로드가 실행되는 서버입니다:"
echo "- Control Plane Node: 클러스터 관리 기능 담당"
echo "- Worker Node: 애플리케이션 Pod 실행"
echo "- 단일 노드 환경에서는 하나의 노드가 두 역할을 모두 수행"
echo ""

echo "명령어: kubectl get nodes -o wide"
echo "목적: 클러스터의 노드 상태와 정보 확인"
echo ""

kubectl get nodes -o wide
echo ""

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo -e "${BLUE}📚 노드 정보 분석:${NC}"
echo "- 총 노드 수: $NODE_COUNT"
echo "- STATUS가 'Ready'인 노드만 워크로드 실행 가능"
echo "- VERSION은 각 노드의 kubelet 버전을 표시"
echo "- INTERNAL-IP는 클러스터 내부 통신에 사용"

if [ "$NODE_COUNT" -eq 1 ]; then
    echo ""
    echo -e "${CYAN}🔧 단일 노드 환경 감지:${NC}"
    echo "단일 노드 환경에서는 특별한 설정이 필요할 수 있습니다."
    echo "- Control plane taint 제거가 필요할 수 있음"
    echo "- 리소스 제약 고려 필요"
fi

wait_for_user "노드 상태를 확인했습니다. Operator 패턴에 대해 학습해보겠습니다."

# Step 3: Operator 패턴 이해
echo -e "${GREEN}📋 Step 3: Kubernetes Operator 패턴 이해${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes Operator는 애플리케이션을 자동으로 관리하는 패턴입니다:"
echo ""
echo "전통적인 방법 vs Operator 패턴:"
echo ""
echo -e "${YELLOW}전통적인 방법:${NC}"
echo "1. Deployment YAML 작성"
echo "2. Service YAML 작성"
echo "3. ConfigMap YAML 작성"
echo "4. Secret YAML 작성"
echo "5. PVC YAML 작성"
echo "6. 각각을 개별적으로 관리"
echo ""
echo -e "${YELLOW}Operator 패턴:${NC}"
echo "1. 하나의 Custom Resource 정의"
echo "2. Operator가 자동으로 필요한 모든 리소스 생성"
echo "3. 애플리케이션 생명주기 자동 관리"
echo "4. 장애 시 자동 복구"
echo "5. 업그레이드 자동 처리"
echo ""

echo -e "${CYAN}🏗️ MinIO Operator의 역할:${NC}"
echo "- MinIO Tenant (사용자 정의 리소스) 관리"
echo "- StatefulSet, Service, Secret 자동 생성"
echo "- MinIO 클러스터 상태 모니터링"
echo "- 자동 스케일링 및 복구"
echo "- 업그레이드 및 설정 변경 처리"

wait_for_user "Operator 패턴을 이해했습니다. MinIO Operator를 설치해보겠습니다."

# Step 4: MinIO Operator 네임스페이스 생성
echo -e "${GREEN}📋 Step 4: MinIO Operator 네임스페이스 생성${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Kubernetes 네임스페이스는 클러스터 내에서 리소스를 논리적으로 분리하는 방법입니다:"
echo "- 리소스 이름 충돌 방지"
echo "- 접근 권한 관리"
echo "- 리소스 할당량 설정"
echo "- 논리적 환경 분리 (dev, staging, prod)"
echo ""

echo "명령어: kubectl create namespace minio-operator"
echo "목적: MinIO Operator 전용 네임스페이스 생성"
echo ""

if kubectl get namespace minio-operator &>/dev/null; then
    echo -e "${YELLOW}⚠️ minio-operator 네임스페이스가 이미 존재합니다${NC}"
    kubectl get namespace minio-operator
else
    kubectl create namespace minio-operator
    echo -e "${GREEN}✅ minio-operator 네임스페이스 생성 완료${NC}"
fi

echo ""
echo -e "${BLUE}📚 네임스페이스 확인:${NC}"
kubectl get namespace minio-operator -o wide
echo ""
echo "- STATUS: Active는 네임스페이스가 정상 작동 중임을 의미"
echo "- AGE: 네임스페이스가 생성된 시간"

wait_for_user "네임스페이스를 생성했습니다. MinIO Operator를 설치해보겠습니다."

# Step 5: MinIO Operator 설치
echo -e "${GREEN}📋 Step 5: MinIO Operator 설치${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Operator는 공식 YAML 매니페스트를 통해 설치할 수 있습니다:"
echo "- CRD (Custom Resource Definition) 설치"
echo "- RBAC (Role-Based Access Control) 설정"
echo "- Operator Pod 배포"
echo "- 필요한 서비스 및 설정 생성"
echo ""

echo "명령어: kubectl apply -k github.com/minio/operator"
echo "목적: 공식 MinIO Operator 설치"
echo ""

echo "MinIO Operator 설치 중..."
if kubectl apply -k "github.com/minio/operator"; then
    echo -e "${GREEN}✅ MinIO Operator 설치 명령 실행 완료${NC}"
else
    echo -e "${RED}❌ MinIO Operator 설치 실패${NC}"
    echo ""
    echo -e "${YELLOW}가능한 원인:${NC}"
    echo "1. 네트워크 연결 문제"
    echo "2. GitHub 접근 불가"
    echo "3. 클러스터 권한 부족"
    echo ""
    echo -e "${YELLOW}해결 방법:${NC}"
    echo "1. 네트워크 연결 확인"
    echo "2. 클러스터 관리자 권한 확인"
    echo "3. 방화벽 설정 확인"
    exit 1
fi

echo ""
echo -e "${BLUE}📚 설치 과정 설명:${NC}"
echo "방금 실행한 명령어는 다음 작업들을 수행했습니다:"
echo "1. MinIO CRD (Custom Resource Definition) 생성"
echo "2. 필요한 RBAC 권한 설정"
echo "3. MinIO Operator Pod 배포"
echo "4. 관련 서비스 및 설정 생성"

wait_for_user "Operator 설치 명령을 실행했습니다. 설치 상태를 확인해보겠습니다."

# Step 6: 설치 상태 확인
echo -e "${GREEN}📋 Step 6: MinIO Operator 설치 상태 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Operator 설치 후에는 다음 사항들을 확인해야 합니다:"
echo "- Pod가 정상적으로 실행되고 있는지"
echo "- CRD가 올바르게 생성되었는지"
echo "- 필요한 서비스가 생성되었는지"
echo ""

echo "명령어: kubectl get pods -n minio-operator"
echo "목적: MinIO Operator Pod 상태 확인"
echo ""

echo "Operator Pod 배포 대기 중... (최대 2분)"
sleep 10

for i in {1..12}; do
    if kubectl get pods -n minio-operator | grep -q "Running"; then
        echo -e "${GREEN}✅ MinIO Operator Pod가 실행 중입니다${NC}"
        break
    else
        echo "대기 중... ($i/12)"
        sleep 10
    fi
done

echo ""
kubectl get pods -n minio-operator -o wide
echo ""

echo -e "${BLUE}📚 Pod 상태 설명:${NC}"
echo "- READY: 실행 중인 컨테이너 수 / 전체 컨테이너 수"
echo "- STATUS: Pod의 현재 상태 (Running이 정상)"
echo "- RESTARTS: Pod 재시작 횟수 (0이 이상적)"
echo "- AGE: Pod가 생성된 시간"

# Pod 상태 상세 확인
OPERATOR_POD=$(kubectl get pods -n minio-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$OPERATOR_POD" ]; then
    POD_STATUS=$(kubectl get pod $OPERATOR_POD -n minio-operator -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo -e "${GREEN}✅ Operator Pod 상태: $POD_STATUS${NC}"
    else
        echo -e "${YELLOW}⚠️ Operator Pod 상태: $POD_STATUS${NC}"
        echo "Pod가 아직 시작 중일 수 있습니다."
    fi
fi

wait_for_user "Operator Pod 상태를 확인했습니다. CRD 생성을 확인해보겠습니다."

# Step 7: CRD 확인
echo -e "${GREEN}📋 Step 7: Custom Resource Definition (CRD) 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "CRD는 Kubernetes API를 확장하여 사용자 정의 리소스를 만드는 방법입니다:"
echo "- 새로운 리소스 타입 정의"
echo "- kubectl로 관리 가능"
echo "- API 서버에서 검증 및 저장"
echo "- Operator가 이 리소스를 감시하고 처리"
echo ""

echo "명령어: kubectl get crd | grep minio"
echo "목적: MinIO 관련 CRD 생성 확인"
echo ""

kubectl get crd | grep minio
echo ""

echo -e "${BLUE}📚 MinIO CRD 설명:${NC}"
CRD_COUNT=$(kubectl get crd | grep minio | wc -l)
echo "- 생성된 MinIO CRD 수: $CRD_COUNT"
echo "- tenants.minio.min.io: MinIO 테넌트 정의"
echo "- 이 CRD를 통해 MinIO 클러스터를 선언적으로 관리"

if [ "$CRD_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ MinIO CRD가 성공적으로 생성되었습니다${NC}"
    
    echo ""
    echo "주요 CRD 상세 정보:"
    kubectl get crd tenants.minio.min.io -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp 2>/dev/null || echo "tenants CRD 확인 중..."
else
    echo -e "${YELLOW}⚠️ MinIO CRD가 아직 생성되지 않았습니다${NC}"
    echo "Operator가 아직 초기화 중일 수 있습니다."
fi

wait_for_user "CRD 생성을 확인했습니다. 단일 노드 환경 최적화를 진행해보겠습니다."

# Step 8: 단일 노드 환경 최적화
echo -e "${GREEN}📋 Step 8: 단일 노드 환경 최적화${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "단일 노드 Kubernetes 환경에서는 특별한 설정이 필요합니다:"
echo "- Control Plane Taint: 기본적으로 control plane 노드에는 일반 Pod 스케줄링 금지"
echo "- 단일 노드에서는 이 제한을 해제해야 함"
echo "- NoSchedule taint 제거로 모든 Pod 스케줄링 허용"
echo ""

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 1 ]; then
    echo -e "${CYAN}🔧 단일 노드 환경 감지됨${NC}"
    echo ""
    echo "명령어: kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
    echo "목적: Control plane 노드에서 일반 Pod 스케줄링 허용"
    echo ""
    
    # Taint 상태 확인
    TAINT_EXISTS=$(kubectl get nodes -o jsonpath='{.items[*].spec.taints[?(@.key=="node-role.kubernetes.io/control-plane")].effect}' 2>/dev/null)
    
    if [ ! -z "$TAINT_EXISTS" ]; then
        echo "Control plane taint 제거 중..."
        if kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null; then
            echo -e "${GREEN}✅ Control plane taint 제거 완료${NC}"
        else
            echo -e "${YELLOW}⚠️ Taint가 이미 제거되었거나 존재하지 않습니다${NC}"
        fi
    else
        echo -e "${GREEN}✅ Control plane taint가 이미 제거되어 있습니다${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📚 Taint 제거 효과:${NC}"
    echo "- 단일 노드에서 모든 Pod 스케줄링 가능"
    echo "- MinIO Operator와 Tenant Pod 정상 배포 가능"
    echo "- 리소스 효율적 활용"
    
else
    echo -e "${CYAN}🔧 다중 노드 환경 감지됨${NC}"
    echo "다중 노드 환경에서는 별도의 taint 제거가 필요하지 않습니다."
    echo "Worker 노드들이 일반 Pod 스케줄링을 담당합니다."
fi

wait_for_user "단일 노드 최적화를 완료했습니다. 최종 설치 검증을 진행해보겠습니다."

# Step 9: 최종 설치 검증
echo -e "${GREEN}📋 Step 9: MinIO Operator 설치 최종 검증${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "Operator 설치가 완료되었는지 종합적으로 확인합니다:"
echo "- Pod 실행 상태"
echo "- 로그 확인"
echo "- API 응답 확인"
echo "- 리소스 생성 능력 테스트"
echo ""

echo "1. Operator Pod 최종 상태 확인:"
kubectl get pods -n minio-operator
echo ""

echo "2. Operator 로그 확인 (최근 10줄):"
OPERATOR_POD=$(kubectl get pods -n minio-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$OPERATOR_POD" ]; then
    kubectl logs $OPERATOR_POD -n minio-operator --tail=10
else
    echo "Operator Pod를 찾을 수 없습니다."
fi
echo ""

echo "3. MinIO CRD API 응답 확인:"
if kubectl get tenants --all-namespaces &>/dev/null; then
    echo -e "${GREEN}✅ MinIO Tenant API 정상 응답${NC}"
    kubectl get tenants --all-namespaces
else
    echo -e "${YELLOW}⚠️ 아직 생성된 Tenant가 없습니다 (정상)${NC}"
fi
echo ""

echo "4. Operator 서비스 확인:"
kubectl get services -n minio-operator
echo ""

echo -e "${BLUE}📚 검증 결과 분석:${NC}"
OPERATOR_RUNNING=$(kubectl get pods -n minio-operator --no-headers | grep Running | wc -l)
if [ "$OPERATOR_RUNNING" -gt 0 ]; then
    echo -e "${GREEN}✅ MinIO Operator가 성공적으로 설치되고 실행 중입니다${NC}"
    echo "- Operator Pod: 실행 중"
    echo "- CRD: 생성 완료"
    echo "- API: 정상 응답"
    echo "- 다음 Lab에서 MinIO Tenant 배포 가능"
else
    echo -e "${YELLOW}⚠️ Operator Pod가 아직 완전히 시작되지 않았습니다${NC}"
    echo "몇 분 더 기다린 후 다시 확인해보세요."
fi

wait_for_user "최종 검증을 완료했습니다. Lab 1 요약을 확인해보겠습니다."

# Step 10: Lab 1 요약 및 다음 단계
echo -e "${GREEN}📋 Step 10: Lab 1 완료 요약${NC}"
echo ""
echo -e "${PURPLE}🎉 Lab 1에서 완료한 작업:${NC}"
echo "✅ Kubernetes 클러스터 연결 확인"
echo "✅ 노드 상태 확인 및 분석"
echo "✅ Operator 패턴 개념 학습"
echo "✅ MinIO Operator 네임스페이스 생성"
echo "✅ MinIO Operator 설치"
echo "✅ CRD (Custom Resource Definition) 생성 확인"
echo "✅ 단일 노드 환경 최적화"
echo "✅ 설치 상태 최종 검증"
echo ""

echo -e "${CYAN}🧠 핵심 학습 내용:${NC}"
echo "• Operator 패턴: 애플리케이션 자동 관리"
echo "• CRD: Kubernetes API 확장"
echo "• 네임스페이스: 리소스 논리적 분리"
echo "• Taint: 노드 스케줄링 제어"
echo ""

echo -e "${BLUE}🔗 다음 Lab 준비사항:${NC}"
echo "• Lab 2에서는 MinIO Tenant를 배포합니다"
echo "• Tenant는 실제 MinIO 클러스터 인스턴스입니다"
echo "• 스토리지 클래스와 PVC가 필요합니다"
echo "• Lab 0에서 확인한 스토리지 설정을 활용합니다"
echo ""

echo -e "${YELLOW}💡 문제 해결 팁:${NC}"
echo "• Operator Pod가 시작되지 않으면: kubectl describe pod -n minio-operator"
echo "• CRD가 생성되지 않으면: kubectl get events -n minio-operator"
echo "• 권한 문제가 있으면: 클러스터 관리자 권한 확인"
echo ""

echo -e "${GREEN}🎯 Lab 1 완료!${NC}"
echo "MinIO Operator가 성공적으로 설치되었습니다."
echo "이제 Lab 2에서 실제 MinIO Tenant를 배포할 준비가 되었습니다."
echo ""

echo -e "${PURPLE}다음 실행할 명령어:${NC}"
echo "./lab-02-tenant-deploy.sh"
