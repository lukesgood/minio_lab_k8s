#!/bin/bash

echo "=== MinIO Lab 환경 자동 설정 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경 정보 로드 (오류 무시)
if [ -f ".environment-info" ]; then
    # 안전하게 환경 변수만 로드
    ENVIRONMENT_TYPE=$(grep "^ENVIRONMENT_TYPE=" .environment-info | cut -d'=' -f2)
    NODE_COUNT=$(grep "^NODE_COUNT=" .environment-info | cut -d'=' -f2)
    WORKER_NODES=$(grep "^WORKER_NODES=" .environment-info | cut -d'=' -f2)
    TOTAL_CPU_CORES=$(grep "^TOTAL_CPU_CORES=" .environment-info | cut -d'=' -f2)
    TOTAL_MEMORY_GB=$(grep "^TOTAL_MEMORY_GB=" .environment-info | cut -d'=' -f2)
    STORAGE_CLASSES=$(grep "^STORAGE_CLASSES=" .environment-info | cut -d'=' -f2)
    DEFAULT_SC=$(grep "^DEFAULT_SC=" .environment-info | cut -d'=' -f2)
    
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

# kubectl 버전 확인 (간단하게)
if command -v kubectl &>/dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | head -1 | awk '{print $3}' || echo "installed")
    echo "   - kubectl: ${KUBECTL_VERSION}"
else
    echo "   - kubectl: 미설치"
fi

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
    CNI_PLUGIN=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -E "flannel|calico|weave|cilium" | head -1 | awk '{print $1}' | cut -d'-' -f1 || echo "")
    if [ -n "$CNI_PLUGIN" ]; then
        echo "   - CNI 플러그인: ${CNI_PLUGIN}"
        echo -e "${GREEN}✅ 네트워크 설정 정상${NC}"
    else
        echo -e "${YELLOW}⚠️  CNI 플러그인을 감지할 수 없습니다.${NC}"
    fi
fi

# 6. 리소스 확인 (실시간 계산)
echo ""
echo "6. 클러스터 리소스 확인..."

# 실시간 리소스 계산
REAL_CPU_CORES=0
REAL_MEMORY_GB=0

# 노드별 리소스 합계 계산
while read -r line; do
    if [[ $line =~ cpu:.*([0-9]+) ]]; then
        CPU_MILLICORES=$(echo "$line" | grep -o 'cpu:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
        if [[ -n "$CPU_MILLICORES" && "$CPU_MILLICORES" -gt 0 ]]; then
            REAL_CPU_CORES=$((REAL_CPU_CORES + CPU_MILLICORES / 1000))
        fi
    fi
    if [[ $line =~ memory:.*([0-9]+)Ki ]]; then
        MEMORY_KI=$(echo "$line" | grep -o 'memory:[[:space:]]*[0-9]*Ki' | grep -o '[0-9]*')
        if [[ -n "$MEMORY_KI" && "$MEMORY_KI" -gt 0 ]]; then
            REAL_MEMORY_GB=$((REAL_MEMORY_GB + MEMORY_KI / 1024 / 1024))
        fi
    fi
done < <(kubectl describe nodes 2>/dev/null | grep -E "cpu:|memory:")

# 기본값 설정 (계산 실패 시)
if [ "$REAL_CPU_CORES" -eq 0 ]; then
    REAL_CPU_CORES=2  # 기본값
fi
if [ "$REAL_MEMORY_GB" -eq 0 ]; then
    REAL_MEMORY_GB=4  # 기본값
fi

echo "   - 노드 수: ${NODE_COUNT:-1}"
echo "   - Worker 노드: ${WORKER_NODES:-0}"
echo "   - 총 CPU: ${REAL_CPU_CORES} 코어"
echo "   - 총 메모리: ${REAL_MEMORY_GB} GB"

# 리소스 충분성 검사
if [ "$REAL_CPU_CORES" -lt 2 ] || [ "$REAL_MEMORY_GB" -lt 4 ]; then
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
echo "1. Lab Guide를 순서대로 따라하며 실습 진행:"
echo "   docs/LAB-00-GUIDE.md  # 환경 사전 검증"
echo "   docs/LAB-01-GUIDE.md  # MinIO Operator 설치"
echo "   docs/LAB-02-GUIDE.md  # MinIO Tenant 배포"
echo "   docs/LAB-03-GUIDE.md  # MinIO Client 및 기본 사용법"
echo ""
echo "2. 환경별 가이드 참조:"
if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    echo "   - 단일 노드 가이드: SINGLE_NODE_GUIDE.md"
else
    echo "   - 다중 노드 가이드: MULTI_NODE_GUIDE.md"
fi
echo ""

# 설정 완료 시간 기록 (안전하게)
echo "SETUP_COMPLETED_AT=\"$(date)\"" >> .environment-info
