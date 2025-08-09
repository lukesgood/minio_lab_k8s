#!/bin/bash

echo "=== MinIO Lab 전체 환경 정리 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}⚠️  이 작업은 모든 MinIO 관련 리소스를 삭제합니다.${NC}"
echo "삭제될 항목:"
echo "- MinIO Tenant 및 관련 리소스"
echo "- MinIO Operator"
echo "- 네임스페이스 (minio-tenant, minio-operator)"
echo "- 포트 포워딩 프로세스"
echo "- 임시 파일들"
echo ""

read -p "계속하시겠습니까? (y/N): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    echo ""
    echo "정리 작업을 시작합니다..."
    
    # 1. 포트 포워딩 프로세스 종료
    echo "1. 포트 포워딩 프로세스 종료..."
    pkill -f "kubectl port-forward.*minio" 2>/dev/null || true
    echo -e "${GREEN}✅ 포트 포워딩 정리 완료${NC}"
    
    # 2. MinIO Tenant 삭제
    echo "2. MinIO Tenant 삭제..."
    kubectl delete tenant --all -n minio-tenant --ignore-not-found --timeout=60s
    echo -e "${GREEN}✅ Tenant 삭제 완료${NC}"
    
    # 3. 네임스페이스 삭제
    echo "3. 네임스페이스 삭제..."
    kubectl delete namespace minio-tenant --ignore-not-found --timeout=60s
    kubectl delete namespace minio-operator --ignore-not-found --timeout=60s
    echo -e "${GREEN}✅ 네임스페이스 삭제 완료${NC}"
    
    # 4. MinIO Operator 삭제
    echo "4. MinIO Operator 삭제..."
    kubectl delete -k "github.com/minio/operator?ref=v5.0.10" --ignore-not-found --timeout=60s 2>/dev/null || true
    echo -e "${GREEN}✅ Operator 삭제 완료${NC}"
    
    # 5. CRD 정리 (선택사항)
    echo "5. MinIO CRD 정리..."
    kubectl delete crd tenants.minio.min.io --ignore-not-found 2>/dev/null || true
    echo -e "${GREEN}✅ CRD 정리 완료${NC}"
    
    # 6. 임시 파일 정리
    echo "6. 임시 파일 정리..."
    rm -f *.txt *.dat *.json .lab-config 2>/dev/null || true
    echo -e "${GREEN}✅ 임시 파일 정리 완료${NC}"
    
    # 7. MinIO Client alias 정리
    echo "7. MinIO Client alias 정리..."
    if command -v mc &>/dev/null; then
        mc alias remove local 2>/dev/null || true
        mc alias remove testlocal 2>/dev/null || true
    fi
    echo -e "${GREEN}✅ MC alias 정리 완료${NC}"
    
    echo ""
    echo -e "${GREEN}🎉 전체 정리가 완료되었습니다!${NC}"
    echo ""
    echo "정리된 항목:"
    echo "- ✅ MinIO Tenant 및 관련 리소스"
    echo "- ✅ MinIO Operator"
    echo "- ✅ 네임스페이스"
    echo "- ✅ 포트 포워딩 프로세스"
    echo "- ✅ 임시 파일들"
    echo "- ✅ MinIO Client aliases"
    
else
    echo ""
    echo "정리 작업이 취소되었습니다."
fi

echo ""
echo "=== 정리 작업 완료 ==="
