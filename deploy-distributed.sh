#!/bin/bash

echo "=== MinIO 분산 모드 배포 ==="

# 네임스페이스 생성
kubectl create namespace minio-distributed

# Helm으로 분산 모드 설치
helm install minio-distributed minio/minio \
  --namespace minio-distributed \
  --values minio-distributed-values.yaml

echo "=== 배포 상태 확인 ==="
kubectl get pods -n minio-distributed

echo "=== StatefulSet 확인 ==="
kubectl get statefulset -n minio-distributed

echo "=== PVC 확인 ==="
kubectl get pvc -n minio-distributed

echo "=== 서비스 확인 ==="
kubectl get svc -n minio-distributed

echo ""
echo "=== 접근 방법 ==="
echo "MinIO Console: kubectl port-forward svc/minio-distributed-console -n minio-distributed 9001:9001"
echo "MinIO API: kubectl port-forward svc/minio-distributed -n minio-distributed 9000:9000"

echo ""
echo "=== 클러스터 상태 확인 ==="
echo "kubectl exec -it minio-distributed-0 -n minio-distributed -- mc admin info local"
