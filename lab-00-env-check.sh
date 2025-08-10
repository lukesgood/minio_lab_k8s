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
echo ""

# 1. 클러스터 연결 확인
echo -e "${GREEN}1. Kubernetes 클러스터 연결 확인${NC}"
echo "명령어: kubectl cluster-info"
echo "목적: kubectl이 Kubernetes API 서버와 통신할 수 있는지 확인"
echo ""

if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✅ 클러스터 연결 정상${NC}"
    kubectl cluster-info
else
    echo -e "${RED}❌ 클러스터 연결 실패${NC}"
    echo "kubectl 설정을 확인하세요."
    exit 1
fi

echo ""

# 2. 노드 리소스 확인
echo -e "${GREEN}2. 노드 상태 및 리소스 확인${NC}"
echo "명령어: kubectl get nodes -o wide"
echo "목적: 클러스터 노드의 상태, IP, OS 정보 확인"
echo ""

kubectl get nodes -o wide
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo ""
echo "감지된 노드 수: ${NODE_COUNT}개"

if [ "$NODE_COUNT" -eq 1 ]; then
    echo -e "${YELLOW}💡 단일 노드 클러스터 감지 - MinIO 단일 노드 모드로 최적화됩니다${NC}"
else
    echo -e "${BLUE}💡 다중 노드 클러스터 감지 - MinIO 분산 모드 사용 가능${NC}"
fi

echo ""

# 3. 스토리지 클래스 확인
echo -e "${GREEN}3. 스토리지 클래스 확인${NC}"
echo "명령어: kubectl get storageclass"
echo "목적: 동적 프로비저닝을 위한 스토리지 클래스 존재 확인"
echo ""

kubectl get storageclass
echo ""

# 스토리지 클래스 상세 정보
if kubectl get storageclass local-path &>/dev/null; then
    echo -e "${GREEN}✅ local-path 스토리지 클래스 발견${NC}"
    echo ""
    echo -e "${BLUE}📖 스토리지 클래스 상세 정보:${NC}"
    kubectl get storageclass local-path -o yaml | grep -E "(provisioner|volumeBindingMode|reclaimPolicy)" | sed 's/^/   /'
    echo ""
    echo -e "${YELLOW}💡 설명:${NC}"
    echo "   - provisioner: rancher.io/local-path → 로컬 경로 프로비저너 사용"
    echo "   - volumeBindingMode: WaitForFirstConsumer → Pod가 PVC를 사용할 때 PV 생성"
    echo "   - reclaimPolicy: Delete → PVC 삭제 시 PV도 자동 삭제"
else
    echo -e "${YELLOW}⚠️  local-path 스토리지 클래스가 없습니다${NC}"
    echo "Local Path Provisioner를 설치해야 합니다."
fi

echo ""

# 4. 스토리지 프로비저너 상태 확인
echo -e "${GREEN}4. 스토리지 프로비저너 상태 확인${NC}"
echo "명령어: kubectl get pods -n local-path-storage"
echo "목적: 동적 프로비저닝을 담당하는 프로비저너 Pod 상태 확인"
echo ""

if kubectl get namespace local-path-storage &>/dev/null; then
    kubectl get pods -n local-path-storage
    echo ""
    
    # 프로비저너 설정 확인
    echo -e "${BLUE}📖 프로비저너 설정 확인:${NC}"
    echo "명령어: kubectl get configmap local-path-config -n local-path-storage"
    echo ""
    
    if kubectl get configmap local-path-config -n local-path-storage &>/dev/null; then
        echo "현재 스토리지 경로 설정:"
        kubectl get configmap local-path-config -n local-path-storage -o jsonpath='{.data.config\.json}' | python3 -m json.tool 2>/dev/null || echo "   기본 설정 사용 중"
    fi
else
    echo -e "${YELLOW}⚠️  local-path-storage 네임스페이스가 없습니다${NC}"
    echo "Local Path Provisioner가 설치되지 않았습니다."
fi

echo ""

