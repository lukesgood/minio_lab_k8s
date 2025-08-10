# MinIO Kubernetes Lab Guide

## 📚 개요

이 실습 가이드는 Kubernetes 환경에서 MinIO 객체 스토리지를 배포하고 운영하는 방법을 학습합니다. 실제 운영 환경에서 발생할 수 있는 문제들과 해결 방법을 포함하여 실용적인 경험을 제공합니다.

## 🎯 학습 목표

- MinIO Operator를 사용한 Kubernetes 네이티브 배포
- S3 호환 API를 통한 객체 스토리지 관리
- 사용자 및 권한 관리 시스템 이해
- 실제 운영 환경에서의 문제 해결 능력 습득

## 🔧 사전 준비: Kubernetes 환경 구성

### Kubernetes 클러스터가 없는 경우

MinIO Lab을 시작하기 전에 Kubernetes 클러스터가 필요합니다. 다음 방법 중 하나를 선택하세요:

#### 자동 설치 (권장)
```bash
# Kubernetes 환경 구성 자동화 스크립트
./setup-k8s-environment.sh

# 메뉴에서 선택:
# 1) Minikube (가장 간단)
# 2) Kind (Docker 기반)
# 3) K3s (경량 프로덕션급)
# 4) kubeadm (표준 클러스터)
# 5) 기존 클러스터 확인
```

#### 수동 설치
- **Minikube**: `minikube start --cpus=4 --memory=8192`
- **Kind**: `kind create cluster --name=minio-lab`
- **K3s**: `curl -sfL https://get.k3s.io | sh -`

**📖 상세 가이드**: [K8S_SETUP_GUIDE.md](K8S_SETUP_GUIDE.md)

### Kubernetes 클러스터가 있는 경우

기존 클러스터 확인:
```bash
kubectl cluster-info
kubectl get nodes
```

## 🚀 빠른 시작

### 자동 환경 감지 및 설정 (권장)
```bash
# 1. 리포지토리 클론
git clone https://github.com/lukesgood/minio_lab_k8s.git
cd minio_lab_k8s

# 2. Kubernetes 환경 구성 (필요한 경우)
./setup-k8s-environment.sh

# 3. 환경 자동 감지
./detect-environment.sh

# 4. 환경 자동 설정
./setup-environment.sh

# 5. 실습 시작
./run-lab.sh
```

### 대화형 단계별 가이드 (초보자 권장) 🆕
```bash
# 단계별 상세 설명과 체크포인트가 포함된 대화형 가이드
./interactive-lab-guide.sh
```

### 수동 환경 선택 (고급 사용자)
```bash
# 환경 감지 후 수동 설정
./detect-environment.sh
./setup-environment.sh

# 실습 메뉴에서 원하는 모듈 선택
./run-lab.sh
```

**⏱️ 예상 소요시간: 60-90분**

## 📋 환경 요구사항

### 단일 노드 환경 (학습/개발용)
- Kubernetes 클러스터 (1개 노드)
- 최소 4GB RAM, 2 CPU 코어
- 10GB 이상 디스크 여유 공간
- kubectl 설치 및 설정 완료

### 다중 노드 환경 (프로덕션용)
- Kubernetes 클러스터 (3개 이상 노드)
- 각 노드당 최소 8GB RAM, 4 CPU 코어
- 각 노드당 100GB 이상 디스크 여유 공간
- 분산 스토리지 시스템 권장

## 📚 실습 모듈

### Core Labs (필수 실습)

#### Lab 0: 환경 사전 검증
- **학습 내용**: 동적 vs 정적 프로비저닝, WaitForFirstConsumer 동작 원리
- **실습 내용**: 클러스터 상태 확인, 스토리지 프로비저너 동작 원리, PV/PVC 생성 과정 이해
- **핵심 개념**: 스토리지 클래스 구성, 스토리지 경로 설정, 동적 프로비저닝 준비 상태
- **소요시간**: 5-10분
- **스크립트**: `./lab-00-env-check.sh`

#### Lab 1: MinIO Operator 설치
- **학습 내용**: Operator 패턴, CRD 기반 리소스 관리
- **실습 내용**: MinIO Operator 설치, 단일/다중 노드 최적화
- **핵심 개념**: Kubernetes 네이티브 애플리케이션 관리, 자동화된 운영
- **소요시간**: 10-15분
- **스크립트**: `./lab-01-operator-install.sh`

