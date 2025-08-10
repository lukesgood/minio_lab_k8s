#!/bin/bash

echo "=== Lab 2: MinIO Tenant 배포 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 이 Lab에서 배우는 내용:${NC}"
echo "- MinIO Tenant 개념과 역할"
echo "- 실시간 동적 프로비저닝 관찰"
echo "- StatefulSet과 PVC의 관계"
echo "- WaitForFirstConsumer 동작 원리"
echo "- MinIO 클러스터 배포 과정"
echo "- 실제 스토리지 경로 확인"
echo ""

echo -e "${PURPLE}🎯 학습 목표:${NC}"
echo "1. MinIO Tenant가 무엇인지 이해하기"
echo "2. 동적 프로비저닝이 실제로 어떻게 작동하는지 관찰하기"
echo "3. MinIO Tenant를 성공적으로 배포하기"
echo "4. 배포된 MinIO 클러스터의 상태를 확인하고 검증하기"
echo "5. 실제 데이터 저장 위치를 확인하기"
echo ""

# 사용자 진행 확인 함수
wait_for_user() {
    echo ""
    echo -e "${YELLOW}🛑 CHECKPOINT: $1${NC}"
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
}

# Step 1: 사전 요구사항 확인
echo -e "${GREEN}📋 Step 1: 사전 요구사항 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant를 배포하기 전에 다음 사항들을 확인해야 합니다:"
echo "- MinIO Operator가 정상 실행 중인지"
echo "- 스토리지 클래스가 설정되어 있는지"
echo "- 클러스터에 충분한 리소스가 있는지"
echo ""

echo "1. MinIO Operator 상태 확인:"
echo "명령어: kubectl get pods -n minio-operator"
echo ""

if kubectl get pods -n minio-operator | grep -q "Running"; then
    echo -e "${GREEN}✅ MinIO Operator가 실행 중입니다${NC}"
    kubectl get pods -n minio-operator
else
    echo -e "${RED}❌ MinIO Operator가 실행되지 않았습니다${NC}"
    echo "Lab 1을 먼저 완료해주세요."
    exit 1
fi

echo ""
echo "2. 스토리지 클래스 확인:"
echo "명령어: kubectl get storageclass"
echo ""

kubectl get storageclass
echo ""

DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [ ! -z "$DEFAULT_SC" ]; then
    echo -e "${GREEN}✅ 기본 스토리지 클래스: $DEFAULT_SC${NC}"
else
    echo -e "${YELLOW}⚠️ 기본 스토리지 클래스가 설정되지 않았습니다${NC}"
    echo "Lab 0에서 스토리지 설정을 확인해주세요."
fi

echo ""
echo -e "${BLUE}📚 스토리지 클래스 설명:${NC}"
echo "- (default): 기본으로 사용될 스토리지 클래스"
echo "- PROVISIONER: 실제 스토리지를 생성하는 컴포넌트"
echo "- RECLAIMPOLICY: PV 삭제 시 데이터 처리 방법"
echo "- VOLUMEBINDINGMODE: PV 생성 시점 결정"

wait_for_user "사전 요구사항을 확인했습니다. MinIO Tenant 개념을 학습해보겠습니다."

# Step 2: MinIO Tenant 개념 이해
echo -e "${GREEN}📋 Step 2: MinIO Tenant 개념 이해${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant는 독립적인 MinIO 클러스터 인스턴스입니다:"
echo ""
echo -e "${CYAN}🏗️ Tenant vs Operator 관계:${NC}"
echo ""
echo "MinIO Operator (관리자):"
echo "- 클러스터에 하나만 설치"
echo "- 여러 Tenant를 관리"
echo "- CRD를 통해 Tenant 정의 감시"
echo "- 자동으로 필요한 리소스 생성"
echo ""
echo "MinIO Tenant (실제 서비스):"
echo "- 독립적인 MinIO 클러스터"
echo "- 고유한 사용자 및 버킷"
echo "- 전용 스토리지 및 네트워크"
echo "- 개별적인 설정 및 정책"
echo ""

echo -e "${YELLOW}🔄 Tenant 배포 시 생성되는 리소스:${NC}"
echo "1. StatefulSet: MinIO 서버 Pod 관리"
echo "2. Service: 네트워크 접근 제공"
echo "3. PVC: 영구 스토리지 요청"
echo "4. Secret: 인증 정보 저장"
echo "5. ConfigMap: 설정 정보 저장"
echo ""

