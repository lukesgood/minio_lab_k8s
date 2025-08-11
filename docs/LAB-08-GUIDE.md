# Lab 8: Helm Chart 실습 - Lab Guide

## 📚 학습 목표

이 실습에서는 전통적인 Helm Chart를 사용한 MinIO 배포 방식을 학습합니다:

- **Helm Chart 기본 개념**: 패키지 관리자로서의 Helm
- **MinIO Helm Chart 배포**: 공식 차트를 사용한 배포
- **Values 파일 커스터마이징**: 환경별 설정 관리
- **Operator vs Helm 비교**: 두 방식의 장단점 분석
- **업그레이드 및 롤백**: Helm을 통한 버전 관리
- **멀티 환경 배포**: 개발/스테이징/프로덕션 환경 관리

## 🎯 핵심 개념

### Helm vs Operator 비교

| 구분 | Helm Chart | MinIO Operator |
|------|------------|----------------|
| **배포 방식** | 템플릿 기반 | CRD 기반 |
| **관리 복잡도** | 낮음 | 높음 |
| **자동화 수준** | 수동 관리 | 자동 관리 |
| **커스터마이징** | 높은 자유도 | 제한적 |
| **운영 편의성** | 보통 | 우수 |
| **학습 곡선** | 완만 | 가파름 |
| **업그레이드** | 수동 실행 | 자동 처리 |

### Helm Chart 구조

```
minio-chart/
├── Chart.yaml          # 차트 메타데이터
├── values.yaml         # 기본 설정값
├── templates/          # Kubernetes 템플릿
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ingress.yaml
└── charts/            # 의존성 차트
```

## 🚀 실습 시작

### 1단계: Helm 설치 및 설정

#### Helm 설치 확인

```bash
# Helm 설치 확인
if ! command -v helm &> /dev/null; then
    echo "Helm 설치 중..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm 버전 확인:"
    helm version
fi

# Helm 저장소 추가
helm repo add minio https://charts.min.io/
helm repo update

# 사용 가능한 MinIO 차트 확인
helm search repo minio
```

### 2단계: 기본 MinIO Helm Chart 배포

#### 네임스페이스 준비

```bash
# Helm 배포용 네임스페이스 생성
kubectl create namespace minio-helm

# 네임스페이스 확인
kubectl get namespaces | grep minio
```

#### 기본 설정으로 배포

```bash
echo "=== 기본 MinIO Helm Chart 배포 ==="

# 기본 values 확인
helm show values minio/minio > default-values.yaml

# 기본 설정으로 배포
helm install minio-helm minio/minio \
  --namespace minio-helm \
  --set auth.rootUser=admin \
  --set auth.rootPassword=password123 \
  --set defaultBuckets="test-bucket"

# 📋 예상 결과:
# NAME: minio-helm
# LAST DEPLOYED: Sun Aug 11 01:45:00 2024
# NAMESPACE: minio-helm
# STATUS: deployed
# REVISION: 1
# TEST SUITE: None
# NOTES:
# MinIO can be accessed via port 9000 on the following DNS name from within your cluster:
# minio-helm.minio-helm.svc.cluster.local
# 
# 💡 설명:
# - Helm 릴리스가 성공적으로 배포됨
# - STATUS: deployed 확인 필요
# - 클러스터 내부 DNS로 접근 가능

# 배포 상태 확인
helm status minio-helm -n minio-helm

# 배포된 리소스 확인
kubectl get all -n minio-helm

# 📋 예상 결과:
# NAME                              READY   STATUS    RESTARTS   AGE
# pod/minio-helm-6c8f7b9d5c-x7k2m  1/1     Running   0          2m
# 
# NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# service/minio-helm   ClusterIP   10.96.123.45    <none>        9000/TCP   2m
# 
# NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/minio-helm   1/1     1            1           2m
# 
# NAME                                    DESIRED   CURRENT   READY   AGE
# replicaset.apps/minio-helm-6c8f7b9d5c  1         1         1       2m
# 
# 💡 설명:
# - Pod가 Running 상태로 정상 배포
# - Deployment로 관리되는 단일 인스턴스
# - ClusterIP 서비스로 내부 접근 가능
```

### 3단계: 커스텀 Values 파일 생성

#### 개발 환경용 설정

