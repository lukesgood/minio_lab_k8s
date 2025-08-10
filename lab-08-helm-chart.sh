#!/bin/bash

echo "=== Lab 8: Helm Chart 실습 (대안 방법) ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- Helm을 사용한 전통적인 MinIO 배포 방식"
echo "- Operator vs Helm 배포 방식 비교"
echo "- Helm Chart 커스터마이징"
echo "- 배포 방식별 장단점 이해"
echo ""

echo -e "${YELLOW}⚠️  주의사항:${NC}"
echo "이 Lab은 기존 MinIO Operator 배포와 별도로 진행됩니다."
echo "두 가지 배포 방식을 비교 학습하기 위한 목적입니다."
echo ""

# Helm 설치 확인
echo -e "${GREEN}1. Helm 설치 확인${NC}"
echo "명령어: helm version"
echo "목적: Helm 패키지 매니저 설치 상태 확인"
echo ""

if ! command -v helm &> /dev/null; then
    echo "Helm이 설치되지 않았습니다. 설치 중..."
    
    # OS 감지
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install helm
        else
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
    else
        echo -e "${RED}❌ 지원하지 않는 OS입니다. Helm을 수동으로 설치하세요.${NC}"
        echo "설치 가이드: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    # 설치 확인
    if command -v helm &> /dev/null; then
        echo -e "${GREEN}✅ Helm 설치 완료${NC}"
    else
        echo -e "${RED}❌ Helm 설치 실패${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Helm이 이미 설치되어 있습니다${NC}"
fi

helm version --short
echo ""

# MinIO Helm Repository 추가
echo -e "${GREEN}2. MinIO Helm Repository 추가${NC}"
echo "명령어: helm repo add minio https://charts.min.io/"
echo "목적: MinIO 공식 Helm Chart 저장소 추가"
echo ""

helm repo add minio https://charts.min.io/
helm repo update

echo "사용 가능한 MinIO Chart 확인..."
helm search repo minio
echo ""

# 네임스페이스 생성
echo -e "${GREEN}3. Helm 배포용 네임스페이스 생성${NC}"
echo "명령어: kubectl create namespace minio-helm"
echo "목적: Helm으로 배포할 MinIO를 위한 별도 네임스페이스 생성"
echo ""

if kubectl get namespace minio-helm &>/dev/null; then
    echo -e "${GREEN}✅ minio-helm 네임스페이스가 이미 존재합니다${NC}"
else
    kubectl create namespace minio-helm
    echo -e "${GREEN}✅ minio-helm 네임스페이스 생성 완료${NC}"
fi
echo ""

# Helm Chart 값 확인
echo -e "${GREEN}4. MinIO Helm Chart 기본 설정 확인${NC}"
echo "명령어: helm show values minio/minio"
echo "목적: MinIO Helm Chart의 기본 설정값 확인"
echo ""

echo "MinIO Helm Chart 기본 설정 (주요 부분):"
helm show values minio/minio | head -50
echo "... (더 많은 설정 옵션 사용 가능)"
echo ""

# 커스텀 values.yaml 생성
echo -e "${GREEN}5. 커스텀 Helm Values 파일 생성${NC}"
echo "목적: 환경에 맞는 MinIO 설정 커스터마이징"
echo ""

# 환경 감지
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 1 ]; then
    ENVIRONMENT_TYPE="single-node"
    REPLICA_COUNT=1
    STORAGE_SIZE="2Gi"
else
    ENVIRONMENT_TYPE="multi-node"
    REPLICA_COUNT=4
    STORAGE_SIZE="10Gi"
fi

echo "감지된 환경: $ENVIRONMENT_TYPE"
echo "설정값: Replicas=$REPLICA_COUNT, Storage=$STORAGE_SIZE"
echo ""

cat > minio-helm-values.yaml << EOF
# MinIO Helm Chart 커스텀 설정
# 환경: $ENVIRONMENT_TYPE

# 기본 설정
mode: distributed
replicas: $REPLICA_COUNT

# 인증 설정
rootUser: minioadmin
rootPassword: minioadmin123

# 스토리지 설정
persistence:
  enabled: true
  size: $STORAGE_SIZE
  storageClass: "local-path"
  accessMode: ReadWriteOnce

# 리소스 설정
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m

# 서비스 설정
service:
  type: ClusterIP
  port: 9000

# Console 설정
consoleService:
  type: ClusterIP
  port: 9001

# 보안 설정
securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# 메트릭 설정
metrics:
  serviceMonitor:
    enabled: false

# 단일 노드 환경 최적화
EOF

if [ "$ENVIRONMENT_TYPE" = "single-node" ]; then
    cat >> minio-helm-values.yaml << EOF

