# MinIO Kubernetes 트러블슈팅 가이드

## 일반적인 문제 및 해결방법

### 1. Pod가 Pending 상태
**증상**: MinIO Pod가 Pending 상태에서 멈춤
**원인**: 
- 리소스 부족 (CPU, 메모리)
- PVC 바인딩 실패
- 노드 스케줄링 문제

**해결방법**:
```bash
# Pod 상태 확인
kubectl describe pod <pod-name> -n <namespace>

# 노드 리소스 확인
kubectl top nodes

# PVC 상태 확인
kubectl get pvc -n <namespace>

# 이벤트 확인
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### 2. MinIO 서비스 접근 불가
**증상**: 포트 포워딩 후에도 접근 안됨
**원인**:
- 서비스 설정 오류
- 네트워크 정책 차단
- 인증 정보 오류

**해결방법**:
```bash
# 서비스 상태 확인
kubectl get svc -n <namespace>

# 엔드포인트 확인
kubectl get endpoints -n <namespace>

# Pod 로그 확인
kubectl logs <pod-name> -n <namespace>

# 포트 포워딩 재시도
kubectl port-forward svc/<service-name> -n <namespace> 9000:9000
```

### 3. 성능 문제
**증상**: 업로드/다운로드 속도가 느림
**원인**:
- 네트워크 대역폭 제한
- 스토리지 I/O 병목
- 리소스 제한

**진단 명령어**:
```bash
# 리소스 사용량 확인
kubectl top pods -n <namespace>

# MinIO 메트릭 확인
mc admin info <alias>

# 네트워크 테스트
mc speed test <alias>

# 스토리지 성능 테스트
kubectl exec -it <pod-name> -n <namespace> -- dd if=/dev/zero of=/tmp/test bs=1M count=100
```

### 4. 데이터 일관성 문제
**증상**: 파일 업로드 후 조회 안됨
**원인**:
- Erasure Coding 설정 오류
- 노드 간 시간 동기화 문제
- 네트워크 분할

**해결방법**:
```bash
# 클러스터 상태 확인
mc admin info <alias>

# 힐링 상태 확인
mc admin heal <alias>

# 시간 동기화 확인
kubectl exec -it <pod-name> -n <namespace> -- date
```

## 로그 분석

### MinIO 로그 레벨 설정
```bash
# 디버그 모드 활성화
kubectl set env statefulset/<statefulset-name> MINIO_LOG_LEVEL=DEBUG -n <namespace>
```

### 주요 로그 패턴
- `ERROR`: 오류 발생
- `WARN`: 경고 메시지
- `INFO`: 일반 정보
- `DEBUG`: 디버그 정보

## 모니터링 체크리스트

### 1. 클러스터 상태
- [ ] 모든 노드가 Ready 상태
- [ ] MinIO Pod가 Running 상태
- [ ] PVC가 Bound 상태
- [ ] 서비스가 정상 동작

### 2. 성능 지표
- [ ] CPU 사용률 < 80%
- [ ] 메모리 사용률 < 80%
- [ ] 디스크 사용률 < 85%
- [ ] 네트워크 지연시간 < 10ms

### 3. 보안 체크
- [ ] TLS 인증서 유효성
- [ ] IAM 정책 적용
- [ ] 네트워크 정책 설정
- [ ] 시크릿 관리

## 백업 및 복구

### 데이터 백업
```bash
# 버킷 미러링
mc mirror <source-alias>/bucket <target-alias>/bucket

# 설정 백업
kubectl get secret <secret-name> -n <namespace> -o yaml > backup-secret.yaml
```

### 재해 복구
```bash
# 클러스터 재구성
kubectl apply -f minio-tenant.yaml

# 데이터 복원
mc mirror <backup-alias>/bucket <restored-alias>/bucket
```