```bash
# 개발 환경용 values 파일 생성
cat > values-dev.yaml << 'EOF'
# 개발 환경 MinIO 설정
auth:
  rootUser: "dev-admin"
  rootPassword: "DevPassword123!"

# 리소스 제한 (개발 환경)
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"

# 스토리지 설정
persistence:
  enabled: true
  size: "10Gi"
  storageClass: "local-path"

# 서비스 설정
service:
  type: ClusterIP
  port: 9000

# 기본 버킷 생성
defaultBuckets: "dev-bucket,test-bucket,temp-bucket"

# 모드 설정 (단일 노드)
mode: standalone

# 복제본 수
replicas: 1

# 보안 설정
securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# 환경 변수
environment:
  MINIO_BROWSER_REDIRECT_URL: "http://localhost:9001"
  MINIO_SERVER_URL: "http://localhost:9000"
EOF
```

#### 프로덕션 환경용 설정

```bash
# 프로덕션 환경용 values 파일 생성
cat > values-prod.yaml << 'EOF'
# 프로덕션 환경 MinIO 설정
auth:
  rootUser: "prod-admin"
  rootPassword: "ProdSecurePassword123!"

# 리소스 설정 (프로덕션)
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

# 스토리지 설정
persistence:
  enabled: true
  size: "100Gi"
  storageClass: "local-path"

# 서비스 설정
service:
  type: ClusterIP
  port: 9000

# 분산 모드 설정
mode: distributed
replicas: 4

# 고가용성 설정
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - minio
      topologyKey: kubernetes.io/hostname

# 보안 강화
securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# 네트워크 정책
networkPolicy:
  enabled: true
  allowExternal: false

# 메트릭 활성화
metrics:
  serviceMonitor:
    enabled: true
    namespace: monitoring

# 백업 설정
defaultBuckets: "production-data,backups,logs"
EOF
```

### 4단계: 환경별 배포

#### 개발 환경 배포

```bash
echo "=== 개발 환경 배포 ==="

# 개발 환경 네임스페이스 생성
kubectl create namespace minio-dev

# 개발 환경 배포
helm install minio-dev minio/minio \
  --namespace minio-dev \
  --values values-dev.yaml

# 배포 상태 확인
helm status minio-dev -n minio-dev

# 서비스 확인
kubectl get pods,svc -n minio-dev
```

#### 스테이징 환경 배포

```bash
echo "=== 스테이징 환경 배포 ==="

# 스테이징 환경용 values 생성
cat > values-staging.yaml << 'EOF'
auth:
  rootUser: "staging-admin"
  rootPassword: "StagingPassword123!"

resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"

persistence:
  enabled: true
  size: "50Gi"
  storageClass: "local-path"

mode: standalone
replicas: 2

defaultBuckets: "staging-data,staging-test"

environment:
  MINIO_BROWSER_REDIRECT_URL: "http://localhost:9002"
  MINIO_SERVER_URL: "http://localhost:9000"
EOF

# 스테이징 환경 네임스페이스 생성
kubectl create namespace minio-staging

# 스테이징 환경 배포
helm install minio-staging minio/minio \
  --namespace minio-staging \
  --values values-staging.yaml

# 배포 상태 확인
helm status minio-staging -n minio-staging
```

### 5단계: Helm 배포 관리

#### 배포 목록 및 상태 확인

```bash
echo "=== Helm 배포 관리 ==="

# 모든 Helm 릴리스 확인
helm list --all-namespaces

# 특정 릴리스 상세 정보
helm get all minio-dev -n minio-dev

# 릴리스 히스토리 확인
helm history minio-dev -n minio-dev
```

#### 설정 업데이트

```bash
# 개발 환경 설정 업데이트
cat > values-dev-updated.yaml << 'EOF'
auth:
  rootUser: "dev-admin"
  rootPassword: "DevPassword123!"

resources:
  requests:
    memory: "1Gi"      # 메모리 증가
    cpu: "500m"        # CPU 증가
  limits:
    memory: "2Gi"
    cpu: "1000m"

persistence:
  enabled: true
  size: "20Gi"         # 스토리지 증가
  storageClass: "local-path"

service:
  type: ClusterIP
  port: 9000

defaultBuckets: "dev-bucket,test-bucket,temp-bucket,new-bucket"  # 버킷 추가

mode: standalone
replicas: 1

securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# 새로운 환경 변수 추가
environment:
  MINIO_BROWSER_REDIRECT_URL: "http://localhost:9001"
  MINIO_SERVER_URL: "http://localhost:9000"
  MINIO_REGION_NAME: "dev-region"
EOF

# 설정 업데이트 적용
helm upgrade minio-dev minio/minio \
  --namespace minio-dev \
  --values values-dev-updated.yaml

# 업데이트 상태 확인
helm status minio-dev -n minio-dev
```

