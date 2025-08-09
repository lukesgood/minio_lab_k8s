# MinIO Kubernetes Lab Guide

## 실습 환경
- Multipass Ubuntu VMs
- Kubernetes 클러스터
- MinIO Operator & Helm Charts

## 실습 구성

### 1. 환경 준비
```bash
# 실행 권한 부여
chmod +x *.sh

# 실습 메뉴 실행
./run-lab.sh
```

### 2. 실습 순서 (권장)
1. **MinIO Operator 설치** - 최신 운영 방식
2. **MinIO Tenant 배포** - 프로덕션 환경 구성
3. **Helm Chart 설치** - 전통적인 배포 방식
4. **성능 테스트** - 벤치마킹 및 최적화
5. **모니터링 설정** - 운영 관리

### 3. 주요 학습 포인트

#### MinIO Operator vs Helm
- **Operator**: 자동화된 운영, CRD 기반 관리
- **Helm**: 템플릿 기반, 커스터마이징 용이

#### 아키텍처 이해
- **Erasure Coding**: 데이터 보호 메커니즘
- **분산 모드**: 고가용성 및 확장성
- **StatefulSet**: 상태 유지 애플리케이션

#### 운영 관리
- **모니터링**: 메트릭 수집 및 알림
- **백업**: 데이터 보호 전략
- **보안**: 인증, 권한, 암호화