echo -e "${PURPLE}📊 실시간 프로비저닝 관찰 계획:${NC}"
echo "이번 Lab에서는 다음 과정을 실시간으로 관찰합니다:"
echo "1. Tenant 배포 전: PV 상태 확인 (none 상태)"
echo "2. Tenant 배포: PVC 생성 및 Pending 상태"
echo "3. Pod 스케줄링: WaitForFirstConsumer 트리거"
echo "4. PV 자동 생성: 프로비저너 동작"
echo "5. PVC Bound: 스토리지 연결 완료"
echo "6. Pod Running: MinIO 서비스 시작"

wait_for_user "Tenant 개념을 이해했습니다. 배포 전 상태를 확인해보겠습니다."

# Step 3: 배포 전 상태 확인
echo -e "${GREEN}📋 Step 3: 배포 전 클러스터 상태 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "동적 프로비저닝의 핵심 특징을 이해하기 위해 배포 전 상태를 확인합니다:"
echo "- PV (Persistent Volume): 실제 스토리지 리소스"
echo "- PVC (Persistent Volume Claim): 스토리지 요청"
echo "- 동적 프로비저닝: 필요할 때 자동으로 PV 생성"
echo ""

echo "1. 현재 PV 상태 확인:"
echo "명령어: kubectl get pv"
echo ""

PV_COUNT_BEFORE=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
echo "배포 전 PV 개수: $PV_COUNT_BEFORE"

if [ "$PV_COUNT_BEFORE" -eq 0 ]; then
    echo -e "${CYAN}📝 중요한 관찰 포인트:${NC}"
    echo "현재 PV가 없는 상태입니다. 이는 정상입니다!"
    echo "동적 프로비저닝에서는 PVC가 생성되고 Pod가 스케줄링될 때"
    echo "비로소 PV가 자동으로 생성됩니다."
else
    echo "기존 PV 목록:"
    kubectl get pv
fi

echo ""
echo "2. 현재 PVC 상태 확인:"
echo "명령어: kubectl get pvc --all-namespaces"
echo ""

kubectl get pvc --all-namespaces
PVC_COUNT_BEFORE=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
echo "배포 전 PVC 개수: $PVC_COUNT_BEFORE"

echo ""
echo "3. MinIO 관련 네임스페이스 확인:"
echo "명령어: kubectl get namespaces | grep minio"
echo ""

kubectl get namespaces | grep minio
echo ""

echo -e "${BLUE}📚 현재 상태 분석:${NC}"
echo "- PV 개수: $PV_COUNT_BEFORE (동적 프로비저닝에서는 0이 정상)"
echo "- PVC 개수: $PVC_COUNT_BEFORE"
echo "- MinIO Operator: 설치됨"
echo "- MinIO Tenant: 아직 없음"

wait_for_user "배포 전 상태를 확인했습니다. MinIO Tenant 네임스페이스를 생성해보겠습니다."

# Step 4: MinIO Tenant 네임스페이스 생성
echo -e "${GREEN}📋 Step 4: MinIO Tenant 네임스페이스 생성${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant는 별도의 네임스페이스에 배포하는 것이 좋습니다:"
echo "- Operator와 Tenant 분리"
echo "- 리소스 관리 용이성"
echo "- 보안 및 접근 제어"
echo "- 다중 Tenant 환경 준비"
echo ""

echo "명령어: kubectl create namespace minio-tenant"
echo "목적: MinIO Tenant 전용 네임스페이스 생성"
echo ""

if kubectl get namespace minio-tenant &>/dev/null; then
    echo -e "${YELLOW}⚠️ minio-tenant 네임스페이스가 이미 존재합니다${NC}"
    kubectl get namespace minio-tenant
else
    kubectl create namespace minio-tenant
    echo -e "${GREEN}✅ minio-tenant 네임스페이스 생성 완료${NC}"
fi

echo ""
echo -e "${BLUE}📚 네임스페이스 구조:${NC}"
kubectl get namespaces | grep minio
echo ""
echo "- minio-operator: Operator 관리 컴포넌트"
echo "- minio-tenant: 실제 MinIO 서비스"

