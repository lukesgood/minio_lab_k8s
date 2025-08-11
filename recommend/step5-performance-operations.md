## Step 5: 성능 검증 및 운영 설정

### 💡 개념 설명

배포된 MinIO 클러스터의 성능을 검증하고 프로덕션 운영을 위한 설정을 완료합니다.

### 🌐 서비스 접근 설정

```bash
echo "=== MinIO 서비스 접근 설정 ==="

# 1. 서비스 확인
kubectl get services -n minio-tenant

# 2. 포트 포워딩 설정 (개발/테스트용)
echo "개발/테스트용 포트 포워딩 설정:"
kubectl port-forward -n minio-tenant svc/minio-tenant-hl 9000:9000 &
kubectl port-forward -n minio-tenant svc/minio-tenant-console 9001:9090 &

echo "MinIO API: http://localhost:9000"
echo "MinIO Console: http://localhost:9001"

# 3. 인증 정보 확인
echo -e "\n인증 정보:"
kubectl get secret minio-creds-secret -n minio-tenant -o jsonpath='{.data.config\.env}' | base64 -d
```

### 🔍 MinIO 클러스터 상태 검증

```bash
echo "=== MinIO 클러스터 상태 검증 ==="

# 1. API 연결 테스트
echo "1. MinIO API 연결 테스트:"
curl -I http://localhost:9000/minio/health/live

# 2. 클러스터 정보 확인
echo -e "\n2. 클러스터 정보:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 | grep -E "(Online|Offline|Status)"

# 3. 드라이브 상태 확인
echo -e "\n3. 드라이브 상태 확인:"
WORKER_COUNT=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' | wc -l)
TOTAL_DRIVES=$((WORKER_COUNT * 2))
echo "예상 드라이브 수: ${TOTAL_DRIVES}개"

# 4. Erasure Coding 설정 확인
echo -e "\n4. Erasure Coding 설정:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 | grep -i "erasure"
```

### ⚡ 성능 테스트

```bash
echo "=== MinIO 성능 테스트 ==="

# MinIO Client 설치 (없는 경우)
if ! command -v mc &> /dev/null; then
    echo "MinIO Client 설치 중..."
    curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
    chmod +x mc
    sudo mv mc /usr/local/bin/
fi

# MinIO 서버 연결 설정
echo "MinIO 서버 연결 설정:"
ROOT_USER=$(kubectl get secret minio-creds-secret -n minio-tenant -o jsonpath='{.data.config\.env}' | base64 -d | grep MINIO_ROOT_USER | cut -d'=' -f2)
ROOT_PASSWORD=$(kubectl get secret minio-creds-secret -n minio-tenant -o jsonpath='{.data.config\.env}' | base64 -d | grep MINIO_ROOT_PASSWORD | cut -d'=' -f2)

mc alias set minio-prod http://localhost:9000 "$ROOT_USER" "$ROOT_PASSWORD"

# 테스트 버킷 생성
echo "테스트 버킷 생성:"
mc mb minio-prod/performance-test

# 성능 테스트 실행
echo "=== 성능 테스트 실행 ==="

# 1. 작은 파일 업로드 테스트 (1MB x 100개)
echo "1. 작은 파일 업로드 테스트 (1MB x 100개):"
mkdir -p /tmp/minio-test
for i in {1..100}; do
    dd if=/dev/zero of=/tmp/minio-test/small-${i}.dat bs=1M count=1 2>/dev/null
done

start_time=$(date +%s)
mc cp /tmp/minio-test/*.dat minio-prod/performance-test/small/
end_time=$(date +%s)
small_duration=$((end_time - start_time))
echo "작은 파일 업로드 시간: ${small_duration}초"

# 2. 대용량 파일 업로드 테스트 (100MB x 10개)
echo -e "\n2. 대용량 파일 업로드 테스트 (100MB x 10개):"
for i in {1..10}; do
    dd if=/dev/zero of=/tmp/minio-test/large-${i}.dat bs=1M count=100 2>/dev/null
done

start_time=$(date +%s)
mc cp /tmp/minio-test/large-*.dat minio-prod/performance-test/large/
end_time=$(date +%s)
large_duration=$((end_time - start_time))
echo "대용량 파일 업로드 시간: ${large_duration}초"

# 3. 다운로드 성능 테스트
echo -e "\n3. 다운로드 성능 테스트:"
rm -rf /tmp/minio-test-download
mkdir -p /tmp/minio-test-download

start_time=$(date +%s)
mc cp --recursive minio-prod/performance-test/large/ /tmp/minio-test-download/
end_time=$(date +%s)
download_duration=$((end_time - start_time))
echo "다운로드 시간: ${download_duration}초"

# 성능 결과 요약
echo -e "\n=== 성능 테스트 결과 요약 ==="
echo "작은 파일 (1MB x 100): ${small_duration}초"
echo "대용량 파일 (100MB x 10): ${large_duration}초"
echo "다운로드 (1GB): ${download_duration}초"
echo "평균 업로드 속도: $((1000 / large_duration))MB/s (추정)"

# 정리
rm -rf /tmp/minio-test /tmp/minio-test-download
```

