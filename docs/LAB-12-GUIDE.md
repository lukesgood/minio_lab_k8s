# Lab 12: 운영 최적화

## 📚 학습 목표

이 실습에서는 MinIO 클러스터의 운영 최적화 방법을 학습합니다:

- **성능 튜닝**: 시스템 성능 최적화
- **리소스 관리**: CPU, 메모리, 스토리지 최적화
- **자동 스케일링**: 부하에 따른 자동 확장
- **운영 자동화**: 일상적인 운영 작업 자동화
- **장애 대응**: 장애 감지 및 자동 복구
- **용량 계획**: 미래 용량 요구사항 예측

## 🎯 핵심 개념

### 운영 최적화 영역

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   성능 최적화    │    │   리소스 관리    │    │   자동화        │
│   (튜닝/모니터링)│    │   (CPU/메모리)   │    │   (스크립트)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   장애 대응     │    │   용량 계획     │    │   비용 최적화    │
│   (복구/알림)    │    │   (예측/확장)    │    │   (효율성)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 실습 시작

### 1단계: 성능 튜닝

```bash
echo "=== 성능 튜닝 ==="

# MinIO 성능 설정 최적화
mc admin config set local api requests_max=1000
mc admin config set local api requests_deadline=10s
mc admin config set local api cluster_deadline=10s

# 캐시 설정
mc admin config set local cache drives="/tmp/cache"
mc admin config set local cache quota=80

# 압축 설정
mc admin config set local compression enable=on
mc admin config set local compression mime_types=".txt,.log,.csv"

# 설정 적용
mc admin service restart local

# 📋 예상 결과:
# Restart command successfully sent to `local`. Type Ctrl-C to quit or wait to follow the status of the restart process.
# 
# ...
# 
# MinIO service restarted successfully.
# 
# 💡 설명:
# - MinIO 서비스가 새 설정으로 재시작됨
# - 성능 최적화 설정이 적용됨
# - API 요청 처리량 및 응답 시간 개선
```

### 2단계: 리소스 최적화

```bash
# 리소스 사용량 모니터링
cat > resource_optimizer.sh << 'EOF'
#!/bin/bash

echo "=== 리소스 최적화 분석 ==="

# CPU 사용률 분석
echo "CPU 사용률:"
kubectl top pods -n minio-tenant

# 메모리 사용률 분석
echo -e "\n메모리 사용률:"
kubectl describe pods -n minio-tenant | grep -A 3 "Requests\|Limits"

# 스토리지 사용률 분석
echo -e "\n스토리지 사용률:"
kubectl get pvc -n minio-tenant

# 최적화 권장사항
echo -e "\n=== 최적화 권장사항 ==="
echo "1. CPU: 현재 사용률 기반 리소스 조정"
echo "2. 메모리: 버퍼 크기 최적화"
echo "3. 스토리지: I/O 패턴 분석 및 최적화"
EOF

chmod +x resource_optimizer.sh
./resource_optimizer.sh

# 📋 예상 결과:
# === 리소스 최적화 분석 ===
# CPU 사용률:
# NAME                     CPU(cores)   MEMORY(bytes)
# minio-ss-0-0            125m         512Mi
# minio-ss-0-1            98m          445Mi
# 
# 메모리 사용률:
#     Requests:
#       cpu:     250m
#       memory:  512Mi
#     Limits:
#       cpu:     500m
#       memory:  1Gi
# 
# 스토리지 사용률:
# NAME                STATUS   VOLUME                     CAPACITY   ACCESS MODES
# data-minio-ss-0-0   Bound    pvc-abc123                10Gi       RWO
# 
# === 최적화 권장사항 ===
# 1. CPU: 현재 사용률 기반 리소스 조정
# 2. 메모리: 버퍼 크기 최적화
# 3. 스토리지: I/O 패턴 분석 및 최적화
# 
# 💡 설명:
# - 현재 리소스 사용률이 요청량 대비 적절한 수준
# - 메모리 사용률 50% 수준으로 안정적
# - 추가 최적화 여지 확인
```