# 단일 노드 환경 추가 설정
affinity: {}
tolerations: []
nodeSelector: {}

# 단일 노드에서는 분산 모드 비활성화
mode: standalone
replicas: 1
EOF
else
    cat >> minio-helm-values.yaml << EOF

# 다중 노드 환경 추가 설정
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - minio
      topologyKey: kubernetes.io/hostname

# 다중 노드 분산 설정
mode: distributed
replicas: $REPLICA_COUNT
EOF
fi

echo "커스텀 values.yaml 파일 생성 완료:"
echo "파일명: minio-helm-values.yaml"
echo ""

# Helm Chart로 MinIO 배포
echo -e "${GREEN}6. Helm Chart로 MinIO 배포${NC}"
echo "명령어: helm install minio-helm minio/minio -f minio-helm-values.yaml -n minio-helm"
echo "목적: 커스터마이징된 설정으로 MinIO 배포"
echo ""

echo "MinIO Helm Chart 배포 중..."
helm install minio-helm minio/minio -f minio-helm-values.yaml -n minio-helm

echo ""
echo "배포 상태 확인 중..."
sleep 10

# 배포 상태 확인
echo ""
echo -e "${GREEN}7. Helm 배포 상태 확인${NC}"
echo ""

echo -e "${BLUE}7-1. Helm Release 상태${NC}"
helm list -n minio-helm
echo ""

echo -e "${BLUE}7-2. Pod 상태 확인${NC}"
kubectl get pods -n minio-helm
echo ""

echo -e "${BLUE}7-3. Service 상태 확인${NC}"
kubectl get svc -n minio-helm
echo ""

echo -e "${BLUE}7-4. PVC 상태 확인${NC}"
kubectl get pvc -n minio-helm
echo ""

# 배포 완료 대기
echo "MinIO Pod 시작 완료 대기 중..."
kubectl wait --for=condition=ready pod -l app=minio -n minio-helm --timeout=300s

# 포트 포워딩 설정
echo ""
echo -e "${GREEN}8. Helm 배포 MinIO 포트 포워딩 설정${NC}"
echo "목적: Helm으로 배포된 MinIO에 로컬에서 접근"
echo ""

echo "기존 포트 포워딩 정리..."
pkill -f "kubectl port-forward.*minio-helm" 2>/dev/null || true

echo "새로운 포트 포워딩 설정..."
kubectl port-forward svc/minio-helm -n minio-helm 9002:9000 &
HELM_MINIO_PF_PID=$!

kubectl port-forward svc/minio-helm-console -n minio-helm 9003:9001 &
HELM_CONSOLE_PF_PID=$!

echo "포트 포워딩 설정 완료 (MinIO PID: $HELM_MINIO_PF_PID, Console PID: $HELM_CONSOLE_PF_PID)"
echo "연결 대기 중..."
sleep 5

# MinIO Client 설정 (Helm 배포용)
echo ""
echo -e "${GREEN}9. Helm 배포 MinIO Client 설정${NC}"
echo ""

# MinIO Client 명령어 확인
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    if [ -f "./mc" ]; then
        MC_CMD="./mc"
    else
        echo -e "${YELLOW}⚠️  MinIO Client가 설치되지 않았습니다.${NC}"
        echo "Lab 3에서 설치한 mc를 사용하거나 다음 명령어로 설치하세요:"
        echo "curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc && chmod +x mc"
        MC_CMD="./mc"
    fi
fi

echo "Helm 배포 MinIO 서버 연결 설정..."
$MC_CMD alias set helm-minio http://localhost:9002 minioadmin minioadmin123

echo "연결 테스트..."
if $MC_CMD admin info helm-minio; then
    echo -e "${GREEN}✅ Helm 배포 MinIO 연결 성공${NC}"
else
    echo -e "${YELLOW}⚠️  연결 확인 중... (Pod 시작 완료 대기)${NC}"
fi

# 기능 테스트
echo ""
echo -e "${GREEN}10. Helm 배포 MinIO 기능 테스트${NC}"
echo ""

echo -e "${BLUE}10-1. 버킷 생성 테스트${NC}"
$MC_CMD mb helm-minio/helm-test-bucket
echo -e "${GREEN}✅ 버킷 생성 완료${NC}"

echo ""
echo -e "${BLUE}10-2. 파일 업로드 테스트${NC}"
echo "Helm MinIO Test Data - $(date)" > helm-test-file.txt
$MC_CMD cp helm-test-file.txt helm-minio/helm-test-bucket/
echo -e "${GREEN}✅ 파일 업로드 완료${NC}"