#### Lab 2: MinIO Tenant 배포
- **학습 내용**: 실시간 동적 프로비저닝 관찰, StatefulSet과 PVC 관계
- **실습 내용**: Tenant 개념 및 설정, 스토리지 클래스 구성, Erasure Coding 설정
- **핵심 개념**: WaitForFirstConsumer 실제 동작, PV 자동 생성 과정, 실제 스토리지 경로 확인
- **특별 기능**: 배포 전후 PV 상태 비교, 실시간 프로비저닝 모니터링
- **소요시간**: 15-20분
- **스크립트**: `./lab-02-tenant-deploy.sh`

#### Lab 3: MinIO Client 및 기본 사용법
- **학습 내용**: S3 호환 API 사용법, 실제 스토리지 경로 검증
- **실습 내용**: MinIO Client (mc) 설치, 서버 연결 설정, 버킷 및 객체 기본 관리
- **핵심 개념**: 포트 포워딩을 통한 서비스 접근, 데이터 무결성 검증, 실제 파일시스템에서 데이터 확인
- **특별 기능**: 업로드된 데이터의 실제 저장 위치 확인, MinIO 데이터 구조 이해
- **소요시간**: 10-15분
- **스크립트**: `./lab-03-client-setup.sh`

### Advanced Labs (권장 실습)

#### Lab 4: S3 API 고급 기능
- **학습 내용**: Multipart Upload vs Single Part 비교, 메타데이터 관리
- **실습 내용**: Multipart Upload 테스트, 메타데이터 관리, 스토리지 클래스 활용
- **핵심 개념**: 대용량 파일 처리 최적화, 객체 메타데이터 활용, 스토리지 효율성
- **소요시간**: 15-20분
- **스크립트**: `./lab-04-advanced-s3.sh`

#### Lab 5: 성능 테스트
- **학습 내용**: 다양한 파일 크기별 성능 특성, 동시 처리 능력 측정
- **실습 내용**: 업로드/다운로드 성능 측정, 다양한 파일 크기별 테스트, 병목 지점 분석
- **핵심 개념**: 처리량 최적화, 동시 연결 관리, 성능 튜닝 방법
- **소요시간**: 10-15분
- **스크립트**: `./lab-05-performance-test.sh`

#### Lab 6: 사용자 및 권한 관리
- **학습 내용**: IAM 정책 시스템, 정책 기반 접근 제어 (PBAC)
- **실습 내용**: IAM 사용자 생성, 정책 기반 접근 제어, 버킷 정책 설정
- **핵심 개념**: 최소 권한 원칙, 세밀한 권한 제어, 보안 모범 사례
- **특별 기능**: 실제 권한 테스트, 읽기 전용 vs 읽기/쓰기 권한 검증
- **소요시간**: 10-15분
- **스크립트**: `./lab-06-user-management.sh`

### Optional Labs (선택 실습)

#### Lab 7: 모니터링 설정
- Prometheus 메트릭 수집
- Grafana 대시보드 구성
- 알림 규칙 설정
- **소요시간**: 15-20분
- **스크립트**: `./lab-07-monitoring.sh`

#### Lab 8: Helm Chart 실습 (대안 방법)
- 전통적인 Helm 배포 방식
- Operator vs Helm 비교
- **소요시간**: 15-20분
- **스크립트**: `./lab-08-helm-chart.sh`

#### Lab 9: 정적 웹사이트 호스팅 🆕
- **학습 내용**: MinIO를 활용한 S3 호환 정적 웹사이트 호스팅
- **실습 내용**: HTML/CSS/JavaScript 웹사이트 배포, 버킷 정책 설정, 공개 접근 구성
- **핵심 개념**: S3 정적 웹사이트 호스팅, 버킷 정책, CORS 설정, 인덱스 문서 구성
- **특별 기능**: 실제 웹사이트 배포 및 브라우저 접근 테스트, CDN 연동 준비
- **소요시간**: 15-20분
- **스크립트**: `./lab-09-static-website.sh`

#### Lab 10: 백업 및 재해 복구 🆕
- **학습 내용**: MinIO 데이터 백업 전략, 버전 관리, 재해 복구 시나리오
- **실습 내용**: 다양한 백업 방법 실습, 버전 관리 활성화, 삭제된 데이터 복구, 백업 자동화 스크립트 작성
- **핵심 개념**: mc cp vs mc mirror, 객체 버전 관리, 재해 복구 절차, 백업 검증 및 모니터링
- **특별 기능**: 실제 재해 시나리오 시뮬레이션, 자동화된 백업 스크립트 생성, 백업 상태 모니터링
- **소요시간**: 25-30분
- **스크립트**: `./lab-10-backup-recovery.sh`

## 🎓 학습 성과 및 핵심 개념

