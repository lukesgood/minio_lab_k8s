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

## 문제 해결
트러블슈팅이 필요한 경우 `troubleshooting-guide.md`를 참조하세요.

---
**주의사항**: 실습 환경은 학습 목적으로 구성되었습니다. 프로덕션 환경에서는 보안 및 성능 요구사항을 추가로 고려해야 합니다.
# minio_lab_k8s