### 6단계: 롤백 테스트

#### 의도적 오류 설정 생성

```bash
# 잘못된 설정으로 업데이트 (테스트용)
cat > values-dev-broken.yaml << 'EOF'
auth:
  rootUser: "dev-admin"
  rootPassword: "DevPassword123!"

resources:
  requests:
    memory: "10Gi"     # 과도한 메모리 요청
    cpu: "8000m"       # 과도한 CPU 요청
  limits:
    memory: "20Gi"
    cpu: "16000m"

persistence:
  enabled: true
  size: "20Gi"
  storageClass: "non-existent-class"  # 존재하지 않는 스토리지 클래스

mode: standalone
replicas: 1
EOF

# 잘못된 설정으로 업데이트
helm upgrade minio-dev minio/minio \
  --namespace minio-dev \
  --values values-dev-broken.yaml

# 상태 확인 (실패할 것임)
kubectl get pods -n minio-dev
```

#### 롤백 수행

```bash
echo "=== 롤백 수행 ==="

# 히스토리 확인
helm history minio-dev -n minio-dev

# 이전 버전으로 롤백
helm rollback minio-dev 2 -n minio-dev

# 롤백 후 상태 확인
helm status minio-dev -n minio-dev
kubectl get pods -n minio-dev
```

### 7단계: 커스텀 차트 생성

#### 자체 MinIO 차트 생성

```bash
echo "=== 커스텀 MinIO 차트 생성 ==="

# 새 차트 생성
helm create custom-minio-chart

# 차트 구조 확인
tree custom-minio-chart/

# 커스텀 values.yaml 생성
cat > custom-minio-chart/values.yaml << 'EOF'
# 커스텀 MinIO 차트 설정
replicaCount: 1

image:
  repository: minio/minio
  tag: "latest"
  pullPolicy: IfNotPresent

auth:
  rootUser: "custom-admin"
  rootPassword: "CustomPassword123!"

service:
  type: ClusterIP
  port: 9000
  consolePort: 9001

persistence:
  enabled: true
  size: 10Gi
  storageClass: "local-path"

resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi

buckets:
  - name: "custom-bucket"
  - name: "app-data"
  - name: "logs"

nodeSelector: {}
tolerations: []
affinity: {}
EOF
```

#### 커스텀 템플릿 수정

```bash
# 커스텀 deployment 템플릿 생성
cat > custom-minio-chart/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "custom-minio-chart.fullname" . }}
  labels:
    {{- include "custom-minio-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "custom-minio-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "custom-minio-chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - /bin/bash
            - -c
          args:
            - minio server /data --console-address ":9001"
          env:
            - name: MINIO_ROOT_USER
              value: {{ .Values.auth.rootUser }}
            - name: MINIO_ROOT_PASSWORD
              value: {{ .Values.auth.rootPassword }}
          ports:
            - name: http
              containerPort: 9000
              protocol: TCP
            - name: console
              containerPort: 9001
              protocol: TCP
          volumeMounts:
            - name: data
              mountPath: /data
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      volumes:
        - name: data
          {{- if .Values.persistence.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "custom-minio-chart.fullname" . }}-pvc
          {{- else }}
          emptyDir: {}
          {{- end }}
EOF

# PVC 템플릿 생성
cat > custom-minio-chart/templates/pvc.yaml << 'EOF'
{{- if .Values.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "custom-minio-chart.fullname" . }}-pvc
  labels:
    {{- include "custom-minio-chart.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
  {{- if .Values.persistence.storageClass }}
  storageClassName: {{ .Values.persistence.storageClass }}
  {{- end }}
{{- end }}
EOF
```

#### 커스텀 차트 배포

