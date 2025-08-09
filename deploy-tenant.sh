#!/bin/bash

echo "=== MinIO Tenant 배포 시작 ==="

# Tenant 네임스페이스 생성
kubectl create namespace minio-tenant

# 사용자 시크릿 생성
kubectl create secret generic minio-user \
  --from-literal=CONSOLE_ACCESS_KEY=admin \
  --from-literal=CONSOLE_SECRET_KEY=password123 \
  -n minio-tenant

# 설정 ConfigMap 생성
kubectl create configmap minio-config \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123
export MINIO_STORAGE_CLASS_STANDARD=EC:2" \
  -n minio-tenant

# Tenant 배포
kubectl apply -f minio-tenant.yaml

echo "=== 배포 상태 확인 ==="
kubectl get pods -n minio-tenant

echo "=== 서비스 확인 ==="
kubectl get svc -n minio-tenant

echo ""
echo "=== 접근 방법 ==="
echo "MinIO API: kubectl port-forward svc/minio -n minio-tenant 9000:80"
echo "MinIO Console: kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9001"