# Step 5: MinIO 인증 정보 설정
echo -e "${GREEN}📋 Step 5: MinIO 인증 정보 설정${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant는 관리자 계정 정보가 필요합니다:"
echo "- Root User: MinIO 관리자 사용자명"
echo "- Root Password: MinIO 관리자 비밀번호"
echo "- Kubernetes Secret으로 안전하게 저장"
echo "- Tenant 배포 시 자동으로 참조"
echo ""

echo "명령어: kubectl create secret generic minio-creds-secret"
echo "목적: MinIO 관리자 인증 정보를 Kubernetes Secret으로 생성"
echo ""

echo "MinIO 인증 정보 생성 중..."
if kubectl get secret minio-creds-secret -n minio-tenant &>/dev/null; then
    echo -e "${YELLOW}⚠️ minio-creds-secret이 이미 존재합니다${NC}"
    kubectl get secret minio-creds-secret -n minio-tenant
else
    kubectl create secret generic minio-creds-secret \
        --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
        -n minio-tenant
    
    echo -e "${GREEN}✅ MinIO 인증 정보 Secret 생성 완료${NC}"
fi

echo ""
echo -e "${BLUE}📚 인증 정보 설명:${NC}"
echo "- 사용자명: admin"
echo "- 비밀번호: password123"
echo "- 실제 운영환경에서는 강력한 비밀번호 사용 필요"
echo "- Secret은 base64로 인코딩되어 저장됨"

echo ""
echo "생성된 Secret 확인:"
kubectl get secret minio-creds-secret -n minio-tenant -o yaml | grep -A 5 "data:"

wait_for_user "인증 정보를 설정했습니다. MinIO Tenant YAML을 생성해보겠습니다."

# Step 6: MinIO Tenant YAML 생성
echo -e "${GREEN}📋 Step 6: MinIO Tenant YAML 생성${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant는 Custom Resource로 정의됩니다:"
echo "- apiVersion: minio.min.io/v2"
echo "- kind: Tenant"
echo "- spec: MinIO 클러스터 설정"
echo "- pools: 스토리지 풀 구성"
echo ""

echo "Tenant YAML 파일 생성 중..."

cat > minio-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z
  credsSecret:
    name: minio-creds-secret
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 4
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
        storageClassName: local-path
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
  requestAutoCert: false
  console:
    image: quay.io/minio/console:v0.22.5
    replicas: 1
    resources:
      requests:
        memory: 256Mi
        cpu: 250m
      limits:
        memory: 512Mi
        cpu: 500m
EOF

echo -e "${GREEN}✅ MinIO Tenant YAML 생성 완료${NC}"
echo ""

echo -e "${BLUE}📚 YAML 구성 설명:${NC}"
echo "• metadata.name: minio-tenant (Tenant 이름)"
echo "• spec.image: 사용할 MinIO 이미지 버전"
echo "• spec.credsSecret: 인증 정보 Secret 참조"
echo "• spec.pools: 스토리지 풀 설정"
echo "  - servers: 1 (단일 서버)"
echo "  - volumesPerServer: 4 (서버당 볼륨 4개)"
echo "  - storage: 10Gi (볼륨당 10GB)"
echo "• spec.console: MinIO 웹 콘솔 설정"

echo ""
echo "생성된 YAML 파일 확인:"
echo "파일명: minio-tenant.yaml"
ls -la minio-tenant.yaml

wait_for_user "Tenant YAML을 생성했습니다. 실시간 모니터링을 시작해보겠습니다."

# Step 7: 실시간 모니터링 준비
echo -e "${GREEN}📋 Step 7: 실시간 프로비저닝 모니터링 준비${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "동적 프로비저닝 과정을 실시간으로 관찰하기 위해 모니터링을 설정합니다:"
echo "- PV/PVC 상태 변화 추적"
echo "- Pod 생성 및 스케줄링 과정"
echo "- 스토리지 바인딩 과정"
echo "- 서비스 시작 과정"
echo ""

echo -e "${CYAN}🔍 모니터링할 리소스:${NC}"
echo "1. PersistentVolume (PV)"
echo "2. PersistentVolumeClaim (PVC)"
echo "3. Pod"
echo "4. StatefulSet"
echo "5. Service"
echo ""