```bash
# 차트 유효성 검사
helm lint custom-minio-chart/

# 템플릿 렌더링 테스트
helm template custom-minio custom-minio-chart/ --debug

# 커스텀 차트 배포
kubectl create namespace minio-custom
helm install minio-custom custom-minio-chart/ \
  --namespace minio-custom

# 배포 상태 확인
helm status minio-custom -n minio-custom
kubectl get all -n minio-custom
```

### 8단계: 멀티 환경 관리 전략

#### 환경별 values 파일 구조화

```bash
# 환경별 디렉토리 구조 생성
mkdir -p environments/{dev,staging,prod}

# 공통 설정 파일
cat > environments/common.yaml << 'EOF'
# 공통 설정
image:
  repository: minio/minio
  tag: "RELEASE.2024-01-01T00-00-00Z"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 9000

securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

persistence:
  enabled: true
  storageClass: "local-path"
EOF

# 개발 환경 특화 설정
cat > environments/dev/values.yaml << 'EOF'
auth:
  rootUser: "dev-admin"
  rootPassword: "DevPassword123!"

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"

persistence:
  size: "10Gi"

replicas: 1
mode: standalone

defaultBuckets: "dev-bucket,test-bucket"
EOF

# 프로덕션 환경 특화 설정
cat > environments/prod/values.yaml << 'EOF'
auth:
  rootUser: "prod-admin"
  rootPassword: "ProdSecurePassword123!"

resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

persistence:
  size: "100Gi"

replicas: 4
mode: distributed

defaultBuckets: "production-data,backups"

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - minio
      topologyKey: kubernetes.io/hostname
EOF
```

#### 환경별 배포 스크립트

```bash
# 환경별 배포 스크립트 생성
cat > deploy_environment.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=$1
NAMESPACE="minio-${ENVIRONMENT}"

if [ -z "$ENVIRONMENT" ]; then
    echo "사용법: $0 <environment>"
    echo "환경: dev, staging, prod"
    exit 1
fi

if [ ! -f "environments/${ENVIRONMENT}/values.yaml" ]; then
    echo "환경 설정 파일이 없습니다: environments/${ENVIRONMENT}/values.yaml"
    exit 1
fi

echo "=== ${ENVIRONMENT} 환경 배포 ==="

# 네임스페이스 생성
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Helm 배포
helm upgrade --install minio-${ENVIRONMENT} minio/minio \
  --namespace $NAMESPACE \
  --values environments/common.yaml \
  --values environments/${ENVIRONMENT}/values.yaml

# 배포 상태 확인
helm status minio-${ENVIRONMENT} -n $NAMESPACE

echo "=== ${ENVIRONMENT} 환경 배포 완료 ==="
EOF

chmod +x deploy_environment.sh

# 개발 환경 배포 테스트
./deploy_environment.sh dev
```

### 9단계: Operator vs Helm 비교 실습

#### 동일한 설정으로 두 방식 비교

```bash
echo "=== Operator vs Helm 비교 ==="

# 현재 배포된 MinIO 인스턴스 확인
echo "1. Operator 기반 배포:"
kubectl get pods -n minio-tenant

echo -e "\n2. Helm 기반 배포:"
kubectl get pods -n minio-dev

# 리소스 사용량 비교
echo -e "\n3. 리소스 사용량 비교:"
echo "Operator 기반:"
kubectl top pods -n minio-tenant 2>/dev/null || echo "metrics-server 필요"

echo "Helm 기반:"
kubectl top pods -n minio-dev 2>/dev/null || echo "metrics-server 필요"

# 관리 복잡도 비교
echo -e "\n4. 관리 방식 비교:"
echo "Operator: CRD 기반 선언적 관리"
kubectl get tenant -n minio-tenant 2>/dev/null || echo "Operator 없음"

echo "Helm: 템플릿 기반 명령형 관리"
helm list -n minio-dev
```

### 10단계: 성능 및 안정성 테스트

#### Helm 배포 성능 테스트