## 추가 리소스
- [MinIO 공식 문서](https://docs.min.io/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [MinIO Operator GitHub](https://github.com/minio/operator)

## MinIO 핵심 이론

### 1. MinIO 아키텍처 개요

#### Object Storage 기본 개념
- **S3 호환성**: AWS S3 API와 100% 호환되는 오픈소스 객체 스토리지
- **RESTful API**: HTTP/HTTPS 기반의 간단한 인터페이스
- **버킷과 객체**: 데이터를 버킷(컨테이너) 내의 객체로 저장
- **메타데이터**: 각 객체에 연결된 키-값 쌍의 추가 정보

#### Erasure Coding (EC)
```
데이터 보호 메커니즘:
- 데이터를 N개의 데이터 블록과 M개의 패리티 블록으로 분할
- 총 N+M개 드라이브 중 최대 M개까지 장애 허용
- 예: EC:4 설정 → 8개 드라이브 중 4개까지 장애 허용 가능
- RAID보다 효율적인 스토리지 활용률 (50% vs 33%)
```

#### 분산 아키텍처
- **최소 요구사항**: 4개 드라이브 (2개 데이터 + 2개 패리티)
- **권장 구성**: 8개 이상 드라이브 (확장성과 성능 고려)
- **서버 풀**: 동일한 구성의 서버 그룹으로 확장
- **일관성 모델**: Strong Read-After-Write consistency 보장

### 2. Kubernetes 배포 방식 비교

#### MinIO Operator 방식
**개념**: Kubernetes Operator 패턴을 사용한 선언적 관리
```yaml
# Custom Resource Definition (CRD) 기반
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
spec:
  pools:
  - servers: 4
    volumesPerServer: 2
```

**장점**:
- 자동화된 라이프사이클 관리 (설치, 업그레이드, 스케일링)
- 내장된 모니터링 및 알림 시스템
- 웹 기반 관리 콘솔 제공
- 복잡한 운영 작업의 자동화

**단점**:
- 학습 곡선이 높음
- Operator 자체의 의존성
- 커스터마이징 제한

#### Helm Chart 방식
**개념**: 템플릿 기반 패키지 관리자를 통한 배포
```yaml
# values.yaml을 통한 설정
mode: distributed
statefulset:
  replicaCount: 4
  drivesPerNode: 2
```

**장점**:
- 기존 Helm 워크플로우 활용 가능
- 높은 커스터마이징 자유도
- 버전 관리 및 롤백 용이
- 템플릿 재사용성

**단점**:
- 수동 운영 관리 필요
- 복잡한 업그레이드 프로세스
- 별도 모니터링 설정 필요

### 3. StatefulSet vs Deployment

#### StatefulSet 사용 이유
MinIO는 상태 유지 애플리케이션으로 다음이 필요:
- **안정적인 네트워크 ID**: minio-0, minio-1, minio-2...
- **순서 보장**: 순차적 시작/종료
- **영구 스토리지**: 각 Pod마다 고유한 PVC
- **DNS 이름**: Headless Service를 통한 직접 접근

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
spec:
  serviceName: minio-headless
  replicas: 4
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### 4. 성능 최적화 이론

#### 네트워크 최적화
- **대역폭**: 10GbE 이상 권장 (25GbE/40GbE 이상 이상적)
- **지연시간**: 1ms 이하 권장
- **네트워크 토폴로지**: Leaf-Spine 아키텍처 권장
- **로드 밸런싱**: 라운드 로빈 또는 최소 연결 방식

#### 스토리지 최적화
- **드라이브 타입**: NVMe SSD > SATA SSD > HDD
- **RAID 불필요**: Erasure Coding이 데이터 보호 담당
- **직접 연결**: 하드웨어 RAID 컨트롤러 우회
- **파일시스템**: XFS 권장 (ext4도 가능)

#### 시스템 리소스
- **CPU**: 코어당 1-2개 드라이브 권장
- **메모리**: 메타데이터 캐싱용 (드라이브당 1-2GB)
- **OS 튜닝**: ulimit, vm.swappiness, TCP 버퍼 크기

### 5. 보안 아키텍처

#### 인증 및 권한
```
계층적 보안 모델:
1. Root 사용자 (관리자)
2. IAM 사용자 (일반 사용자)
3. Service Account (애플리케이션)
4. STS (임시 자격 증명)
```

#### 암호화
- **전송 중 암호화**: TLS 1.2+ (mTLS 지원)
- **저장 시 암호화**: AES-256 (KMS 통합 가능)
- **키 관리**: 내장 KMS 또는 외부 KMS 연동

#### 네트워크 보안
- **VPC/VLAN 분리**: 스토리지 전용 네트워크
- **방화벽 규칙**: 필요한 포트만 개방 (9000, 9001)
- **네트워크 정책**: Kubernetes NetworkPolicy 활용

## 실습별 상세 이론

### Lab 1: MinIO Operator 실습

#### Operator 패턴 이해
```
Kubernetes Operator = Controller + Custom Resource
- Controller: 원하는 상태와 현재 상태를 지속적으로 비교
- Custom Resource: 애플리케이션별 설정을 Kubernetes API로 관리
- Reconciliation Loop: 상태 불일치 시 자동 복구
```

#### MinIO Operator 구성 요소
- **Operator Pod**: MinIO 클러스터 관리 로직
- **Console**: 웹 기반 관리 인터페이스
- **Tenant CRD**: MinIO 클러스터 정의
- **User CRD**: 사용자 및 권한 관리

#### 실습에서 학습할 내용
- CRD 기반 선언적 관리
- 자동화된 TLS 인증서 관리
- 내장 모니터링 및 로깅
- 웹 콘솔을 통한 GUI 관리

### Lab 2: MinIO Tenant 배포 실습

#### Tenant 개념
```
Tenant = MinIO 클러스터의 논리적 단위
- 독립적인 네임스페이스
- 전용 리소스 할당
- 격리된 보안 정책
- 개별 모니터링 및 로깅
```

#### 서버 풀 (Server Pool) 아키텍처
```yaml
pools:
- servers: 4          # 서버 수
  volumesPerServer: 2  # 서버당 볼륨 수
  # 총 8개 드라이브 = 4 서버 × 2 볼륨
```

#### Erasure Coding 계산
```
EC:N 설정에서:
- 데이터 드라이브: 총 드라이브 수 / 2
- 패리티 드라이브: 총 드라이브 수 / 2
- 장애 허용: N개 드라이브
- 스토리지 효율: 50% (N=총드라이브수/2일 때)
```

#### 실습에서 학습할 내용
- Tenant 설정 파일 작성
- PVC 템플릿 구성
- 리소스 할당 계획
- 서비스 노출 방법

### Lab 3: Helm Chart 실습

#### Helm 템플릿 엔진
```
Template + Values = Kubernetes Manifests
- 재사용 가능한 차트
- 환경별 설정 분리
- 버전 관리 및 롤백
- 의존성 관리
```

#### MinIO Helm Chart 구조
```
minio/
├── Chart.yaml          # 차트 메타데이터
├── values.yaml          # 기본 설정값
├── templates/
│   ├── statefulset.yaml # MinIO StatefulSet
│   ├── service.yaml     # 서비스 정의
│   ├── configmap.yaml   # 설정 맵
│   └── secret.yaml      # 인증 정보
```

#### Standalone vs Distributed 모드
```yaml
# Standalone 모드
mode: standalone
replicas: 1

# Distributed 모드  
mode: distributed
statefulset:
  replicaCount: 4
  drivesPerNode: 2
```

#### 실습에서 학습할 내용
- Helm 차트 설치 및 관리
- Values 파일 커스터마이징
- 분산 모드 구성
- 업그레이드 및 롤백

### Lab 4: 성능 테스트 실습

#### 성능 측정 지표
```
처리량 (Throughput):
- PUT/GET 요청 수 (ops/sec)
- 데이터 전송률 (MB/s, GB/s)

지연시간 (Latency):
- 평균 응답 시간
- 95th/99th 백분위수
- 첫 바이트까지의 시간 (TTFB)
```

#### 병목 지점 분석
```
네트워크 병목:
- 대역폭 포화
- 패킷 손실
- 지연시간 증가

스토리지 병목:
- IOPS 한계
- 큐 깊이 부족
- 파일시스템 오버헤드

CPU/메모리 병목:
- 높은 CPU 사용률
- 메모리 부족
- GC 압박
```

#### 최적화 전략
```
클라이언트 최적화:
- 멀티파트 업로드 사용
- 동시 연결 수 조정
- 적절한 청크 크기

서버 최적화:
- 드라이브 수 증가
- 네트워크 대역폭 확장
- 메모리 캐시 튜닝
```

#### 실습에서 학습할 내용
- mc speed test 사용법
- 다양한 파일 크기별 성능 측정
- 병렬 업로드/다운로드 테스트
- 성능 병목 지점 식별

### Lab 5: 모니터링 실습

#### 메트릭 수집 아키텍처
```
MinIO → Prometheus → Grafana
- MinIO: /minio/v2/metrics/cluster 엔드포인트
- Prometheus: 메트릭 수집 및 저장
- Grafana: 시각화 및 알림
```

#### 주요 모니터링 지표
```
용량 지표:
- minio_cluster_capacity_usable_total_bytes
- minio_cluster_capacity_usable_free_bytes
- minio_bucket_usage_total_bytes

성능 지표:
- minio_http_requests_duration_seconds
- minio_s3_requests_total
- minio_network_sent_bytes_total

가용성 지표:
- minio_cluster_nodes_online_total
- minio_cluster_nodes_offline_total
- minio_heal_objects_total
```

#### 알림 설정
```yaml
# Prometheus AlertManager 규칙
groups:
- name: minio
  rules:
  - alert: MinIONodeDown
    expr: minio_cluster_nodes_offline_total > 0
    for: 5m
    annotations:
      summary: "MinIO node is down"
```

#### 실습에서 학습할 내용
- ServiceMonitor 설정
- Grafana 대시보드 구성
- 알림 규칙 작성
- 메트릭 기반 용량 계획


### 아키텍처 Q&A
**Q: MinIO의 Erasure Coding과 RAID의 차이점은?**
A: 
- **Erasure Coding**: 소프트웨어 기반, 네트워크를 통한 분산 저장, 50% 스토리지 효율
- **RAID**: 하드웨어 기반, 단일 서버 내 드라이브, 33% 스토리지 효율 (RAID 5)
- **확장성**: EC는 서버 추가로 확장, RAID는 단일 서버 제한
- **복구**: EC는 네트워크를 통한 분산 복구, RAID는 로컬 복구

**Q: MinIO 클러스터에서 노드 장애 시 어떻게 처리되나요?**
A:
- **자동 감지**: Health check를 통한 노드 상태 모니터링
- **읽기 복구**: 남은 노드에서 Erasure Coding으로 데이터 재구성
- **쓰기 처리**: 가용한 노드에만 데이터 저장, 복구 후 동기화
- **힐링**: 노드 복구 시 자동으로 누락된 데이터 복원

### 운영 Q&A
**Q: MinIO 클러스터 확장 시 고려사항은?**
A:
- **서버 풀 단위**: 동일한 드라이브 수로 풀 추가
- **데이터 재분산 없음**: 기존 데이터는 그대로 유지
- **로드 밸런서**: 새 노드 추가 시 설정 업데이트
- **네트워크**: 추가 대역폭 및 스위치 포트 확보
- **모니터링**: 새 노드에 대한 메트릭 수집 설정

**Q: 대용량 데이터 마이그레이션 전략은?**
A:
- **단계적 접근**: 중요도별 데이터 우선순위 설정
- **병렬 전송**: 여러 클라이언트를 통한 동시 업로드
- **검증**: 체크섬을 통한 데이터 무결성 확인
- **롤백 계획**: 문제 발생 시 원본 시스템으로 복구
- **네트워크 최적화**: 전용 네트워크 또는 대역폭 예약

### 보안 Q&A
**Q: MinIO에서 Zero-Trust 보안 모델 구현 방법은?**
A:
- **네트워크 암호화**: 모든 통신에 TLS 적용
- **최소 권한**: IAM 정책으로 필요한 권한만 부여
- **네트워크 분할**: Kubernetes NetworkPolicy로 트래픽 제한
- **인증 강화**: mTLS, OIDC 연동
- **감사 로깅**: 모든 API 호출 기록 및 분석

## 문제 해결
트러블슈팅이 필요한 경우 `troubleshooting-guide.md`를 참조하세요.

---
**주의사항**: 실습 환경은 학습 목적으로 구성되었습니다. 프로덕션 환경에서는 보안 및 성능 요구사항을 추가로 고려해야 합니다.
