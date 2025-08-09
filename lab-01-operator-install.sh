#!/bin/bash

echo "=== Lab 1: MinIO Operator 설치 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Operator 설치
echo "1. MinIO Operator 설치 중..."
kubectl apply -k "github.com/minio/operator?ref=v5.0.10"

echo "2. 설치 상태 확인..."
echo "Operator Pod 생성 대기 중..."
sleep 10
kubectl get pods -n minio-operator

# 단일 노드 최적화
echo "3. 단일 노드 환경 최적화..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 1 ]; then
    echo "단일 노드 감지 - Operator replica를 1로 조정..."
    kubectl scale deployment minio-operator -n minio-operator --replicas=1
    
    # 스케일링 완료 대기
    echo "스케일링 완료 대기 중..."
    kubectl wait --for=condition=available --timeout=300s deployment/minio-operator -n minio-operator
else
    echo "다중 노드 환경 - 기본 설정 유지"
fi

echo "4. 최종 상태 확인..."
kubectl get pods -n minio-operator
kubectl get deployment -n minio-operator

echo ""
echo -e "${GREEN}✅ Lab 1 완료${NC}"
echo "MinIO Operator가 성공적으로 설치되었습니다."