echo "모니터링 스크립트 생성 중..."

cat > monitor-deployment.sh << 'EOF'
#!/bin/bash

echo "=== MinIO Tenant 배포 실시간 모니터링 ==="
echo "Ctrl+C로 중단할 수 있습니다."
echo ""

while true; do
    clear
    echo "=== $(date) ==="
    echo ""
    
    echo "1. PersistentVolume 상태:"
    kubectl get pv 2>/dev/null || echo "PV 없음"
    echo ""
    
    echo "2. PersistentVolumeClaim 상태:"
    kubectl get pvc -n minio-tenant 2>/dev/null || echo "PVC 없음"
    echo ""
    
    echo "3. Pod 상태:"
    kubectl get pods -n minio-tenant 2>/dev/null || echo "Pod 없음"
    echo ""
    
    echo "4. StatefulSet 상태:"
    kubectl get statefulset -n minio-tenant 2>/dev/null || echo "StatefulSet 없음"
    echo ""
    
    echo "5. Service 상태:"
    kubectl get svc -n minio-tenant 2>/dev/null || echo "Service 없음"
    echo ""
    
    sleep 5
done
EOF

chmod +x monitor-deployment.sh

echo -e "${GREEN}✅ 모니터링 스크립트 생성 완료${NC}"
echo ""
echo -e "${YELLOW}📋 모니터링 실행 방법:${NC}"
echo "1. 새 터미널 창을 열어주세요"
echo "2. 다음 명령어를 실행하세요: ./monitor-deployment.sh"
echo "3. 이 터미널에서는 Tenant 배포를 진행합니다"
echo ""

wait_for_user "모니터링 준비가 완료되었습니다. 이제 MinIO Tenant를 배포해보겠습니다."

# Step 8: MinIO Tenant 배포
echo -e "${GREEN}📋 Step 8: MinIO Tenant 배포${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "이제 실제로 MinIO Tenant를 배포합니다:"
echo "- kubectl apply로 Tenant 리소스 생성"
echo "- Operator가 자동으로 필요한 리소스 생성"
echo "- 동적 프로비저닝 과정 시작"
echo "- 실시간으로 변화 관찰 가능"
echo ""

echo -e "${CYAN}🚀 배포 과정 예상 순서:${NC}"
echo "1. Tenant 리소스 생성"
echo "2. StatefulSet 생성"
echo "3. PVC 생성 (Pending 상태)"
echo "4. Pod 생성 시도"
echo "5. PV 자동 생성 (프로비저너 동작)"
echo "6. PVC Bound 상태로 변경"
echo "7. Pod Running 상태로 변경"
echo "8. Service 생성 및 활성화"
echo ""

echo "명령어: kubectl apply -f minio-tenant.yaml"
echo "목적: MinIO Tenant 배포 시작"
echo ""

read -p "배포를 시작하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "MinIO Tenant 배포 시작..."
    kubectl apply -f minio-tenant.yaml
    
    echo -e "${GREEN}✅ MinIO Tenant 배포 명령 실행 완료${NC}"
    echo ""
    echo -e "${YELLOW}📊 실시간 상태 확인:${NC}"
    echo "다른 터미널에서 ./monitor-deployment.sh를 실행하여"
    echo "배포 과정을 실시간으로 관찰해보세요!"
else
    echo "배포를 취소했습니다."
    exit 0
fi

wait_for_user "Tenant 배포를 시작했습니다. 배포 진행 상황을 확인해보겠습니다."

# Step 9: 배포 진행 상황 확인
echo -e "${GREEN}📋 Step 9: 배포 진행 상황 단계별 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "배포 과정을 단계별로 확인하여 동적 프로비저닝을 이해합니다:"
echo "- 각 단계별 상태 변화 관찰"
echo "- 문제 발생 시 원인 분석"
echo "- 정상 동작 확인"
echo ""

echo "1단계: Tenant 리소스 생성 확인"
echo "명령어: kubectl get tenant -n minio-tenant"
echo ""

sleep 5
kubectl get tenant -n minio-tenant
echo ""

echo "2단계: StatefulSet 생성 확인"
echo "명령어: kubectl get statefulset -n minio-tenant"
echo ""