### 3단계: 자동 스케일링 설정

```bash
# HPA (Horizontal Pod Autoscaler) 설정
cat > hpa.yaml << 'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: minio-hpa
  namespace: minio-tenant
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: minio
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

kubectl apply -f hpa.yaml

# 📋 예상 결과:
# horizontalpodautoscaler.autoscaling/minio-hpa created
# 
# HPA 상태 확인:
# kubectl get hpa -n minio-tenant
# NAME        REFERENCE             TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
# minio-hpa   StatefulSet/minio     15%/70%, 45%/80%   2         10        2          1m
# 
# 💡 설명:
# - CPU 70%, 메모리 80% 임계값으로 자동 스케일링 설정
# - 최소 2개, 최대 10개 Pod로 확장 가능
# - 현재 리소스 사용률이 임계값 이하로 안정적
```

### 4단계: 운영 자동화

```bash
# 운영 자동화 스크립트
cat > operations_automation.sh << 'EOF'
#!/bin/bash

echo "=== 운영 자동화 실행 ==="

# 1. 헬스 체크
health_check() {
    echo "헬스 체크 실행 중..."
    if mc admin info local >/dev/null 2>&1; then
        echo "✅ MinIO 서비스 정상"
    else
        echo "❌ MinIO 서비스 이상"
        # 알림 발송 로직
    fi
}

# 2. 로그 로테이션
log_rotation() {
    echo "로그 로테이션 실행 중..."
    # 오래된 로그 파일 정리
    find /var/log/minio -name "*.log" -mtime +7 -delete
}

# 3. 임시 파일 정리
cleanup_temp_files() {
    echo "임시 파일 정리 중..."
    # 임시 파일 정리
    find /tmp -name "minio-*" -mtime +1 -delete
}

# 4. 성능 메트릭 수집
collect_metrics() {
    echo "성능 메트릭 수집 중..."
    mc admin prometheus metrics local > /var/log/minio/metrics-$(date +%Y%m%d_%H%M%S).txt
}

# 메인 실행
main() {
    health_check
    log_rotation
    cleanup_temp_files
    collect_metrics
    echo "운영 자동화 완료"
}

main
EOF

chmod +x operations_automation.sh
./operations_automation.sh
```

### 5단계: 장애 대응 자동화

```bash
# 장애 대응 스크립트
cat > failure_recovery.sh << 'EOF'
#!/bin/bash

echo "=== 장애 대응 시스템 ==="

# 장애 감지
detect_failures() {
    echo "장애 감지 중..."
    
    # Pod 상태 확인
    failed_pods=$(kubectl get pods -n minio-tenant --field-selector=status.phase!=Running --no-headers | wc -l)
    
    if [ "$failed_pods" -gt 0 ]; then
        echo "⚠️  실패한 Pod 발견: $failed_pods 개"
        return 1
    else
        echo "✅ 모든 Pod 정상 상태"
        return 0
    fi
}

# 자동 복구
auto_recovery() {
    echo "자동 복구 시작..."
    
    # 실패한 Pod 재시작
    kubectl delete pods -n minio-tenant --field-selector=status.phase!=Running
    
    # 복구 대기
    sleep 30
    
    # 복구 확인
    if detect_failures; then
        echo "✅ 자동 복구 성공"
    else
        echo "❌ 자동 복구 실패 - 수동 개입 필요"
        # 관리자 알림
    fi
}

# 메인 실행
if ! detect_failures; then
    auto_recovery
fi
EOF

chmod +x failure_recovery.sh
./failure_recovery.sh
```

### 6단계: 용량 계획

