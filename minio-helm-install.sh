#!/bin/bash

echo "=== MinIO Helm Chart 설치 ==="

# MinIO Helm Repository 추가
helm repo add minio https://charts.min.io/
helm repo update

# 네임스페이스 생성
kubectl create namespace minio-helm

# MinIO 설치 (Standalone 모드)
helm install minio-standalone minio/minio \
  --namespace minio-helm \
  --set auth.rootUser=admin \
  --set auth.rootPassword=password123 \
  --set defaultBuckets="test-bucket" \
  --set persistence.size=10Gi \
  --set service.type=ClusterIP

echo "=== 설치 상태 확인 ==="
kubectl get pods -n minio-helm

echo "=== 서비스 확인 ==="
kubectl get svc -n minio-helm

echo ""
echo "=== 접근 정보 ==="
echo "MinIO Console: kubectl port-forward svc/minio-standalone -n minio-helm 9001:9001"
echo "MinIO API: kubectl port-forward svc/minio-standalone -n minio-helm 9000:9000"
echo "사용자: admin / 비밀번호: password123"