echo ""
echo -e "${BLUE}10-3. 파일 다운로드 테스트${NC}"
$MC_CMD cp helm-minio/helm-test-bucket/helm-test-file.txt helm-downloaded.txt
echo -e "${GREEN}✅ 파일 다운로드 완료${NC}"

echo ""
echo -e "${BLUE}10-4. 데이터 무결성 확인${NC}"
if diff helm-test-file.txt helm-downloaded.txt > /dev/null; then
    echo -e "${GREEN}✅ 데이터 무결성 검증 성공${NC}"
else
    echo -e "${RED}❌ 데이터 무결성 검증 실패${NC}"
fi

# Operator vs Helm 비교
echo ""
echo -e "${GREEN}11. Operator vs Helm 배포 방식 비교${NC}"
echo ""

echo -e "${BLUE}📊 배포 방식 비교 분석:${NC}"
echo ""

echo -e "${YELLOW}🔧 Helm 방식 (현재 Lab):${NC}"
echo "   장점:"
echo "   ✅ 표준 Kubernetes 리소스 사용"
echo "   ✅ 설정 커스터마이징 용이"
echo "   ✅ 버전 관리 및 롤백 지원"
echo "   ✅ 다양한 배포 옵션 제공"
echo ""
echo "   단점:"
echo "   ❌ 수동 운영 작업 필요"
echo "   ❌ 업그레이드 시 다운타임 가능"
echo "   ❌ 복잡한 운영 시나리오 처리 어려움"
echo ""

echo -e "${YELLOW}🤖 Operator 방식 (Lab 1-6):${NC}"
echo "   장점:"
echo "   ✅ 자동화된 운영 (업그레이드, 스케일링)"
echo "   ✅ MinIO 전용 최적화"
echo "   ✅ 복잡한 운영 시나리오 자동 처리"
echo "   ✅ 선언적 관리"
echo ""
echo "   단점:"
echo "   ❌ Operator 의존성"
echo "   ❌ 커스터마이징 제한"
echo "   ❌ 디버깅 복잡도 증가"
echo ""

# 실제 리소스 비교
echo -e "${BLUE}📋 실제 배포된 리소스 비교:${NC}"
echo ""

echo "Operator 배포 (minio-tenant 네임스페이스):"
kubectl get all -n minio-tenant --no-headers 2>/dev/null | wc -l | xargs echo "   총 리소스 수:"
kubectl get statefulset -n minio-tenant --no-headers 2>/dev/null | wc -l | xargs echo "   StatefulSet 수:"
kubectl get svc -n minio-tenant --no-headers 2>/dev/null | wc -l | xargs echo "   Service 수:"

echo ""
echo "Helm 배포 (minio-helm 네임스페이스):"
kubectl get all -n minio-helm --no-headers 2>/dev/null | wc -l | xargs echo "   총 리소스 수:"
kubectl get statefulset -n minio-helm --no-headers 2>/dev/null | wc -l | xargs echo "   StatefulSet 수:"
kubectl get svc -n minio-helm --no-headers 2>/dev/null | wc -l | xargs echo "   Service 수:"

# Helm 관리 명령어 소개
echo ""
echo -e "${GREEN}12. Helm 관리 명령어 소개${NC}"
echo ""

echo -e "${BLUE}📚 주요 Helm 명령어:${NC}"
echo ""

echo "배포 관리:"
echo "   helm list -n minio-helm                    # 배포된 릴리스 목록"
echo "   helm status minio-helm -n minio-helm      # 릴리스 상태 확인"
echo "   helm get values minio-helm -n minio-helm  # 현재 설정값 확인"
echo ""

echo "업그레이드 및 롤백:"
echo "   helm upgrade minio-helm minio/minio -f minio-helm-values.yaml -n minio-helm"
echo "   helm rollback minio-helm 1 -n minio-helm  # 이전 버전으로 롤백"
echo "   helm history minio-helm -n minio-helm     # 배포 히스토리 확인"
echo ""

echo "정리:"
echo "   helm uninstall minio-helm -n minio-helm   # Helm 릴리스 삭제"
echo ""

# 성능 비교 테스트 (간단한)
echo -e "${GREEN}13. 간단한 성능 비교 테스트${NC}"
echo ""

echo "Operator 배포 MinIO 응답 시간 측정..."
if curl -s -w "%{time_total}" -o /dev/null http://localhost:9000/minio/health/live 2>/dev/null; then
    OPERATOR_RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:9000/minio/health/live 2>/dev/null)
    echo "   Operator MinIO 응답 시간: ${OPERATOR_RESPONSE_TIME}초"
