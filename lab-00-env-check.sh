#!/bin/bash

echo "=== Lab 0: 환경 사전 검증 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경 감지 실행
if [ -f "./detect-environment.sh" ]; then
    echo "환경 자동 감지 실행 중..."
    ./detect-environment.sh
else
    echo -e "${YELLOW}⚠️  detect-environment.sh 파일이 없습니다.${NC}"
    echo "수동으로 환경을 확인합니다..."
    
    echo "1. 클러스터 연결 확인..."
    kubectl cluster-info
    
    echo "2. 노드 상태 확인..."
    kubectl get nodes
    
    echo "3. 스토리지 클래스 확인..."
    kubectl get storageclass
fi

echo ""
echo -e "${GREEN}✅ Lab 0 완료${NC}"
echo "환경 사전 검증이 완료되었습니다."