```bash
# Helm 배포 MinIO 성능 테스트
echo "=== Helm 배포 성능 테스트 ==="

# 포트 포워딩 설정
kubectl port-forward -n minio-dev svc/minio-dev 9010:9000 &
sleep 3

# mc 별칭 설정
mc alias set helm-minio http://localhost:9010 dev-admin DevPassword123!

# 성능 테스트
echo "업로드 성능 테스트:"
dd if=/dev/zero of=helm-test-10mb.dat bs=1M count=10 2>/dev/null
time mc cp helm-test-10mb.dat helm-minio/dev-bucket/

echo "다운로드 성능 테스트:"
time mc cp helm-minio/dev-bucket/helm-test-10mb.dat helm-downloaded.dat

# 정리
rm -f helm-test-10mb.dat helm-downloaded.dat
pkill -f "kubectl port-forward.*9010"
```

### 11단계: 업그레이드 시나리오 테스트

#### 차트 버전 업그레이드

```bash
echo "=== 차트 버전 업그레이드 테스트 ==="

# 현재 차트 버전 확인
helm list -n minio-dev

# 사용 가능한 차트 버전 확인
helm search repo minio/minio --versions | head -10

# 특정 버전으로 업그레이드
CURRENT_VERSION=$(helm list -n minio-dev -o json | jq -r '.[0].chart')
echo "현재 버전: $CURRENT_VERSION"

# 업그레이드 수행 (최신 버전으로)
helm upgrade minio-dev minio/minio \
  --namespace minio-dev \
  --values values-dev-updated.yaml \
  --version $(helm search repo minio/minio -o json | jq -r '.[0].version')

# 업그레이드 상태 확인
helm status minio-dev -n minio-dev
```

### 12단계: 결과 분석 및 정리

#### 배포 방식 비교 결과

```bash
echo "=== 배포 방식 비교 결과 ==="

echo "1. 배포된 Helm 릴리스:"
helm list --all-namespaces

echo -e "\n2. 네임스페이스별 리소스:"
for ns in minio-dev minio-staging minio-custom; do
    echo "  $ns:"
    kubectl get pods -n $ns 2>/dev/null | grep -v "No resources" || echo "    배포 없음"
done

echo -e "\n3. 스토리지 사용량:"
kubectl get pvc --all-namespaces | grep minio

echo -e "\n4. 서비스 엔드포인트:"
kubectl get svc --all-namespaces | grep minio
```

## 🎯 실습 완료 체크리스트

- [ ] Helm 설치 및 기본 배포 완료
- [ ] 커스텀 Values 파일 생성 및 적용
- [ ] 환경별 배포 (dev/staging/prod) 완료
- [ ] 업그레이드 및 롤백 테스트 완료
- [ ] 커스텀 차트 생성 및 배포 완료
- [ ] 멀티 환경 관리 전략 구현 완료
- [ ] Operator vs Helm 비교 분석 완료
- [ ] 성능 및 안정성 테스트 완료

## 🧹 정리

실습이 완료되면 Helm 배포를 정리합니다:

```bash
# 모든 Helm 릴리스 삭제
helm uninstall minio-helm -n minio-helm
helm uninstall minio-dev -n minio-dev
helm uninstall minio-staging -n minio-staging
helm uninstall minio-custom -n minio-custom

# 네임스페이스 삭제
kubectl delete namespace minio-helm
kubectl delete namespace minio-dev
kubectl delete namespace minio-staging
kubectl delete namespace minio-custom

# 테스트 파일 정리
rm -rf custom-minio-chart/ environments/
rm -f *.yaml *.dat deploy_environment.sh

echo "Helm 실습 정리 완료"
```

## 📚 다음 단계

이제 **Lab 9: 정적 웹사이트 호스팅**으로 진행하여 MinIO를 활용한 웹사이트 호스팅을 학습해보세요.

## 💡 핵심 포인트

1. **Helm의 장점**: 템플릿 기반으로 높은 커스터마이징 가능
2. **환경별 관리**: Values 파일을 통한 효율적인 멀티 환경 관리
3. **버전 관리**: 업그레이드와 롤백이 간단하고 안전
4. **학습 용이성**: Operator보다 이해하기 쉬운 구조
5. **운영 고려사항**: 수동 관리가 필요하지만 세밀한 제어 가능

---

**🔗 관련 문서:**
- [LAB-08-CONCEPTS.md](LAB-08-CONCEPTS.md) - Helm Chart 배포 상세 개념
- [LAB-09-GUIDE.md](LAB-09-GUIDE.md) - 다음 Lab Guide: 정적 웹사이트 호스팅