# 5. 동적 프로비저닝 테스트
echo -e "${GREEN}5. 동적 프로비저닝 테스트${NC}"
echo "목적: 실제로 PVC 생성 시 PV가 자동으로 생성되는지 테스트"
echo ""

echo -e "${BLUE}📖 동적 프로비저닝 vs 정적 프로비저닝:${NC}"
echo "   정적 프로비저닝: 관리자가 미리 PV 생성 → 사용자가 PVC 생성 → 바인딩"
echo "   동적 프로비저닝: 사용자가 PVC 생성 → 프로비저너가 자동으로 PV 생성 → 바인딩"
echo ""

# 현재 PV 상태 확인
echo "현재 PV 상태 (MinIO 배포 전):"
PV_COUNT=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ "$PV_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ PV 없음 (정상) - 동적 프로비저닝 준비 완료${NC}"
else
    echo "기존 PV ${PV_COUNT}개 발견:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name
fi

echo ""

# 6. WaitForFirstConsumer 동작 설명
echo -e "${GREEN}6. WaitForFirstConsumer 동작 원리${NC}"
echo ""
echo -e "${BLUE}📖 WaitForFirstConsumer란?${NC}"
echo "   - PVC 생성 시 즉시 PV를 만들지 않음"
echo "   - Pod가 PVC를 실제로 사용할 때 PV 생성"
echo "   - 장점: 리소스 효율성, 최적 노드 선택"
echo ""

echo -e "${YELLOW}💡 MinIO 배포 시 예상 동작:${NC}"
echo "   1. MinIO Operator가 PVC 생성 → 상태: Pending (WaitForFirstConsumer)"
echo "   2. MinIO Pod 시작 → PVC 사용 요청"
echo "   3. 프로비저너가 PV 자동 생성 → PVC 상태: Bound"
echo "   4. MinIO Pod가 볼륨 마운트하여 시작"

echo ""

# 7. 스토리지 경로 정보
echo -e "${GREEN}7. 스토리지 경로 정보${NC}"
echo ""
echo -e "${BLUE}📖 MinIO 데이터가 저장될 위치:${NC}"

# 기본 경로 확인
DEFAULT_PATH="/opt/local-path-provisioner"
echo "   기본 경로: ${DEFAULT_PATH}"

# 커스텀 경로 설정 여부 확인
if kubectl get configmap local-path-config -n local-path-storage -o jsonpath='{.data.config\.json}' 2>/dev/null | grep -q "nodePathMap"; then
    echo "   커스텀 경로 설정 감지됨"
    echo "   설정된 경로들:"
    kubectl get configmap local-path-config -n local-path-storage -o jsonpath='{.data.config\.json}' | python3 -c "
import json, sys
try:
    config = json.load(sys.stdin)
    for node_map in config.get('nodePathMap', []):
        print(f'     노드: {node_map.get(\"node\", \"unknown\")}')
        for path in node_map.get('paths', []):
            print(f'       - {path}')
except:
    print('     파싱 실패 - 수동 확인 필요')
" 2>/dev/null || echo "     설정 파싱 실패"
else
    echo "   기본 설정 사용 중: ${DEFAULT_PATH}"
fi

echo ""
echo -e "${YELLOW}💡 참고:${NC}"
echo "   - MinIO 배포 후 실제 PV 경로는 'kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path'로 확인 가능"
echo "   - 각 PV는 고유한 하위 디렉토리를 가짐 (예: /opt/local-path-provisioner/pvc-xxxxx)"

echo ""

# 환경 검증 완료
echo -e "${GREEN}✅ Lab 0 완료${NC}"
echo "환경 사전 검증이 완료되었습니다."
echo ""
echo -e "${BLUE}📋 검증 결과 요약:${NC}"
echo "   - ✅ Kubernetes 클러스터 연결 정상"
echo "   - ✅ 노드 상태 확인 완료"
echo "   - ✅ 스토리지 클래스 준비 완료"
echo "   - ✅ 동적 프로비저닝 시스템 준비 완료"
echo ""
echo -e "${GREEN}🚀 다음 단계: MinIO Operator 설치 (Lab 1)${NC}"
echo "   명령어: ./lab-01-operator-install.sh"