sleep 5
kubectl get statefulset -n minio-tenant
echo ""

echo "3단계: PVC 생성 및 상태 확인"
echo "명령어: kubectl get pvc -n minio-tenant"
echo ""

sleep 5
kubectl get pvc -n minio-tenant
echo ""

echo -e "${CYAN}📝 PVC 상태 분석:${NC}"
PVC_STATUS=$(kubectl get pvc -n minio-tenant --no-headers 2>/dev/null | awk '{print $2}' | head -1)
if [ "$PVC_STATUS" = "Pending" ]; then
    echo "PVC가 Pending 상태입니다. 이는 정상입니다!"
    echo "WaitForFirstConsumer 모드에서는 Pod가 스케줄링될 때까지 대기합니다."
elif [ "$PVC_STATUS" = "Bound" ]; then
    echo "PVC가 이미 Bound 상태입니다. 프로비저닝이 완료되었습니다!"
else
    echo "PVC 상태: $PVC_STATUS"
fi

echo ""
echo "4단계: Pod 생성 및 스케줄링 확인"
echo "명령어: kubectl get pods -n minio-tenant"
echo ""

sleep 5
kubectl get pods -n minio-tenant
echo ""

echo "5단계: PV 자동 생성 확인"
echo "명령어: kubectl get pv"
echo ""

sleep 5
kubectl get pv
PV_COUNT_AFTER=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
echo ""
echo -e "${CYAN}📊 PV 생성 분석:${NC}"
echo "배포 전 PV 개수: $PV_COUNT_BEFORE"
echo "배포 후 PV 개수: $PV_COUNT_AFTER"
if [ "$PV_COUNT_AFTER" -gt "$PV_COUNT_BEFORE" ]; then
    echo -e "${GREEN}✅ 동적 프로비저닝으로 PV가 자동 생성되었습니다!${NC}"
else
    echo -e "${YELLOW}⚠️ PV가 아직 생성되지 않았습니다. 조금 더 기다려보세요.${NC}"
fi

wait_for_user "배포 진행 상황을 확인했습니다. 배포 완료를 기다려보겠습니다."

# Step 10: 배포 완료 대기 및 확인
echo -e "${GREEN}📋 Step 10: MinIO Tenant 배포 완료 대기${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "MinIO Tenant가 완전히 시작되기까지 시간이 걸립니다:"
echo "- 이미지 다운로드"
echo "- 스토리지 초기화"
echo "- MinIO 서버 시작"
echo "- 헬스체크 통과"
echo ""

echo "배포 완료 대기 중... (최대 5분)"
echo "실시간 상태는 다른 터미널의 모니터링 스크립트에서 확인하세요."
echo ""