### 📋 이론적 이해
- **동적 프로비저닝**: PVC 생성 시 자동으로 PV가 생성되는 과정
- **WaitForFirstConsumer**: Pod가 PVC를 사용할 때까지 PV 생성을 지연하는 메커니즘
- **StatefulSet**: 상태 유지 애플리케이션을 위한 Kubernetes 리소스
- **MinIO Operator**: Kubernetes 네이티브 방식의 MinIO 관리
- **Erasure Coding**: 데이터 보호 및 효율성을 위한 MinIO의 핵심 기술

### 🛠️ 실무 기술
- **Kubernetes 리소스 관리**: 네임스페이스, 시크릿, 서비스 등
- **스토리지 트러블슈팅**: PVC Pending 상태 해결, 스토리지 클래스 설정
- **MinIO 관리**: 사용자 생성, 정책 설정, 성능 최적화
- **포트 포워딩**: 클러스터 내부 서비스에 안전한 접근
- **데이터 검증**: 무결성 확인, 실제 저장 위치 확인

### 🔍 실제 환경 이해
- **PV가 "none"으로 표시되는 이유**: 동적 프로비저닝의 정상 동작
- **스토리지 자동 생성 과정**: 프로비저너가 PV를 자동으로 생성하는 메커니즘
- **데이터 실제 저장 위치**: 파일시스템에서 MinIO 데이터 구조 확인
- **스토리지 문제 해결**: 일반적인 문제와 해결 방법
- **프로덕션 배포 고려사항**: 보안, 성능, 확장성 요소

## 🏗️ 아키텍처 개요

### MinIO Operator 아키텍처
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Operator      │    │     Tenant      │    │   MinIO Pods    │
│   Controller    │───▶│   Custom        │───▶│   StatefulSet   │
│                 │    │   Resource      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Console   │    │   Services      │    │   Persistent    │
│   Management    │    │   & Ingress     │    │   Volumes       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Erasure Coding 개념
```
데이터 보호 메커니즘:
┌─────────┬─────────┬─────────┬─────────┐
│ Data 1  │ Data 2  │ Data 3  │ Data 4  │  ← 데이터 블록
├─────────┼─────────┼─────────┼─────────┤
│Parity 1 │Parity 2 │Parity 3 │Parity 4 │  ← 패리티 블록
└─────────┴─────────┴─────────┴─────────┘

EC:4 설정 = 8개 드라이브 중 4개까지 장애 허용
스토리지 효율 = 50% (4/8)
```

## 🔧 주요 학습 포인트

### MinIO Operator vs Helm
| 구분 | Operator | Helm |
|------|----------|------|
| **관리 방식** | 선언적, 자동화 | 템플릿 기반 |
| **라이프사이클** | 자동 관리 | 수동 관리 |
| **복잡도** | 높음 | 낮음 |
| **운영 편의성** | 우수 | 보통 |
| **커스터마이징** | 제한적 | 자유로움 |

### 스토리지 아키텍처
- **Local Path**: 단일 노드 환경, 학습용
- **분산 스토리지**: 다중 노드 환경, 프로덕션용
- **Erasure Coding**: 데이터 보호 및 효율성
- **StatefulSet**: 상태 유지 애플리케이션 관리

### 보안 모델
- **Root 사용자**: 시스템 관리자
- **IAM 사용자**: 일반 사용자
- **정책 기반 제어**: 세밀한 권한 관리
- **버킷 정책**: 리소스별 접근 제어

## 🚨 일반적인 문제 및 해결책

### 1. Pod Pending 상태
**원인**: 스케줄링 불가 (taint, 리소스 부족)
```bash
# Control-plane taint 제거 (단일 노드)
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-

# 리소스 확인
kubectl describe node
```

### 2. PVC Pending 상태
**원인**: 스토리지 클래스 없음
```bash
# Local Path Provisioner 설치
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# 기본 스토리지 클래스 설정
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 3. 시크릿 형식 오류
**원인**: MinIO Operator v5.x 호환성 문제
```bash
# 올바른 시크릿 생성
kubectl create secret generic minio-creds-secret \
  --from-literal=config.env="export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=password123" \
  -n minio-tenant
```

### 4. 포트 접근 불가
**원인**: 포트 포워딩 미설정
```bash
# MinIO API 포트 포워딩
kubectl port-forward svc/minio -n minio-tenant 9000:80 &

