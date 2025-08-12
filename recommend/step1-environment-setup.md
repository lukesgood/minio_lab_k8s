## Step 1: 멀티노드 환경 준비 및 검증

### 💡 개념 설명

MinIO 권장사항에 따른 멀티노드 환경을 준비하고 검증합니다. 모든 설정은 프로덕션 환경 기준으로 구성됩니다.

### 🔍 클러스터 환경 검증

```bash
echo "=== MinIO 권장 멀티노드 환경 검증 ==="

# 1. 노드 구성 확인
echo "1. 클러스터 노드 구성:"
kubectl get nodes -o wide

# 2. 워커 노드 수 확인
WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)
echo -e "\n워커 노드 수: $WORKER_COUNT"

if [ $WORKER_COUNT -lt 3 ]; then
    echo "❌ 경고: MinIO 권장 최소 워커 노드 수는 3개 이상입니다."
    echo "현재: $WORKER_COUNT개, 권장: 3개 이상"
else
    echo "✅ 워커 노드 수 충족: $WORKER_COUNT개"
fi

# 3. 노드별 리소스 확인
echo -e "\n2. 노드별 리소스 상태:"
kubectl top nodes 2>/dev/null || echo "metrics-server가 설치되지 않음"

# 4. 스토리지 클래스 확인
echo -e "\n3. 현재 스토리지 클래스:"
kubectl get storageclass

# 5. MinIO Operator 확인
echo -e "\n4. MinIO Operator 상태:"
kubectl get pods -n minio-operator 2>/dev/null || echo "MinIO Operator가 설치되지 않음"
```

### 🔧 MinIO Operator 설치 (필요한 경우)

```bash
# MinIO Operator가 없는 경우 설치
if ! kubectl get namespace minio-operator &>/dev/null; then
    echo "=== MinIO Operator 설치 ==="
    
    # 최신 버전 설치
    kubectl kustomize github.com/minio/operator\?ref=v7.1.1 | kubectl apply -f -
    
    # 설치 완료 대기
    echo "Operator 설치 중... (1-2분 소요)"
    kubectl wait --for=condition=ready pod -l name=minio-operator -n minio-operator --timeout=300s
    
    echo "✅ MinIO Operator 설치 완료"
else
    echo "✅ MinIO Operator 이미 설치됨"
fi
```

### 🛑 체크포인트
- [ ] 워커 노드 3개 이상 확인
- [ ] 모든 노드가 Ready 상태
- [ ] MinIO Operator 정상 실행
- [ ] 충분한 클러스터 리소스 확보