else
    echo "   Operator MinIO 응답 시간: 측정 불가 (포트 포워딩 확인 필요)"
fi

echo ""
echo "Helm 배포 MinIO 응답 시간 측정..."
if curl -s -w "%{time_total}" -o /dev/null http://localhost:9002/minio/health/live 2>/dev/null; then
    HELM_RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:9002/minio/health/live 2>/dev/null)
    echo "   Helm MinIO 응답 시간: ${HELM_RESPONSE_TIME}초"
else
    echo "   Helm MinIO 응답 시간: 측정 불가"
fi

# 정리 옵션 제공
echo ""
echo -e "${GREEN}14. 정리 옵션${NC}"
echo ""

echo -e "${YELLOW}정리 옵션을 선택하세요:${NC}"
echo "1) Helm 배포만 정리 (Operator 배포 유지)"
echo "2) 모든 배포 정리 (Operator + Helm)"
echo "3) 정리하지 않음 (두 배포 모두 유지)"
echo ""

read -p "선택 (1-3): " cleanup_choice

case $cleanup_choice in
    1)
        echo "Helm 배포 정리 중..."
        helm uninstall minio-helm -n minio-helm
        kubectl delete namespace minio-helm
        pkill -f "kubectl port-forward.*minio-helm" 2>/dev/null || true
        echo -e "${GREEN}✅ Helm 배포 정리 완료${NC}"
        ;;
    2)
        echo "모든 배포 정리 중..."
        helm uninstall minio-helm -n minio-helm 2>/dev/null || true
        kubectl delete namespace minio-helm 2>/dev/null || true
        kubectl delete namespace minio-tenant 2>/dev/null || true
        pkill -f "kubectl port-forward.*minio" 2>/dev/null || true
        echo -e "${GREEN}✅ 모든 배포 정리 완료${NC}"
        ;;
    3)
        echo "정리하지 않습니다. 두 배포 모두 유지됩니다."
        ;;
    *)
        echo "잘못된 선택입니다. 정리하지 않습니다."
        ;;
esac

# 임시 파일 정리
echo ""
echo -e "${GREEN}15. 임시 파일 정리${NC}"
rm -f minio-helm-values.yaml helm-test-file.txt helm-downloaded.txt

echo ""
echo -e "${GREEN}✅ Lab 8 완료${NC}"
echo "Helm Chart를 사용한 MinIO 배포 실습이 완료되었습니다."
echo ""
echo -e "${BLUE}📋 완료된 작업 요약:${NC}"
echo "   - ✅ Helm 설치 및 MinIO Repository 추가"
echo "   - ✅ 환경별 커스텀 Values 파일 생성"
echo "   - ✅ Helm Chart로 MinIO 배포"
echo "   - ✅ Helm 배포 MinIO 기능 테스트"
echo "   - ✅ Operator vs Helm 배포 방식 비교 분석"
echo "   - ✅ Helm 관리 명령어 학습"
echo ""
echo -e "${BLUE}💡 학습 포인트:${NC}"
echo "   - Helm을 통한 전통적인 Kubernetes 애플리케이션 배포"
echo "   - Values 파일을 통한 설정 커스터마이징"
echo "   - Operator vs Helm 배포 방식의 장단점 이해"
echo "   - 실제 프로덕션 환경에서의 배포 방식 선택 기준"
echo ""
echo -e "${GREEN}🎉 전체 MinIO Kubernetes Lab 완료!${NC}"
echo ""
echo -e "${BLUE}📚 학습한 내용 전체 요약:${NC}"
echo "   Lab 0: 환경 사전 검증 및 동적 프로비저닝 이해"
echo "   Lab 1: MinIO Operator 설치 및 CRD 기반 관리"
echo "   Lab 2: MinIO Tenant 배포 및 실시간 프로비저닝 관찰"
echo "   Lab 3: MinIO Client 설정 및 S3 API 기본 사용법"
echo "   Lab 4: S3 API 고급 기능 (Multipart, 메타데이터)"
echo "   Lab 5: 성능 테스트 및 벤치마킹"
echo "   Lab 6: 사용자 및 권한 관리 (IAM, 정책)"
echo "   Lab 7: 모니터링 설정 (Prometheus, Grafana)"
echo "   Lab 8: Helm Chart 배포 및 방식 비교"
echo ""
echo -e "${YELLOW}💡 다음 단계 권장사항:${NC}"
echo "   - 프로덕션 환경에서는 보안, 네트워크, 백업 정책 수립"
echo "   - 모니터링 및 알림 시스템 구축"
echo "   - 재해 복구 계획 수립"
echo "   - 성능 튜닝 및 용량 계획"