# Pod가 Running 상태가 될 때까지 대기
for i in {1..30}; do
    RUNNING_PODS=$(kubectl get pods -n minio-tenant --no-headers 2>/dev/null | grep Running | wc -l)
    TOTAL_PODS=$(kubectl get pods -n minio-tenant --no-headers 2>/dev/null | wc -l)
    
    if [ "$RUNNING_PODS" -gt 0 ] && [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        echo -e "${GREEN}✅ 모든 Pod가 Running 상태입니다!${NC}"
        break
    else
        echo "대기 중... ($i/30) - Running: $RUNNING_PODS/$TOTAL_PODS"
        sleep 10
    fi
done

echo ""
echo "최종 배포 상태 확인:"
kubectl get all -n minio-tenant

# Step 11: 실제 스토리지 경로 확인
echo -e "${GREEN}📋 Step 11: 실제 스토리지 경로 확인${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "동적 프로비저닝으로 생성된 PV의 실제 저장 위치를 확인합니다:"
echo "- Local Path Provisioner는 노드의 로컬 디스크 사용"
echo "- 기본 경로: /opt/local-path-provisioner/"
echo "- PV별로 고유한 디렉토리 생성"
echo "- 실제 MinIO 데이터가 저장되는 위치"
echo ""

echo "1. PV 상세 정보 확인:"
echo "명령어: kubectl get pv -o wide"
echo ""

kubectl get pv -o wide
echo ""

echo "2. PV 실제 경로 확인:"
PV_NAMES=$(kubectl get pv --no-headers -o custom-columns=":metadata.name" | grep pvc)
for pv in $PV_NAMES; do
    if [ ! -z "$pv" ]; then
        echo "PV: $pv"
        PV_PATH=$(kubectl get pv $pv -o jsonpath='{.spec.local.path}' 2>/dev/null)
        if [ ! -z "$PV_PATH" ]; then
            echo "실제 경로: $PV_PATH"
            echo "디렉토리 확인:"
            ls -la $PV_PATH 2>/dev/null || echo "경로 접근 불가 (권한 또는 원격 노드)"
        fi
        echo ""
    fi
done

echo -e "${BLUE}📚 스토리지 경로 설명:${NC}"
echo "- 각 PVC마다 고유한 디렉토리 생성"
echo "- MinIO 데이터는 이 경로에 실제로 저장됨"
echo "- 노드 재시작 시에도 데이터 유지"
echo "- 백업 시 이 경로를 대상으로 함"

wait_for_user "실제 스토리지 경로를 확인했습니다. MinIO 서비스 접근을 테스트해보겠습니다."

# Step 12: MinIO 서비스 접근 테스트
echo -e "${GREEN}📋 Step 12: MinIO 서비스 접근 테스트${NC}"
echo ""
echo -e "${BLUE}💡 개념 설명:${NC}"
echo "배포된 MinIO 서비스에 실제로 접근할 수 있는지 확인합니다:"
echo "- Service를 통한 네트워크 접근"
echo "- 포트 포워딩을 통한 로컬 접근"
echo "- MinIO API 응답 확인"
echo "- 웹 콘솔 접근 확인"
echo ""

echo "1. MinIO 서비스 확인:"
echo "명령어: kubectl get svc -n minio-tenant"
echo ""

kubectl get svc -n minio-tenant
echo ""

echo -e "${BLUE}📚 서비스 설명:${NC}"
echo "- minio: MinIO API 서비스 (포트 80)"
echo "- minio-tenant-console: 웹 콘솔 서비스 (포트 9090)"
echo "- ClusterIP: 클러스터 내부에서만 접근 가능"

echo ""
echo "2. 포트 포워딩 설정:"
echo "명령어: kubectl port-forward svc/minio -n minio-tenant 9000:80"
echo ""

echo "MinIO API 포트 포워딩 시작..."
kubectl port-forward svc/minio -n minio-tenant 9000:80 > /dev/null 2>&1 &
API_PF_PID=$!

echo "MinIO Console 포트 포워딩 시작..."
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 > /dev/null 2>&1 &
CONSOLE_PF_PID=$!

sleep 5

echo -e "${GREEN}✅ 포트 포워딩 설정 완료${NC}"
echo "- MinIO API: http://localhost:9000"
echo "- MinIO Console: http://localhost:9001"

echo ""
echo "3. MinIO API 응답 테스트:"
echo "명령어: curl -I http://localhost:9000/minio/health/live"
echo ""

if curl -I http://localhost:9000/minio/health/live 2>/dev/null | grep -q "200 OK"; then
    echo -e "${GREEN}✅ MinIO API 정상 응답${NC}"
    curl -I http://localhost:9000/minio/health/live 2>/dev/null | head -3
else
    echo -e "${YELLOW}⚠️ MinIO API 응답 대기 중...${NC}"
    echo "MinIO 서버가 아직 완전히 시작되지 않았을 수 있습니다."
fi

echo ""
echo -e "${CYAN}🌐 웹 브라우저 접근 정보:${NC}"
echo "다음 URL로 MinIO 웹 콘솔에 접근할 수 있습니다:"
echo "URL: http://localhost:9001"
echo "사용자명: admin"
echo "비밀번호: password123"

# 포트 포워딩 프로세스 정리
kill $API_PF_PID $CONSOLE_PF_PID 2>/dev/null

wait_for_user "MinIO 서비스 접근을 테스트했습니다. 배포 결과를 요약해보겠습니다."

# Step 13: 배포 결과 요약
echo -e "${GREEN}📋 Step 13: MinIO Tenant 배포 결과 요약${NC}"
echo ""
echo -e "${PURPLE}🎉 Lab 2에서 완료한 작업:${NC}"
echo "✅ MinIO Operator 상태 확인"
echo "✅ 스토리지 클래스 확인"
echo "✅ MinIO Tenant 개념 학습"
echo "✅ 배포 전 클러스터 상태 확인"
echo "✅ Tenant 네임스페이스 생성"
echo "✅ MinIO 인증 정보 Secret 생성"
echo "✅ Tenant YAML 파일 생성"
echo "✅ 실시간 모니터링 스크립트 생성"
echo "✅ MinIO Tenant 배포 실행"
echo "✅ 동적 프로비저닝 과정 관찰"
echo "✅ 실제 스토리지 경로 확인"
echo "✅ MinIO 서비스 접근 테스트"
echo ""

echo -e "${CYAN}🧠 핵심 학습 내용:${NC}"
echo "• 동적 프로비저닝: PVC 생성 시 자동으로 PV 생성"
echo "• WaitForFirstConsumer: Pod 스케줄링 시점에 PV 생성"
echo "• StatefulSet: 상태 유지 애플리케이션 관리"
echo "• MinIO Tenant: 독립적인 MinIO 클러스터 인스턴스"
echo "• Operator 패턴: 선언적 애플리케이션 관리"
echo ""

echo -e "${BLUE}📊 배포 결과 통계:${NC}"
FINAL_PV_COUNT=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
FINAL_PVC_COUNT=$(kubectl get pvc -n minio-tenant --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n minio-tenant --no-headers 2>/dev/null | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n minio-tenant --no-headers 2>/dev/null | wc -l)

echo "• 생성된 PV 수: $FINAL_PV_COUNT (이전: $PV_COUNT_BEFORE)"
echo "• 생성된 PVC 수: $FINAL_PVC_COUNT"
echo "• 실행 중인 Pod: $RUNNING_PODS/$TOTAL_PODS"
echo "• 생성된 Service 수: $(kubectl get svc -n minio-tenant --no-headers 2>/dev/null | wc -l)"

echo ""
echo -e "${YELLOW}🔍 동적 프로비저닝 관찰 결과:${NC}"
if [ "$FINAL_PV_COUNT" -gt "$PV_COUNT_BEFORE" ]; then
    echo "✅ 동적 프로비저닝이 성공적으로 작동했습니다!"
    echo "   - PVC 생성 → Pod 스케줄링 → PV 자동 생성 → 바인딩 완료"
    echo "   - WaitForFirstConsumer 모드의 실제 동작을 확인했습니다"
else
    echo "⚠️ 동적 프로비저닝이 아직 완료되지 않았습니다"
    echo "   - 시간이 더 필요하거나 문제가 있을 수 있습니다"
fi

echo ""
echo -e "${BLUE}🔗 다음 Lab 준비사항:${NC}"
echo "• Lab 3에서는 MinIO Client를 설정합니다"
echo "• 실제 데이터 업로드/다운로드를 테스트합니다"
echo "• S3 호환 API 사용법을 학습합니다"
echo "• 데이터 무결성 검증 방법을 배웁니다"

echo ""
echo -e "${YELLOW}💡 문제 해결 팁:${NC}"
echo "• Pod가 Pending 상태: kubectl describe pod -n minio-tenant"
echo "• PVC가 Bound되지 않음: kubectl describe pvc -n minio-tenant"
echo "• 서비스 접근 불가: kubectl get events -n minio-tenant"
echo "• 포트 포워딩 문제: 포트가 이미 사용 중인지 확인"

echo ""
echo -e "${GREEN}🎯 Lab 2 완료!${NC}"
echo "MinIO Tenant가 성공적으로 배포되었습니다."
echo "동적 프로비저닝의 실제 동작 과정을 관찰했습니다."
echo "이제 Lab 3에서 MinIO Client를 설정하여 실제 데이터를 다뤄보겠습니다."

echo ""
echo -e "${PURPLE}다음 실행할 명령어:${NC}"
echo "./lab-03-client-setup.sh"

echo ""
echo -e "${CYAN}📋 현재 실행 중인 리소스:${NC}"
echo "다음 명령어로 언제든지 상태를 확인할 수 있습니다:"
echo "kubectl get all -n minio-tenant"
echo ""
echo "웹 콘솔 접근 (포트 포워딩 필요):"
echo "kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090"
echo "브라우저에서 http://localhost:9001 접근"
