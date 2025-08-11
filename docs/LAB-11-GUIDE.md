# Lab 11: 고급 보안 설정 - Lab Guide

## 📚 학습 목표

이 실습에서는 MinIO의 고급 보안 기능을 학습합니다:

- **암호화**: 전송 중 및 저장 시 암호화
- **네트워크 보안**: TLS/SSL 설정 및 네트워크 정책
- **접근 제어**: 고급 IAM 정책 및 MFA
- **감사 로깅**: 보안 이벤트 추적
- **취약점 스캔**: 보안 취약점 점검
- **규정 준수**: 보안 표준 준수

## 🎯 핵심 개념

### 보안 계층 모델

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   네트워크 보안  │    │   인증/인가     │    │   데이터 보안    │
│   (TLS/방화벽)   │    │   (IAM/MFA)     │    │   (암호화)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   모니터링      │    │   감사 로깅     │    │   규정 준수     │
│   (실시간 추적)  │    │   (이벤트 기록)  │    │   (정책 준수)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 실습 시작

### 1단계: TLS/SSL 암호화 설정

```bash
echo "=== TLS/SSL 설정 ==="

# 자체 서명 인증서 생성 (테스트용)
openssl req -new -x509 -days 365 -nodes \
  -out minio.crt -keyout minio.key \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=MinIO Lab/CN=localhost"

# 인증서를 Kubernetes Secret으로 생성
kubectl create secret tls minio-tls \
  --cert=minio.crt --key=minio.key \
  -n minio-tenant

# 📋 예상 결과:
# secret/minio-tls created
# 
# 💡 설명:
# - TLS 인증서가 Secret으로 생성됨
# - MinIO Pod에서 HTTPS 통신 가능
# - 자체 서명 인증서로 테스트 환경 구성

# TLS 설정 확인
kubectl get secret minio-tls -n minio-tenant -o yaml
```

### 2단계: 네트워크 보안 정책

```bash
# 네트워크 정책 생성
cat > network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: minio-network-policy
  namespace: minio-tenant
spec:
  podSelector:
    matchLabels:
      app: minio
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
      port: 9001
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF

kubectl apply -f network-policy.yaml

# 📋 예상 결과:
# networkpolicy.networking.k8s.io/minio-network-policy created
# 
# 💡 설명:
# - 네트워크 정책이 적용되어 트래픽 제한
# - 지정된 포트(9000, 9001)만 접근 허용
# - 네임스페이스 간 통신 제어 강화
```

### 3단계: 고급 IAM 정책

```bash
# 고급 보안 정책 생성
cat > advanced-security-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::secure-bucket/*"
      ],
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["10.0.0.0/8", "192.168.0.0/16"]
        },
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T00:00:00Z"
        },
        "StringEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
EOF

mc admin policy add local advanced-security-policy advanced-security-policy.json

# 📋 예상 결과:
# Added policy `advanced-security-policy` successfully.
# 
# 💡 설명:
# - IP 주소 기반 접근 제한 정책 생성
# - 암호화 요구사항 포함
# - 시간 기반 접근 제어 설정
```

### 4단계: 감사 로깅 활성화

```bash
echo "=== 감사 로깅 설정 ==="

# 감사 로깅 활성화
mc admin config set local audit_webhook:1 endpoint=http://audit-server:9000/audit

# 로그 레벨 설정
mc admin config set local logger_webhook:1 endpoint=http://log-server:9000/log

# 설정 적용
mc admin service restart local
```

## 🎯 실습 완료 체크리스트

- [ ] TLS/SSL 암호화 설정 완료
- [ ] 네트워크 보안 정책 적용 완료
- [ ] 고급 IAM 정책 구성 완료
- [ ] 감사 로깅 활성화 완료
- [ ] 보안 모니터링 설정 완료

## 🧹 정리

```bash
# 보안 설정 정리
kubectl delete secret minio-tls -n minio-tenant
kubectl delete networkpolicy minio-network-policy -n minio-tenant
rm -f *.crt *.key *.yaml *.json

echo "고급 보안 설정 실습 정리 완료"
```

## 📚 다음 단계

이제 **Lab 12: 운영 최적화**로 진행하여 MinIO 클러스터의 운영 최적화를 학습해보세요.

## 💡 핵심 포인트

1. **다층 보안**: 네트워크, 애플리케이션, 데이터 계층 보안
2. **최소 권한 원칙**: 필요한 최소한의 권한만 부여
3. **지속적 모니터링**: 실시간 보안 이벤트 추적
4. **정기적 점검**: 보안 설정 및 취약점 정기 검토
5. **규정 준수**: 관련 보안 표준 및 규정 준수

---

**🔗 관련 문서:**
- [LAB-11-CONCEPTS.md](LAB-11-CONCEPTS.md) - 고급 보안 설정 상세 개념
- [LAB-12-GUIDE.md](LAB-12-GUIDE.md) - 다음 Lab Guide: 운영 최적화
