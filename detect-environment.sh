#!/bin/bash

echo "=== MinIO Kubernetes Lab 환경 감지 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경 변수 초기화
NODE_COUNT=0
WORKER_NODES=0
TOTAL_CPU=0
TOTAL_MEMORY=0
STORAGE_CLASSES=0
ENVIRONMENT_TYPE=""

echo "🔍 Kubernetes 클러스터 분석 중..."
echo ""

# 1. 노드 수 확인
echo "1. 노드 정보 분석"
echo "==================="

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl이 설치되지 않았습니다.${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes 클러스터에 연결할 수 없습니다.${NC}"
    echo "   kubectl 설정을 확인하세요."
    exit 1
fi

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
WORKER_NODES=$(kubectl get nodes --no-headers | grep -v "control-plane\|master" | wc -l)
CONTROL_PLANE_NODES=$(kubectl get nodes --no-headers | grep -E "control-plane|master" | wc -l)

echo "📊 노드 현황:"
echo "   - 전체 노드 수: ${NODE_COUNT}"
echo "   - Control Plane 노드: ${CONTROL_PLANE_NODES}"
echo "   - Worker 노드: ${WORKER_NODES}"
echo ""

# 2. 리소스 분석
echo "2. 리소스 분석"
echo "=============="

# CPU 및 메모리 계산
while IFS= read -r line; do
    CPU=$(echo "$line" | awk '{print $3}' | sed 's/m$//')
    MEMORY=$(echo "$line" | awk '{print $4}' | sed 's/Ki$//')
    
    if [[ "$CPU" =~ ^[0-9]+$ ]]; then
        TOTAL_CPU=$((TOTAL_CPU + CPU))
    fi
    
    if [[ "$MEMORY" =~ ^[0-9]+$ ]]; then
        TOTAL_MEMORY=$((TOTAL_MEMORY + MEMORY))
    fi
done < <(kubectl describe nodes | grep -A 2 "Allocatable:" | grep -E "cpu:|memory:" | paste - -)

TOTAL_CPU_CORES=$((TOTAL_CPU / 1000))
TOTAL_MEMORY_GB=$((TOTAL_MEMORY / 1024 / 1024))

echo "💻 총 리소스:"
echo "   - CPU: ${TOTAL_CPU_CORES} 코어"
echo "   - Memory: ${TOTAL_MEMORY_GB} GB"
echo ""

# 3. 스토리지 클래스 확인
echo "3. 스토리지 분석"
echo "==============="

STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
DEFAULT_SC=$(kubectl get storageclass --no-headers 2>/dev/null | grep "(default)" | awk '{print $1}')

echo "💾 스토리지 클래스:"
echo "   - 사용 가능한 스토리지 클래스: ${STORAGE_CLASSES}개"

if [ -n "$DEFAULT_SC" ]; then
    echo "   - 기본 스토리지 클래스: ${DEFAULT_SC}"
else
    echo -e "   - ${YELLOW}⚠️  기본 스토리지 클래스가 설정되지 않음${NC}"
fi

# 스토리지 클래스 목록 표시
if [ "$STORAGE_CLASSES" -gt 0 ]; then
    echo "   - 스토리지 클래스 목록:"
    kubectl get storageclass --no-headers 2>/dev/null | while read -r line; do
        SC_NAME=$(echo "$line" | awk '{print $1}')
        SC_PROVISIONER=$(echo "$line" | awk '{print $2}')
        echo "     * ${SC_NAME} (${SC_PROVISIONER})"
    done
fi
echo ""

# 4. 네트워크 분석
echo "4. 네트워크 분석"
echo "==============="

CNI_PLUGIN=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -E "flannel|calico|weave|cilium" | head -1 | awk '{print $1}' | cut -d'-' -f1)

if [ -n "$CNI_PLUGIN" ]; then
    echo "🌐 네트워크:"
    echo "   - CNI 플러그인: ${CNI_PLUGIN}"
else
    echo "🌐 네트워크:"
    echo "   - CNI 플러그인: 감지되지 않음"
fi
echo ""

# 5. 환경 유형 결정
echo "5. 환경 유형 결정"
echo "================="

# 환경 결정 로직
if [ "$NODE_COUNT" -eq 1 ] && [ "$WORKER_NODES" -eq 0 ]; then
    ENVIRONMENT_TYPE="single-node"
    RECOMMENDATION="단일 노드 환경"
    REASON="Control-plane 노드 1개만 존재"
elif [ "$NODE_COUNT" -eq 1 ] && [ "$WORKER_NODES" -eq 1 ]; then
    ENVIRONMENT_TYPE="single-node"
    RECOMMENDATION="단일 노드 환경"
    REASON="전체 노드 1개 (Worker 노드로 분류되었지만 실질적으로 단일 노드)"
elif [ "$WORKER_NODES" -lt 3 ]; then
    ENVIRONMENT_TYPE="single-node"
    RECOMMENDATION="단일 노드 환경"
    REASON="Worker 노드가 3개 미만 (고가용성 불가)"
