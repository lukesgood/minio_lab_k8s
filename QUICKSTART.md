# MinIO Kubernetes Lab - 빠른 시작 가이드

MinIO Field Architect 면접 준비를 위한 실습 환경을 빠르게 구성하는 가이드입니다.

## 🚀 원클릭 설치 (권장)

### 자동 환경 구성
```bash
# 1. 리포지토리 클론
git clone https://github.com/lukesgood/minio_lab_k8s.git
cd minio_lab_k8s

# 2. 자동 설치 스크립트 실행
chmod +x setup-environment.sh
./setup-environment.sh

# 3. kubectl 설정 적용
export KUBECONFIG=~/.kube/config-minio

# 4. 실습 시작
./run-lab.sh
```

**⏱️ 예상 소요시간: 30-45분**

## 📊 메모리별 구성 선택

### 자동 감지 (권장)
```bash
./setup-environment.sh
# 시스템 메모리를 자동 감지하여 최적 구성 선택
```

### 수동 선택
```bash
# 32GB+ 메모리: 멀티 노드 구성
./setup-environment.sh multi

# 16GB 메모리: 단일 노드 구성 (권장)
./setup-environment.sh single

# 8GB 메모리: 최소 구성
./setup-environment.sh minimal
```

## 🔍 설치 확인

### 1. 클러스터 상태 확인
```bash
kubectl get nodes
# 결과: Ready 상태여야 함

kubectl get pods -n kube-system
# 결과: 모든 Pod가 Running 상태여야 함
```

### 2. 테스트 Pod 배포
```bash
kubectl run test-nginx --image=nginx --restart=Never
kubectl get pods
# 결과: test-nginx가 Running 상태여야 함

# 정리
kubectl delete pod test-nginx
```

## 🎯 실습 메뉴

### 실습 가이드 실행
```bash
./run-lab.sh
```

### 실습 메뉴 옵션
```
1) MinIO Operator 설치      - 최신 운영 방식
2) MinIO Tenant 배포        - 프로덕션 환경 구성  
3) MinIO Helm (Standalone)  - 단일 인스턴스
4) MinIO Helm (Distributed) - 분산 모드
5) MinIO Client 설정        - CLI 도구 설정
6) 성능 테스트 실행         - 벤치마킹
7) 모니터링 설정           - 메트릭 수집
8) 전체 정리               - 환경 초기화
```

## 🚨 문제 해결

### 일반적인 문제

#### 1. VM 생성 실패
```bash
# 기존 VM 정리 후 재시도
multipass delete --all
multipass purge
./setup-environment.sh
```

#### 2. kubectl 연결 실패
```bash
# VM 내부에서 직접 작업
multipass shell minio-k8s
kubectl get nodes
```

#### 3. 노드가 NotReady 상태
```bash
# CNI 재설치
kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### 4. 메모리 부족
```bash
# 더 작은 구성으로 재시도
./setup-environment.sh minimal
```

### 상세 트러블슈팅
문제가 지속되면 `troubleshooting-guide.md`를 참조하세요.

## 📚 학습 순서 (권장)

### 1단계: 기본 이해
- `README.md` - 전체 개요 및 이론
- `lab-setup-guide.md` - 상세 설치 가이드

### 2단계: 실습 진행
1. **MinIO Operator** - 현대적 운영 방식
2. **MinIO Tenant** - 멀티테넌트 환경
3. **Helm Chart** - 전통적 배포 방식
4. **성능 테스트** - 최적화 기법
5. **모니터링** - 운영 관리

### 3단계: 심화 학습
- `performance-comparison.md` - MinIO vs GlusterFS
- `troubleshooting-guide.md` - 문제 해결

## 🎓 면접 준비 체크리스트

### 기술적 질문 대비
- [ ] MinIO 아키텍처 설명 가능
- [ ] Erasure Coding vs RAID 차이점 이해
- [ ] Kubernetes 배포 방식 비교 가능
- [ ] 성능 최적화 방법 숙지
- [ ] 보안 설정 방법 이해

### 실무 시나리오 대비
- [ ] 대용량 데이터 마이그레이션 계획 수립
- [ ] 멀티 클라우드 전략 설계
- [ ] 재해 복구 방안 구성
- [ ] 성능 문제 진단 및 해결
- [ ] 비용 최적화 방안 제시

## 🔧 환경 관리

### VM 관리 명령어
```bash
# VM 목록 확인
multipass list

# VM 접속
multipass shell minio-k8s

# VM 중지/시작
multipass stop minio-k8s
multipass start minio-k8s

# VM 삭제 (완전 정리)
multipass delete minio-k8s
multipass purge
```

### 리소스 모니터링
```bash
# 호스트 메모리 사용량
free -h

# VM 리소스 사용량
multipass info minio-k8s

# Kubernetes 리소스 사용량
kubectl top nodes
kubectl top pods --all-namespaces
```

## 📞 지원

### 문서 참조
- **설치 문제**: `lab-setup-guide.md`
- **실습 문제**: `troubleshooting-guide.md`
- **이론 학습**: `README.md`

### 로그 확인
```bash
# VM 로그
multipass logs minio-k8s

# Kubernetes 로그
kubectl logs -n kube-system <pod-name>

# MinIO 로그
kubectl logs -n minio-tenant <minio-pod-name>
```

---

**🎉 준비 완료!** 

이제 MinIO Field Architect 면접을 위한 실습을 시작할 수 있습니다. 

실습 중 궁금한 점이 있으면 각 Lab의 이론 설명을 참조하고, 문제가 발생하면 트러블슈팅 가이드를 확인하세요.