```bash
# 용량 계획 스크립트
cat > capacity_planning.sh << 'EOF'
#!/bin/bash

echo "=== 용량 계획 분석 ==="

# 현재 사용량 분석
analyze_current_usage() {
    echo "현재 스토리지 사용량:"
    
    total_usage=$(mc du local/ | tail -1 | awk '{print $1}')
    echo "총 사용량: $total_usage"
    
    # 버킷별 사용량
    echo -e "\n버킷별 사용량:"
    mc ls local | while read line; do
        bucket=$(echo $line | awk '{print $5}')
        if [ -n "$bucket" ]; then
            usage=$(mc du local/$bucket | awk '{print $1}')
            echo "  $bucket: $usage"
        fi
    done
}

# 성장률 예측
predict_growth() {
    echo -e "\n성장률 예측:"
    
    # 간단한 선형 성장 모델 (실제로는 더 정교한 분석 필요)
    current_month=$(date +%m)
    growth_rate=10  # 월 10% 성장 가정
    
    echo "예상 성장률: ${growth_rate}% per month"
    
    for i in {1..12}; do
        future_month=$((current_month + i))
        if [ $future_month -gt 12 ]; then
            future_month=$((future_month - 12))
        fi
        
        growth_factor=$(echo "scale=2; 1 + ($growth_rate * $i / 100)" | bc -l)
        echo "  ${i}개월 후: ${growth_factor}x 증가 예상"
    done
}

# 용량 권장사항
capacity_recommendations() {
    echo -e "\n=== 용량 권장사항 ==="
    echo "1. 현재 사용률이 70% 초과 시 확장 고려"
    echo "2. 6개월 후 예상 사용량 기준 용량 계획"
    echo "3. 백업 및 복제를 위한 추가 용량 확보"
    echo "4. 성능 최적화를 위한 SSD 스토리지 고려"
}

# 메인 실행
analyze_current_usage
predict_growth
capacity_recommendations
EOF

chmod +x capacity_planning.sh
./capacity_planning.sh
```

### 7단계: 비용 최적화

```bash
# 비용 최적화 분석
cat > cost_optimization.sh << 'EOF'
#!/bin/bash

echo "=== 비용 최적화 분석 ==="

# 스토리지 비용 분석
analyze_storage_costs() {
    echo "스토리지 비용 분석:"
    
    # 스토리지 클래스별 사용량
    echo "스토리지 클래스별 사용량:"
    kubectl get pvc -n minio-tenant -o custom-columns=NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,SIZE:.spec.resources.requests.storage
    
    # 미사용 스토리지 식별
    echo -e "\n미사용 스토리지 식별:"
    # 실제로는 더 정교한 분석 필요
    echo "정기적인 사용량 모니터링을 통한 최적화 필요"
}

# 리소스 효율성 분석
analyze_resource_efficiency() {
    echo -e "\n리소스 효율성 분석:"
    
    # CPU/메모리 사용률 vs 할당량
    echo "리소스 사용률 분석:"
    kubectl top pods -n minio-tenant
    
    echo -e "\n최적화 기회:"
    echo "- 과도하게 할당된 리소스 조정"
    echo "- 사용률이 낮은 시간대 스케일 다운"
    echo "- 스토리지 계층화 적용"
}

# 비용 절감 권장사항
cost_saving_recommendations() {
    echo -e "\n=== 비용 절감 권장사항 ==="
    echo "1. 자동 스케일링으로 리소스 효율성 향상"
    echo "2. 스토리지 계층화로 비용 최적화"
    echo "3. 압축 및 중복 제거 활성화"
    echo "4. 미사용 데이터 아카이브 정책 수립"
    echo "5. 리소스 사용량 정기 검토"
}

# 메인 실행
analyze_storage_costs
analyze_resource_efficiency
cost_saving_recommendations
EOF

chmod +x cost_optimization.sh
./cost_optimization.sh
```

### 8단계: 종합 운영 대시보드

