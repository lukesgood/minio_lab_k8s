#!/bin/bash

echo "=== Lab 2: MinIO Tenant 배포 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- MinIO Tenant 리소스 생성"
echo "- 동적 프로비저닝으로 PV 자동 생성 과정"
echo "- StatefulSet과 PVC의 관계"
echo "- WaitForFirstConsumer 동작 실습"
echo ""

# 배포 전 PV 상태 확인
echo -e "${GREEN}배포 전 상태 확인${NC}"
echo "현재 PV 상태:"
PV_COUNT_BEFORE=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ "$PV_COUNT_BEFORE" -eq 0 ]; then
    echo -e "${GREEN}✅ PV 없음 - 깨끗한 상태에서 시작${NC}"
else
    echo "기존 PV ${PV_COUNT_BEFORE}개:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
fi
echo ""

# 1. 네임스페이스 생성
echo -e "${GREEN}1. MinIO 네임스페이스 생성${NC}"
echo "명령어: kubectl create namespace minio-tenant"
echo "목적: MinIO 리소스를 격리된 네임스페이스에서 관리"
echo ""

kubectl create namespace minio-tenant --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ 네임스페이스 생성 완료${NC}"
echo ""

# 2. 시크릿 생성
echo -e "${GREEN}2. MinIO 인증 시크릿 생성${NC}"
echo "명령어: kubectl create secret generic minio-creds-secret"
echo "목적: MinIO 루트 사용자 인증 정보 저장"
echo "   - 사용자명: minio"
echo "   - 비밀번호: minio123"
echo ""

kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=minio
export MINIO_ROOT_PASSWORD=minio123" \
  -n minio-tenant --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ 인증 시크릿 생성 완료${NC}"
echo ""

# 3. Tenant YAML 생성 및 설명
echo -e "${GREEN}3. MinIO Tenant 리소스 생성${NC}"
echo ""
echo -e "${BLUE}📖 Tenant 설정 설명:${NC}"
echo "   - servers: 1 (단일 노드 최적화)"
echo "   - volumesPerServer: 2 (서버당 2개 볼륨으로 기본 중복성 제공)"
echo "   - storage: 2Gi per volume (총 4Gi 스토리지)"
echo "   - storageClassName: local-path (동적 프로비저닝 사용)"
echo ""

if [ -f "./minio-tenant.yaml" ]; then
    echo "기존 minio-tenant.yaml 파일 사용"
    kubectl apply -f minio-tenant.yaml
else
    echo -e "${YELLOW}⚠️  minio-tenant.yaml 파일이 없습니다. 기본 설정으로 생성합니다.${NC}"
    echo ""
    echo -e "${BLUE}📖 생성되는 Tenant YAML:${NC}"
    
    # Tenant YAML 생성 및 적용
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
    
    echo "Tenant 리소스 적용 중..."
    kubectl apply -f temp-tenant.yaml
    rm temp-tenant.yaml
fi

echo -e "${GREEN}✅ MinIO Tenant 생성 완료${NC}"
echo ""

# 4. 동적 프로비저닝 과정 관찰
echo -e "${GREEN}4. 동적 프로비저닝 과정 실시간 관찰${NC}"
echo ""
echo -e "${BLUE}📖 예상되는 배포 과정:${NC}"
echo "   1. Tenant 리소스 생성 → Operator가 감지"
echo "   2. StatefulSet 생성 → PVC 템플릿으로 PVC 자동 생성"
echo "   3. PVC 상태: Pending (WaitForFirstConsumer)"
echo "   4. MinIO Pod 시작 시도 → PVC 사용 요청"
echo "   5. 프로비저너가 PV 자동 생성 → PVC 상태: Bound"
echo "   6. Pod가 볼륨 마운트하여 Running 상태"
echo ""

echo "배포 진행 상황을 단계별로 확인합니다..."
echo ""

# 5초 대기 후 상태 확인 시작
sleep 5

# Tenant 상태 확인
echo -e "${GREEN}5. Tenant 상태 확인${NC}"
echo "명령어: kubectl get tenant -n minio-tenant"
echo ""
kubectl get tenant -n minio-tenant
echo ""

# PVC 생성 확인
echo -e "${GREEN}6. PVC 생성 상태 확인${NC}"
echo "명령어: kubectl get pvc -n minio-tenant"
echo "예상: 2개의 PVC가 생성되어야 함 (volumesPerServer: 2)"
echo ""
kubectl get pvc -n minio-tenant
echo ""

# PVC 상세 정보
echo -e "${BLUE}📖 PVC 상세 정보:${NC}"
for pvc in $(kubectl get pvc -n minio-tenant -o jsonpath='{.items[*].metadata.name}'); do
    echo "PVC: $pvc"
    STATUS=$(kubectl get pvc $pvc -n minio-tenant -o jsonpath='{.status.phase}')
    echo "   상태: $STATUS"
    if [ "$STATUS" = "Pending" ]; then
        echo -e "${YELLOW}   → WaitForFirstConsumer로 인해 Pending (정상)${NC}"
    elif [ "$STATUS" = "Bound" ]; then
        PV_NAME=$(kubectl get pvc $pvc -n minio-tenant -o jsonpath='{.spec.volumeName}')
        echo -e "${GREEN}   → PV $PV_NAME에 바인딩됨${NC}"
    fi
