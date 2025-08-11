## Step 4: 배포 실행 및 실시간 모니터링

### 💡 개념 설명

MinIO Tenant를 배포하고 실시간으로 배포 과정을 모니터링합니다. 멀티노드 환경에서의 분산 배포 과정을 관찰할 수 있습니다.

### 📊 실시간 모니터링 설정

```bash
echo "=== 실시간 모니터링 설정 ==="

# 별도 터미널에서 실행할 모니터링 명령어들
echo "다음 명령어들을 별도 터미널에서 실행하세요:"
echo ""
echo "터미널 1 (PV 모니터링):"
echo "watch -n 2 'kubectl get pv -l minio.min.io/storage-type=local-attached'"
echo ""
echo "터미널 2 (PVC 모니터링):"
echo "watch -n 2 'kubectl get pvc -n minio-tenant'"
echo ""
echo "터미널 3 (Pod 모니터링):"
echo "watch -n 2 'kubectl get pods -n minio-tenant -o wide'"
echo ""
echo "터미널 4 (Tenant 상태 모니터링):"
echo "watch -n 5 'kubectl get tenant -n minio-tenant'"
echo ""
```

### 🚀 MinIO Tenant 배포 실행

```bash
echo "=== MinIO Tenant 배포 시작 ==="

# 배포 전 상태 기록
echo "배포 전 상태:"
echo "PV 상태:" && kubectl get pv -l minio.min.io/storage-type=local-attached --no-headers | wc -l
echo "PVC 상태:" && kubectl get pvc -n minio-tenant --no-headers 2>/dev/null | wc -l || echo "0"
echo "Pod 상태:" && kubectl get pods -n minio-tenant --no-headers 2>/dev/null | wc -l || echo "0"

echo -e "\n=== Tenant 배포 실행 ==="
kubectl apply -f minio-tenant-production.yaml

echo "✅ Tenant 배포 명령 실행 완료"
echo "실시간 모니터링을 통해 배포 과정을 관찰하세요."
```

### 📈 단계별 배포 과정 확인

```bash
echo "=== 단계별 배포 과정 확인 ==="

# 1단계: Tenant 리소스 생성 확인 (즉시)
echo "1단계: Tenant 리소스 생성 확인"
sleep 5
kubectl get tenant -n minio-tenant

# 2단계: PVC 생성 확인 (10-20초 후)
echo -e "\n2단계: PVC 생성 확인 (10초 대기)"
sleep 10
kubectl get pvc -n minio-tenant

# 3단계: StatefulSet 생성 확인
echo -e "\n3단계: StatefulSet 생성 확인"
kubectl get statefulset -n minio-tenant

# 4단계: Pod 스케줄링 확인 (30초 후)
echo -e "\n4단계: Pod 스케줄링 확인 (30초 대기)"
sleep 30
kubectl get pods -n minio-tenant -o wide

# 5단계: PV 바인딩 확인
echo -e "\n5단계: PV 바인딩 상태 확인"
kubectl get pv -l minio.min.io/storage-type=local-attached

# 6단계: 서비스 생성 확인
echo -e "\n6단계: 서비스 생성 확인"
kubectl get services -n minio-tenant
```

### 🔍 배포 완료 대기 및 검증

```bash
echo "=== 배포 완료 대기 ==="

# StatefulSet 준비 완료 대기
echo "StatefulSet 준비 완료 대기 중... (최대 10분)"
kubectl wait --for=condition=ready statefulset/minio-tenant-pool-0 -n minio-tenant --timeout=600s

# 모든 Pod 실행 대기
echo "모든 Pod 실행 대기 중..."
kubectl wait --for=condition=ready pod -l v1.min.io/tenant=minio-tenant -n minio-tenant --timeout=600s

echo "✅ 배포 완료!"
```

### 📊 배포 상태 종합 확인

```bash
echo "=== 배포 상태 종합 확인 ==="

echo "1. Tenant 상태:"
kubectl get tenant -n minio-tenant -o wide

echo -e "\n2. StatefulSet 상태:"
kubectl get statefulset -n minio-tenant

echo -e "\n3. Pod 상태 및 분산 배치:"
kubectl get pods -n minio-tenant -o wide

echo -e "\n4. PVC 바인딩 상태:"
kubectl get pvc -n minio-tenant

echo -e "\n5. PV 사용 상태:"
kubectl get pv -l minio.min.io/storage-type=local-attached

echo -e "\n6. 서비스 상태:"
kubectl get services -n minio-tenant

echo -e "\n7. 노드별 Pod 분산 확인:"
kubectl get pods -n minio-tenant -o wide | awk 'NR>1 {print $7}' | sort | uniq -c

echo -e "\n8. MinIO 클러스터 로그 확인:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 --tail=10
```

### 🛑 체크포인트
- [ ] Tenant 리소스가 "Initialized" 상태
- [ ] 모든 StatefulSet이 Ready 상태
- [ ] 모든 Pod가 "Running" 상태
- [ ] 모든 PVC가 "Bound" 상태
- [ ] Pod가 워커 노드에 분산 배치됨
- [ ] MinIO 로그에서 "X Online, 0 Offline" 확인