elif [ "$WORKER_NODES" -ge 3 ] && [ "$TOTAL_CPU_CORES" -ge 12 ] && [ "$TOTAL_MEMORY_GB" -ge 24 ]; then
    ENVIRONMENT_TYPE="multi-node"
    RECOMMENDATION="다중 노드 환경"
    REASON="충분한 노드 수와 리소스 보유"
else
    ENVIRONMENT_TYPE="single-node"
    RECOMMENDATION="단일 노드 환경"
    REASON="리소스가 다중 노드 환경에 부족"
fi

echo "🎯 권장 환경: ${RECOMMENDATION}"
echo "📝 판단 근거: ${REASON}"
echo ""

# 6. 상세 분석 결과
echo "6. 상세 분석 결과"
echo "================="

if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo -e "${BLUE}📋 단일 노드 환경 분석:${NC}"
    echo ""
    
    # 장점
    echo -e "${GREEN}✅ 장점:${NC}"
    echo "   - 설정이 간단하고 빠름"
    echo "   - 리소스 요구사항이 낮음"
    echo "   - 학습 및 개발에 적합"
    echo "   - 네트워크 지연시간 최소"
    echo ""
    
    # 단점
    echo -e "${YELLOW}⚠️  제한사항:${NC}"
    echo "   - 고가용성 없음 (단일 장애점)"
    echo "   - 확장성 제한"
    echo "   - 프로덕션 환경 부적합"
    echo "   - Erasure Coding 제한적"
    echo ""
    
    # 권장사항
    echo -e "${BLUE}💡 권장사항:${NC}"
    if [ "$STORAGE_CLASSES" -eq 0 ]; then
        echo "   - Local Path Provisioner 설치 필요"
    fi
    
    # Control-plane taint 확인
    TAINT_EXISTS=$(kubectl describe nodes | grep -c "node-role.kubernetes.io/control-plane:NoSchedule" || true)
    if [ "$TAINT_EXISTS" -gt 0 ]; then
        echo "   - Control-plane taint 제거 필요"
    fi
    
    echo "   - 학습 목적으로 사용 권장"
    echo "   - 프로덕션 사용 시 다중 노드로 확장 고려"
    
else
    echo -e "${BLUE}📋 다중 노드 환경 분석:${NC}"
    echo ""
    
    # 장점
    echo -e "${GREEN}✅ 장점:${NC}"
    echo "   - 고가용성 지원"
    echo "   - 수평 확장 가능"
    echo "   - 프로덕션 환경 적합"
    echo "   - 완전한 Erasure Coding 지원"
    echo ""
    
    # 고려사항
    echo -e "${YELLOW}⚠️  고려사항:${NC}"
    echo "   - 설정 복잡도 높음"
    echo "   - 더 많은 리소스 필요"
    echo "   - 네트워크 성능 중요"
    echo "   - 분산 스토리지 권장"
    echo ""
    
    # 권장사항
    echo -e "${BLUE}💡 권장사항:${NC}"
    if [ "$STORAGE_CLASSES" -eq 0 ]; then
        echo "   - 분산 스토리지 시스템 설치 권장 (Ceph, GlusterFS 등)"
    fi
    echo "   - 노드별 리소스 모니터링 설정"
    echo "   - 네트워크 성능 최적화"
    echo "   - 백업 및 재해복구 계획 수립"
fi

echo ""

# 7. 다음 단계 안내
echo "7. 다음 단계"
echo "==========="

echo -e "${GREEN}🚀 권장 실행 명령어:${NC}"
echo ""

if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo "# 단일 노드 환경 설정 및 실습"
    echo "./setup-single-node.sh"
    echo "./run-single-node-lab.sh"
    echo ""
    echo "# 또는 자동 설정"
    echo "./auto-setup.sh single-node"
else
    echo "# 다중 노드 환경 설정 및 실습"
    echo "./setup-multi-node.sh"
    echo "./run-multi-node-lab.sh"
    echo ""
    echo "# 또는 자동 설정"
    echo "./auto-setup.sh multi-node"
fi

echo ""
echo -e "${BLUE}📖 관련 문서:${NC}"
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo "   - 단일 노드 가이드: SINGLE_NODE_GUIDE.md"
else
    echo "   - 다중 노드 가이드: MULTI_NODE_GUIDE.md"
fi
echo "   - 환경 선택 가이드: SELECT_ENVIRONMENT.md"
echo "   - 트러블슈팅 가이드: troubleshooting-guide.md"

echo ""
echo "=== 환경 감지 완료 ==="

# 환경 정보를 파일로 저장
cat > .environment-info << EOF
ENVIRONMENT_TYPE=${ENVIRONMENT_TYPE}
NODE_COUNT=${NODE_COUNT}
WORKER_NODES=${WORKER_NODES}
TOTAL_CPU_CORES=${TOTAL_CPU_CORES}
TOTAL_MEMORY_GB=${TOTAL_MEMORY_GB}
STORAGE_CLASSES=${STORAGE_CLASSES}
DEFAULT_SC=${DEFAULT_SC}
CNI_PLUGIN=${CNI_PLUGIN}
DETECTED_AT=$(date)
EOF

echo ""
echo -e "${GREEN}💾 환경 정보가 .environment-info 파일에 저장되었습니다.${NC}"
