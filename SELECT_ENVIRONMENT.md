# MinIO Kubernetes Lab - 환경 선택 가이드

## 📋 개요

이 가이드는 MinIO Kubernetes Lab을 실행하기 위한 최적의 환경을 선택하는 방법을 안내합니다. 사용자의 하드웨어 리소스와 학습 목표에 따라 적절한 환경을 선택할 수 있습니다.

## 🎯 환경 유형

### 단일 노드 환경 (학습/개발용)
**권장 대상:**
- Kubernetes 초보자
- 로컬 개발 환경
- 리소스 제약이 있는 환경
- MinIO 기본 기능 학습

**특징:**
- ✅ 간단한 설정
- ✅ 낮은 리소스 요구사항
- ✅ 빠른 시작
- ❌ 고가용성 없음
- ❌ 실제 분산 스토리지 경험 제한

### 다중 노드 환경 (프로덕션용)
**권장 대상:**
- Kubernetes 경험자
- 프로덕션 환경 시뮬레이션
- 고가용성 및 확장성 학습
- 성능 테스트 및 벤치마킹

**특징:**
- ✅ 실제 프로덕션 환경과 유사
- ✅ 고가용성 및 장애 복구
- ✅ 확장성 테스트 가능
- ❌ 복잡한 설정
- ❌ 높은 리소스 요구사항

## 🔍 자동 환경 감지

### 권장 방법 (자동 감지)
```bash
# 1. 환경 감지
./detect-environment.sh

# 2. 자동 설정 (감지된 환경에 따라)
./setup-environment.sh

# 3. 실습 시작
./run-lab.sh
```

**자동 감지 기준:**
- 노드 수 (1개 = 단일 노드, 2개 이상 = 다중 노드)
- 사용 가능한 CPU 및 메모리
- 스토리지 클래스 존재 여부
- 네트워크 정책 지원 여부

## 📊 환경별 상세 비교

| 구분 | 단일 노드 | 다중 노드 |
|------|-----------|-----------|
| **최소 노드 수** | 1개 | 3개 이상 |
| **CPU** | 2코어 | 8코어 이상 |
| **메모리** | 4GB | 16GB 이상 |
| **디스크** | 20GB | 100GB 이상 |
| **네트워크** | 로컬 | 10GbE 권장 |
| **설정 복잡도** | 낮음 | 높음 |
| **학습 시간** | 1-2시간 | 3-4시간 |
| **실무 적용도** | 개발/테스트 | 프로덕션 |

## 🚀 환경별 시작 가이드

### 단일 노드 환경으로 시작
```bash
# 환경 감지 후 단일 노드로 설정
./detect-environment.sh
./setup-environment.sh
./run-lab.sh
```

**상세 가이드:** [SINGLE_NODE_GUIDE.md](SINGLE_NODE_GUIDE.md)

### 다중 노드 환경으로 시작
```bash
# 환경 감지 후 다중 노드로 설정
./detect-environment.sh
./setup-environment.sh
./run-lab.sh
```

**상세 가이드:** [MULTI_NODE_GUIDE.md](MULTI_NODE_GUIDE.md)

## 🔄 환경 전환

### 단일 노드에서 다중 노드로 전환
```bash
# 1. 현재 환경 정리
./cleanup-all.sh

# 2. 다중 노드 클러스터 구성 (별도 작업 필요)
# 3. 새 환경에서 재시작
./detect-environment.sh
./setup-environment.sh
./run-lab.sh
```

### 다중 노드에서 단일 노드로 전환
```bash
# 1. 현재 환경 정리
./cleanup-all.sh

# 2. 단일 노드 클러스터 구성 (별도 작업 필요)
# 3. 새 환경에서 재시작
./detect-environment.sh
./setup-environment.sh
./run-lab.sh
```

## 📚 사용 가능한 스크립트

### 핵심 스크립트
- `detect-environment.sh` - 환경 자동 감지
- `setup-environment.sh` - 환경별 자동 설정
- `run-lab.sh` - 통합 실습 메뉴
- `cleanup-all.sh` - 전체 환경 정리

### 개별 Lab 스크립트
- `lab-00-env-check.sh` - 환경 사전 검증
- `lab-01-operator-install.sh` - MinIO Operator 설치
- `lab-02-tenant-deploy.sh` - MinIO Tenant 배포
- `lab-03-client-setup.sh` - MinIO Client 설정
- `lab-04-advanced-s3.sh` - S3 API 고급 기능
- `lab-05-performance-test.sh` - 성능 테스트
- `lab-06-user-management.sh` - 사용자 및 권한 관리

### Kubernetes 환경 구성
- `setup-k8s-environment.sh` - Kubernetes 클러스터 설치

## 📝 학습 경로 추천

### 초보자 경로
1. **단일 노드 환경**으로 시작
2. **기본 Lab (0-3)** 완주
3. **핵심 개념** 문서 학습
4. **고급 Lab (4-6)** 도전

### 경험자 경로
1. **다중 노드 환경**으로 시작
2. **전체 Lab (0-6)** 완주
3. **성능 최적화** 실험
4. **프로덕션 시나리오** 테스트

### 실무자 경로
1. **다중 노드 환경** 구성
2. **모니터링 및 알림** 설정
3. **백업 및 복구** 절차 수립
4. **보안 강화** 적용

## 🎯 환경 선택 결정 트리

```
시작
 ├─ Kubernetes 경험이 있나요?
 │   ├─ 예 → 리소스가 충분한가요? (8GB+ RAM, 4+ CPU)
 │   │   ├─ 예 → 다중 노드 환경 권장
 │   │   └─ 아니오 → 단일 노드 환경 권장
 │   └─ 아니오 → 단일 노드 환경 권장
 └─ 학습 목표가 무엇인가요?
     ├─ 기본 개념 학습 → 단일 노드 환경
     ├─ 프로덕션 준비 → 다중 노드 환경
     └─ 성능 테스트 → 다중 노드 환경
```

## 🔧 환경별 최적화 팁

### 단일 노드 최적화
- Control-plane taint 제거
- 리소스 요청/제한 조정
- 로컬 스토리지 최적화
- 단일 replica 설정

### 다중 노드 최적화
- Pod Anti-Affinity 설정
- 분산 스토리지 활용
- 네트워크 정책 적용
- 고가용성 구성

## 🚨 주의사항

### 단일 노드 환경
- 실제 프로덕션 환경과 차이 있음
- 고가용성 기능 제한
- 성능 테스트 결과 제한적

### 다중 노드 환경
- 복잡한 네트워크 설정 필요
- 높은 리소스 요구사항
- 문제 해결 난이도 높음

## 📖 관련 문서

- [단일 노드 환경 가이드](SINGLE_NODE_GUIDE.md)
- [다중 노드 환경 가이드](MULTI_NODE_GUIDE.md)
- [Kubernetes 환경 구성](K8S_SETUP_GUIDE.md)
- [핵심 개념 문서](docs/)

---

**💡 권장사항:** 처음 사용하는 경우 단일 노드 환경으로 시작하여 기본 개념을 익힌 후, 다중 노드 환경으로 확장하는 것을 권장합니다.