# MinIO Console 포트 포워딩
kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &
```

## 📊 성능 최적화 가이드

### 단일 노드 환경
- **CPU**: 2-4 코어 권장
- **메모리**: 4-8GB 권장
- **스토리지**: SSD 권장
- **네트워크**: 로컬 통신으로 지연시간 최소

### 다중 노드 환경
- **CPU**: 노드당 4-8 코어 권장
- **메모리**: 노드당 8-16GB 권장
- **스토리지**: NVMe SSD 권장
- **네트워크**: 10GbE 이상 권장

### 성능 테스트 방법
```bash
# 대용량 파일 업로드 테스트
dd if=/dev/zero of=test-50mb.dat bs=1M count=50
time mc cp test-50mb.dat local/test-bucket/

# 다중 파일 업로드 테스트
for i in {1..10}; do
  dd if=/dev/zero of=test-${i}.dat bs=1M count=5
done
time mc cp test-*.dat local/test-bucket/
```

## 🔄 실습 진행 방법

### 1. 환경 준비
```bash
# 환경 감지 및 설정
./detect-environment.sh
./setup-environment.sh
```

### 2. 실습 실행

#### 통합 메뉴 방식 (권장)
```bash
# 인터랙티브 실습 메뉴 실행
./run-lab.sh

# 메뉴에서 원하는 Lab 선택:
# 0: 환경 사전 검증
# 1: MinIO Operator 설치  
# 2: MinIO Tenant 배포
# 3: MinIO Client 및 기본 사용법
# 4: S3 API 고급 기능
# 5: 성능 테스트
# 6: 사용자 및 권한 관리
```

#### 개별 스크립트 실행 방식
```bash
# 순서대로 개별 실행
./lab-00-env-check.sh
./lab-01-operator-install.sh
./lab-02-tenant-deploy.sh
./lab-03-client-setup.sh
./lab-04-advanced-s3.sh
./lab-05-performance-test.sh
./lab-06-user-management.sh

# 또는 필요한 Lab만 선택적으로 실행
./lab-03-client-setup.sh  # MinIO Client 설정만
./lab-05-performance-test.sh  # 성능 테스트만
```

### 3. 실습 완료 후 정리
```bash
# run-lab.sh 메뉴에서 '9' 선택하여 전체 정리
# 또는 전용 정리 스크립트 실행:
./cleanup-all.sh

# 또는 수동 정리:
kubectl delete namespace minio-tenant
kubectl delete namespace minio-operator
```

## 📖 추가 리소스

### 핵심 개념 상세 가이드
- [Lab 0 핵심 개념: 동적 프로비저닝과 스토리지 클래스](docs/LAB-00-CONCEPTS.md)
- [Lab 1 핵심 개념: Kubernetes Operator 패턴과 CRD](docs/LAB-01-CONCEPTS.md)
- [Lab 2 핵심 개념: MinIO Tenant와 실시간 프로비저닝](docs/LAB-02-CONCEPTS.md)
- [Lab 3 핵심 개념: S3 API와 데이터 무결성 검증](docs/LAB-03-CONCEPTS.md)
- [Lab 7 핵심 개념: Prometheus 모니터링과 Grafana 시각화](docs/LAB-07-CONCEPTS.md)
- [Lab 8 핵심 개념: Helm Chart 배포와 Operator 비교](docs/LAB-08-CONCEPTS.md)

### 공식 문서
- [MinIO 공식 문서](https://docs.min.io/)
- [MinIO Operator GitHub](https://github.com/minio/operator)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)

### 관련 가이드
- [단일 노드 환경 가이드](SINGLE_NODE_GUIDE.md)
- [다중 노드 환경 가이드](MULTI_NODE_GUIDE.md)
- [환경 선택 가이드](SELECT_ENVIRONMENT.md)
- [Kubernetes 환경 구성](K8S_SETUP_GUIDE.md)

### 커뮤니티
- [MinIO Slack](https://slack.min.io/)
- [MinIO GitHub Discussions](https://github.com/minio/minio/discussions)

## 🤝 기여하기

이 실습 가이드는 오픈소스 프로젝트입니다. 개선사항이나 문제점을 발견하시면 언제든지 기여해주세요.

### 기여 방법
1. 이슈 리포트: 문제점이나 개선사항 제안
2. Pull Request: 코드나 문서 개선
3. 피드백: 실습 후기 및 제안사항

### 라이선스
이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---

**💡 팁**: 처음 사용하는 경우 단일 노드 환경으로 시작하여 MinIO의 기본 개념을 익힌 후, 다중 노드 환경으로 확장하는 것을 권장합니다.

**⚠️ 주의**: 이 실습 가이드는 학습 목적으로 설계되었습니다. 프로덕션 환경에서는 보안, 네트워크, 백업 등 추가 고려사항이 필요합니다.