```bash
# 운영 대시보드 스크립트
cat > operations_dashboard.sh << 'EOF'
#!/bin/bash

echo "=== MinIO 운영 대시보드 ==="

# 시스템 상태 요약
system_status() {
    echo "📊 시스템 상태 요약"
    echo "===================="
    
    # 서비스 상태
    if mc admin info local >/dev/null 2>&1; then
        echo "🟢 MinIO 서비스: 정상"
    else
        echo "🔴 MinIO 서비스: 이상"
    fi
    
    # Pod 상태
    running_pods=$(kubectl get pods -n minio-tenant --field-selector=status.phase=Running --no-headers | wc -l)
    total_pods=$(kubectl get pods -n minio-tenant --no-headers | wc -l)
    echo "📦 Pod 상태: $running_pods/$total_pods 실행 중"
    
    # 스토리지 사용량
    total_usage=$(mc du local/ 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
    echo "💾 스토리지 사용량: $total_usage"
}

# 성능 메트릭
performance_metrics() {
    echo -e "\n📈 성능 메트릭"
    echo "=============="
    
    # API 응답 시간 (간단한 테스트)
    start_time=$(date +%s.%N)
    mc ls local >/dev/null 2>&1
    end_time=$(date +%s.%N)
    response_time=$(echo "$end_time - $start_time" | bc -l)
    echo "⚡ API 응답 시간: ${response_time}초"
    
    # 리소스 사용률
    echo "🖥️  리소스 사용률:"
    kubectl top pods -n minio-tenant 2>/dev/null || echo "   metrics-server 필요"
}

# 최근 이벤트
recent_events() {
    echo -e "\n📋 최근 이벤트"
    echo "============="
    
    kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | tail -5
}

# 권장 조치
recommendations() {
    echo -e "\n💡 권장 조치"
    echo "==========="
    
    # 간단한 헬스 체크 기반 권장사항
    if ! mc admin info local >/dev/null 2>&1; then
        echo "🚨 MinIO 서비스 점검 필요"
    fi
    
    # 리소스 사용률 기반 권장사항
    echo "📊 정기적인 성능 모니터링 권장"
    echo "🔄 백업 상태 확인 권장"
    echo "🔒 보안 설정 점검 권장"
}

# 메인 실행
clear
echo "MinIO Kubernetes Lab - 운영 대시보드"
echo "Generated at: $(date)"
echo "========================================"

system_status
performance_metrics
recent_events
recommendations

echo -e "\n========================================"
echo "대시보드 업데이트: $(date)"
EOF

chmod +x operations_dashboard.sh
./operations_dashboard.sh
```

## 🎯 실습 완료 체크리스트

- [ ] 성능 튜닝 설정 완료
- [ ] 리소스 최적화 분석 완료
- [ ] 자동 스케일링 설정 완료
- [ ] 운영 자동화 스크립트 작성 완료
- [ ] 장애 대응 시스템 구축 완료
- [ ] 용량 계획 수립 완료
- [ ] 비용 최적화 분석 완료
- [ ] 운영 대시보드 구축 완료

## 🧹 정리

실습이 완료되면 운영 최적화 관련 리소스를 정리합니다:

```bash
# HPA 삭제
kubectl delete hpa minio-hpa -n minio-tenant

# 스크립트 정리
rm -f *.sh *.yaml

echo "운영 최적화 실습 정리 완료"
```

## 📚 실습 과정 완료

축하합니다! MinIO Kubernetes Lab의 모든 실습을 완료하셨습니다.

## 💡 핵심 포인트

1. **지속적 최적화**: 성능과 비용의 균형점 찾기
2. **자동화**: 반복적인 운영 작업의 자동화
3. **모니터링**: 실시간 상태 추적 및 분석
4. **예측적 관리**: 미래 요구사항 예측 및 대비
5. **비용 효율성**: 리소스 사용량과 비용의 최적화

---

**🔗 관련 문서:**
- [LAB-12-CONCEPTS.md](LAB-12-CONCEPTS.md) - 운영 최적화 상세 개념
- [README.md](../README.md) - 전체 실습 가이드 개요
