#!/bin/bash

echo "=== Lab 2: MinIO Tenant 배포 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 네임스페이스 생성
echo "1. 네임스페이스 생성..."
kubectl create namespace minio-tenant --dry-run=client -o yaml | kubectl apply -f -

# 시크릿 생성
echo "2. 인증 시크릿 생성..."
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=minio
export MINIO_ROOT_PASSWORD=minio123" \
  -n minio-tenant --dry-run=client -o yaml | kubectl apply -f -

# Tenant YAML 적용
echo "3. MinIO Tenant 배포..."
if [ -f "./minio-tenant.yaml" ]; then
    kubectl apply -f minio-tenant.yaml
else
    echo -e "${YELLOW}⚠️  minio-tenant.yaml 파일이 없습니다. 기본 설정으로 생성합니다.${NC}"
    # 기본 Tenant YAML 생성 및 적용
    cat > temp-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Gi
        storageClassName: local-path
  mountPath: /export
  configuration:
    name: minio-creds-secret
  requestAutoCert: false
EOF
    kubectl apply -f temp-tenant.yaml
    rm temp-tenant.yaml
fi

echo "4. 배포 상태 확인..."
echo "Tenant 생성 대기 중..."
sleep 15

echo "Tenant 상태:"
kubectl get tenant -n minio-tenant

echo "Pod 상태:"
kubectl get pods -n minio-tenant

echo "PVC 상태:"
kubectl get pvc -n minio-tenant

echo "Service 상태:"
kubectl get svc -n minio-tenant

echo ""
echo -e "${GREEN}✅ Lab 2 완료${NC}"
echo "MinIO Tenant가 성공적으로 배포되었습니다."
echo ""
echo "다음 단계:"
echo "- Pod가 Running 상태가 될 때까지 기다리세요"
echo "- 'kubectl get pods -n minio-tenant -w' 명령어로 실시간 모니터링 가능"
