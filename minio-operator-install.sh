#!/bin/bash

echo "=== MinIO Operator 설치 시작 ==="

# MinIO Operator 네임스페이스 생성
kubectl create namespace minio-operator

# MinIO Operator 설치
kubectl apply -k "github.com/minio/operator?ref=v5.0.10"

# Operator 상태 확인
echo "Operator Pod 상태 확인 중..."
kubectl get pods -n minio-operator

# Console 접근을 위한 JWT 토큰 생성
echo "=== Console 접근 토큰 생성 ==="
kubectl -n minio-operator get secret console-sa-secret -o jsonpath="{.data.token}" | base64 --decode

echo ""
echo "=== MinIO Operator 설치 완료 ==="
echo "Console 접근: kubectl port-forward svc/console -n minio-operator 9090:9090"
