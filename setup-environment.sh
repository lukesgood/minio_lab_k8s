#!/bin/bash

echo "=== MinIO Lab 환경 자동 설정 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경 정보 로드
if [ -f ".environment-info" ]; then
    source .environment-info
    echo -e "${BLUE}📋 감지된 환경: ${ENVIRONMENT_TYPE}${NC}"
else
    echo -e "${YELLOW}⚠️  환경 정보가 없습니다. 환경 감지를 먼저 실행하세요.${NC}"
    echo "실행: ./detect-environment.sh"
    exit 1
fi

echo ""

# 1. Kubernetes 연결 확인
echo "1. Kubernetes 클러스터 연결 확인..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Kubernetes 클러스터에 연결할 수 없습니다.${NC}"
    echo "kubectl 설정을 확인하세요."
    exit 1
fi
echo -e "${GREEN}✅ 클러스터 연결 정상${NC}"

# 2. 스토리지 프로비저너 설치
echo ""
echo "2. 스토리지 프로비저너 확인 및 설치..."

if ! kubectl get storageclass local-path &>/dev/null; then
    echo "Local Path Provisioner 설치 중..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    
    # 설치 완료 대기
    echo "설치 완료 대기 중..."
    kubectl wait --for=condition=available --timeout=300s deployment/local-path-provisioner -n local-path-storage
    
    # 기본 스토리지 클래스로 설정
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    echo -e "${GREEN}✅ Local Path Provisioner 설치 완료${NC}"
else
    echo -e "${GREEN}✅ Local Path Provisioner 이미 설치됨${NC}"
fi

# 3. 단일 노드 환경 최적화
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo ""
    echo "3. 단일 노드 환경 최적화..."
    
    # Control-plane taint 제거
    echo "   - Control-plane taint 제거..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
    kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
    
    echo -e "${GREEN}✅ 단일 노드 최적화 완료${NC}"
else
    echo ""
    echo "3. 다중 노드 환경 확인..."
    echo -e "${GREEN}✅ 다중 노드 환경 설정 완료${NC}"
fi

# 4. 필수 도구 확인
echo ""
echo "4. 필수 도구 확인..."

# kubectl 버전 확인
KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
echo "   - kubectl: ${KUBECTL_VERSION}"

# curl 확인
if command -v curl &>/dev/null; then
    echo -e "   - curl: ${GREEN}설치됨${NC}"
else
    echo -e "   - curl: ${RED}미설치${NC} (MinIO Client 다운로드에 필요)"
fi

# 5. 네트워크 정책 확인 (다중 노드 환경)
if [ "$ENVIRONMENT_TYPE" = "multi-node" ]; then
    echo ""
    echo "5. 네트워크 정책 확인..."
    
    # CNI 플러그인 확인
    if [ -n "$CNI_PLUGIN" ]; then
        echo "   - CNI 플러그인: ${CNI_PLUGIN}"
        echo -e "${GREEN}✅ 네트워크 설정 정상${NC}"
    else
        echo -e "${YELLOW}⚠️  CNI 플러그인을 감지할 수 없습니다.${NC}"
    fi
fi

# 6. 리소스 확인
echo ""
echo "6. 클러스터 리소스 확인..."
echo "   - 노드 수: ${NODE_COUNT}"
echo "   - Worker 노드: ${WORKER_NODES}"
echo "   - 총 CPU: ${TOTAL_CPU_CORES} 코어"
echo "   - 총 메모리: ${TOTAL_MEMORY_GB} GB"

# 리소스 충분성 검사
if [ "$TOTAL_CPU_CORES" -lt 2 ] || [ "$TOTAL_MEMORY_GB" -lt 4 ]; then
    echo -e "${YELLOW}⚠️  리소스가 부족할 수 있습니다. 최소 2 CPU, 4GB RAM 권장${NC}"
else
    echo -e "${GREEN}✅ 충분한 리소스 확인${NC}"
fi

# 7. 환경별 추가 설정
echo ""
echo "7. 환경별 추가 설정..."

if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    # 단일 노드용 설정 파일 생성
    cat > .lab-config << EOF
ENVIRONMENT_TYPE=single-node
MINIO_REPLICAS=1
STORAGE_CLASS=local-path
VOLUME_SIZE=2Gi
RESOURCE_REQUESTS_CPU=250m
RESOURCE_REQUESTS_MEMORY=512Mi
RESOURCE_LIMITS_CPU=500m
RESOURCE_LIMITS_MEMORY=1Gi
EOF
    echo -e "${GREEN}✅ 단일 노드 설정 완료${NC}"
else
    # 다중 노드용 설정 파일 생성
    cat > .lab-config << EOF
ENVIRONMENT_TYPE=multi-node
MINIO_REPLICAS=3
STORAGE_CLASS=local-path
VOLUME_SIZE=10Gi
RESOURCE_REQUESTS_CPU=1000m
RESOURCE_REQUESTS_MEMORY=2Gi
RESOURCE_LIMITS_CPU=2000m
RESOURCE_LIMITS_MEMORY=4Gi
EOF
    echo -e "${GREEN}✅ 다중 노드 설정 완료${NC}"
fi

# 8. 최종 검증
echo ""
echo "8. 최종 환경 검증..."

# 스토리지 클래스 재확인
if kubectl get storageclass local-path &>/dev/null; then
    echo -e "${GREEN}✅ 스토리지 클래스 준비 완료${NC}"
else
    echo -e "${RED}❌ 스토리지 클래스 설정 실패${NC}"
    exit 1
fi

# 노드 스케줄링 가능 여부 확인
SCHEDULABLE_NODES=$(kubectl get nodes --no-headers | grep -v "SchedulingDisabled" | wc -l)
if [ "$SCHEDULABLE_NODES" -gt 0 ]; then
    echo -e "${GREEN}✅ 스케줄링 가능한 노드: ${SCHEDULABLE_NODES}개${NC}"
else
    echo -e "${RED}❌ 스케줄링 가능한 노드가 없습니다${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 환경 설정이 완료되었습니다!${NC}"
echo ""
echo "다음 단계:"
echo "1. 실습 시작: ./run-lab.sh"
echo "2. 환경별 가이드 참조:"
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo "   - 단일 노드 가이드: SINGLE_NODE_GUIDE.md"
else
    echo "   - 다중 노드 가이드: MULTI_NODE_GUIDE.md"
fi
echo ""

# 설정 완료 시간 기록
echo "SETUP_COMPLETED_AT=$(date)" >> .environment-info