### 📊 모니터링 설정

```bash
echo "=== 모니터링 설정 ==="

# 1. Prometheus 메트릭 확인
echo "1. Prometheus 메트릭 엔드포인트 확인:"
curl -s http://localhost:9000/minio/v2/metrics/cluster | head -20

# 2. 리소스 사용량 확인
echo -e "\n2. 리소스 사용량:"
kubectl top pods -n minio-tenant 2>/dev/null || echo "metrics-server 필요"

# 3. 스토리지 사용량 확인
echo -e "\n3. 스토리지 사용량:"
mc admin info minio-prod

# 4. 클러스터 상태 모니터링 스크립트 생성
cat << 'EOF' > monitor-minio.sh
#!/bin/bash
echo "=== MinIO 클러스터 모니터링 ==="
echo "시간: $(date)"
echo ""

echo "1. Tenant 상태:"
kubectl get tenant -n minio-tenant

echo -e "\n2. Pod 상태:"
kubectl get pods -n minio-tenant

echo -e "\n3. 스토리지 사용량:"
mc admin info minio-prod 2>/dev/null | grep -E "(Used|Total|Available)"

echo -e "\n4. 최근 로그:"
kubectl logs -n minio-tenant minio-tenant-pool-0-0 --tail=5

echo "================================"
EOF

chmod +x monitor-minio.sh
echo "모니터링 스크립트 생성: ./monitor-minio.sh"
```

### 🔒 보안 강화 설정

```bash
echo "=== 보안 강화 설정 ==="

# 1. 네트워크 정책 생성 (선택사항)
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: minio-tenant-network-policy
  namespace: minio-tenant
spec:
  podSelector:
    matchLabels:
      v1.min.io/tenant: minio-tenant
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: minio-tenant
    ports:
    - protocol: TCP
      port: 9000
    - protocol: TCP
      port: 9090
  egress:
  - {}
EOF

# 2. RBAC 설정 확인
echo "RBAC 설정 확인:"
kubectl get serviceaccount -n minio-tenant
kubectl get role -n minio-tenant
kubectl get rolebinding -n minio-tenant

# 3. 시크릿 보안 확인
echo -e "\n시크릿 보안 상태:"
kubectl get secrets -n minio-tenant
```

### 🚀 운영 준비 완료 확인

```bash
echo "=== 운영 준비 완료 확인 ==="

# 최종 상태 확인
echo "1. 전체 상태 요약:"
kubectl get all -n minio-tenant

echo -e "\n2. MinIO 클러스터 정보:"
mc admin info minio-prod

echo -e "\n3. 접근 정보:"
echo "MinIO API: http://localhost:9000"
echo "MinIO Console: http://localhost:9001"
echo "사용자명: $ROOT_USER"
echo "패스워드: [시크릿에서 확인]"

echo -e "\n4. 다음 단계:"
echo "- 프로덕션 환경에서는 LoadBalancer 또는 Ingress 설정"
echo "- SSL/TLS 인증서 설정"
echo "- 백업 정책 수립"
echo "- 모니터링 시스템 연동"
echo "- 사용자 및 권한 관리 설정"

echo -e "\n✅ MinIO 권장사항 기반 멀티노드 클러스터 배포 완료!"
```

### 🛑 최종 체크포인트
- [ ] MinIO API 정상 응답
- [ ] 웹 콘솔 접근 가능
- [ ] 성능 테스트 완료
- [ ] 모니터링 설정 완료
- [ ] 보안 설정 적용
- [ ] 운영 스크립트 준비