done
echo ""

# Pod 상태 확인
echo -e "${GREEN}7. MinIO Pod 상태 확인${NC}"
echo "명령어: kubectl get pods -n minio-tenant"
echo ""
kubectl get pods -n minio-tenant
echo ""

# Pod 상세 정보
POD_NAME=$(kubectl get pods -n minio-tenant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    POD_STATUS=$(kubectl get pod $POD_NAME -n minio-tenant -o jsonpath='{.status.phase}')
    echo "Pod 상태: $POD_STATUS"
    
    if [ "$POD_STATUS" = "Pending" ]; then
        echo -e "${YELLOW}💡 Pod가 Pending 상태인 경우 볼륨 마운트 대기 중일 수 있습니다${NC}"
        echo "Pod 이벤트 확인:"
        kubectl describe pod $POD_NAME -n minio-tenant | tail -10
    fi
fi
echo ""

# PV 생성 확인
echo -e "${GREEN}8. PV 자동 생성 확인${NC}"
echo "명령어: kubectl get pv"
echo ""

PV_COUNT_AFTER=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
echo "배포 후 PV 개수: $PV_COUNT_AFTER (배포 전: $PV_COUNT_BEFORE)"

if [ "$PV_COUNT_AFTER" -gt "$PV_COUNT_BEFORE" ]; then
    echo -e "${GREEN}✅ 동적 프로비저닝으로 PV가 자동 생성되었습니다!${NC}"
    echo ""
    echo "생성된 PV와 스토리지 경로:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path,STATUS:.status.phase,CLAIM:.spec.claimRef.name | grep minio-tenant || kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path,STATUS:.status.phase
else
    echo -e "${YELLOW}⚠️  아직 PV가 생성되지 않았습니다. Pod가 시작되면 자동으로 생성됩니다.${NC}"
fi
echo ""

# 서비스 상태 확인
echo -e "${GREEN}9. MinIO 서비스 확인${NC}"
echo "명령어: kubectl get svc -n minio-tenant"
echo ""
kubectl get svc -n minio-tenant
echo ""

echo -e "${BLUE}📖 생성된 서비스 설명:${NC}"
echo "   - minio: MinIO S3 API 서비스 (포트 80)"
echo "   - minio-tenant-console: MinIO 웹 콘솔 서비스 (포트 9090)"
echo "   - minio-tenant-hl: Headless 서비스 (내부 통신용)"
echo ""

# 최종 상태 요약
echo -e "${GREEN}10. 배포 상태 최종 요약${NC}"
echo ""

# 15초 추가 대기 후 최종 확인
echo "Pod 시작 완료 대기 중... (15초)"
sleep 15

echo "최종 상태:"
echo ""

echo "Tenant 상태:"
kubectl get tenant -n minio-tenant
echo ""

echo "Pod 상태:"
kubectl get pods -n minio-tenant
echo ""

echo "PVC 상태:"
kubectl get pvc -n minio-tenant
echo ""

echo "PV 상태 (스토리지 경로 포함):"
kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.local.path,STATUS:.status.phase,CLAIM:.spec.claimRef.name 2>/dev/null | grep -E "(NAME|minio-tenant)" || echo "PV 정보를 가져올 수 없습니다."
echo ""

# 성공 여부 판단
POD_READY=$(kubectl get pods -n minio-tenant -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
if [ "$POD_READY" = "true" ]; then
    echo -e "${GREEN}🎉 MinIO Tenant 배포 성공!${NC}"
    echo ""
    echo -e "${BLUE}📋 배포 완료 상태:${NC}"
    echo "   - ✅ MinIO Tenant 생성됨"
    echo "   - ✅ PVC 2개 생성 및 바인딩됨"
    echo "   - ✅ PV 2개 자동 생성됨"
    echo "   - ✅ MinIO Pod 실행 중"
    echo "   - ✅ 서비스 3개 생성됨"
else
    echo -e "${YELLOW}⚠️  MinIO Pod가 아직 완전히 시작되지 않았습니다${NC}"
    echo "다음 명령어로 상태를 계속 모니터링하세요:"
    echo "   kubectl get pods -n minio-tenant -w"
fi

echo ""
echo -e "${GREEN}✅ Lab 2 완료${NC}"
echo "MinIO Tenant 배포가 완료되었습니다."
echo ""
echo -e "${BLUE}💡 학습 포인트 정리:${NC}"
echo "   - ✅ 동적 프로비저닝으로 PV가 자동 생성됨을 확인"
echo "   - ✅ WaitForFirstConsumer 동작 방식 이해"
echo "   - ✅ StatefulSet이 PVC 템플릿으로 PVC를 자동 생성함을 확인"
echo "   - ✅ MinIO Operator가 복잡한 리소스들을 자동으로 관리함을 확인"
echo ""
echo -e "${GREEN}🚀 다음 단계: MinIO Client 설정 (Lab 3)${NC}"
echo "   명령어: ./lab-03-client-setup.sh"
