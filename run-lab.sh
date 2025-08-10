#!/bin/bash

echo "=== MinIO Kubernetes Lab 실행 가이드 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo -e "${BLUE}📚 실습 메뉴를 선택하세요:${NC}"
    echo ""
    echo -e "${GREEN}=== Core Labs (필수 실습) ===${NC}"
    echo "0) 환경 사전 검증 (5-10분)"
    echo "1) MinIO Operator 설치 (10-15분)"
    echo "2) MinIO Tenant 배포 (15-20분)"
    echo "3) MinIO Client 및 기본 사용법 (10-15분)"
    echo ""
    echo -e "${YELLOW}=== Advanced Labs (권장 실습) ===${NC}"
    echo "4) S3 API 고급 기능 테스트 (15-20분)"
    echo "5) 성능 테스트 (10-15분)"
    echo "6) 사용자 및 권한 관리 (10-15분)"
    echo ""
    echo -e "${BLUE}=== Optional Labs (선택 실습) ===${NC}"
    echo "7) 모니터링 설정"
    echo "8) Helm Chart 실습 (대안 방법)"
    echo ""
    echo -e "${RED}=== 관리 ===${NC}"
    echo "9) 전체 정리"
    echo "h) 도움말"
    echo "q) 종료"
    echo ""
}

show_help() {
    echo -e "${BLUE}📖 도움말${NC}"
    echo ""
    echo "실습 순서 권장사항:"
    echo "1. 처음 사용자: 0 → 1 → 2 → 3 → 4 → 5 → 6 순서로 진행"
    echo "2. 경험자: 필요한 모듈만 선택적으로 실행"
    echo "3. 문제 발생 시: 해당 모듈의 트러블슈팅 가이드 참조"
    echo ""
    echo "관련 문서:"
    echo "- 단일 노드 가이드: SINGLE_NODE_GUIDE.md"
    echo "- 다중 노드 가이드: MULTI_NODE_GUIDE.md"
    echo "- 환경 선택 가이드: SELECT_ENVIRONMENT.md"
    echo ""
}

lab_0_env_check() {
    echo -e "${GREEN}=== Lab 0: 환경 사전 검증 ===${NC}"
    echo ""
    
    # 환경 감지 실행
    if [ -f "./detect-environment.sh" ]; then
        echo "환경 자동 감지 실행 중..."
        ./detect-environment.sh
    else
        echo -e "${YELLOW}⚠️  detect-environment.sh 파일이 없습니다.${NC}"
        echo "수동으로 환경을 확인합니다..."
        
        echo "1. 클러스터 연결 확인..."
        kubectl cluster-info
        
        echo "2. 노드 상태 확인..."
        kubectl get nodes
        
        echo "3. 스토리지 클래스 확인..."
        kubectl get storageclass
    fi
    
    echo ""
    echo -e "${GREEN}✅ Lab 0 완료${NC}"
    read -p "계속하려면 Enter를 누르세요..."
}

lab_1_operator_install() {
    echo -e "${GREEN}=== Lab 1: MinIO Operator 설치 ===${NC}"
    echo ""
    
    # Operator 설치
    echo "1. MinIO Operator 설치 중..."
    kubectl apply -k "github.com/minio/operator?ref=v5.0.10"
    
    echo "2. 설치 상태 확인..."
    kubectl get pods -n minio-operator
    
    # 단일 노드 최적화
    echo "3. 단일 노드 환경 최적화..."
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -eq 1 ]; then
        echo "단일 노드 감지 - Operator replica를 1로 조정..."
        kubectl scale deployment minio-operator -n minio-operator --replicas=1
    fi
    
    echo ""
    echo -e "${GREEN}✅ Lab 1 완료${NC}"
    echo "MinIO Operator가 설치되었습니다."
    read -p "계속하려면 Enter를 누르세요..."
}

lab_2_tenant_deploy() {
    echo -e "${GREEN}=== Lab 2: MinIO Tenant 배포 ===${NC}"
    echo ""
    
    # 네임스페이스 생성
    echo "1. 네임스페이스 생성..."
    kubectl create namespace minio-tenant --dry-run=client -o yaml | kubectl apply -f -
    
    # 시크릿 생성
    echo "2. 인증 시크릿 생성..."
    kubectl create secret generic minio-creds-secret \
      --from-literal=config.env="export MINIO_ROOT_USER=minio
export MINIO_ROOT_PASSWORD=minio123" \
      -n minio-tenant --dry-run=client -o yaml | kubectl apply -f -
    
    # Tenant YAML 적용
    echo "3. MinIO Tenant 배포..."
    if [ -f "./minio-tenant.yaml" ]; then
        kubectl apply -f minio-tenant.yaml
    else
        echo -e "${YELLOW}⚠️  minio-tenant.yaml 파일이 없습니다. 기본 설정으로 생성합니다.${NC}"
        # 기본 Tenant YAML 생성 및 적용
        cat > temp-tenant.yaml << 'EOF'
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: minio-tenant
  namespace: minio-tenant
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
  - servers: 1
    name: pool-0
    volumesPerServer: 2
    volumeClaimTemplate:
      metadata:
        name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Gi
        storageClassName: local-path
  mountPath: /export
  configuration:
    name: minio-creds-secret
  requestAutoCert: false
EOF
        kubectl apply -f temp-tenant.yaml
        rm temp-tenant.yaml
    fi
    
    echo "4. 배포 상태 확인..."
    kubectl get tenant -n minio-tenant
    kubectl get pods -n minio-tenant
    
    echo ""
    echo -e "${GREEN}✅ Lab 2 완료${NC}"
    echo "MinIO Tenant가 배포되었습니다."
    read -p "계속하려면 Enter를 누르세요..."
}

lab_3_client_setup() {
    echo -e "${GREEN}=== Lab 3: MinIO Client 및 기본 사용법 ===${NC}"
    echo ""
    
    # MinIO Client 설치 확인
    echo "1. MinIO Client 설치 확인..."
    if ! command -v mc &> /dev/null; then
        echo "MinIO Client 설치 중..."
        curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
        chmod +x mc
        sudo mv mc /usr/local/bin/ 2>/dev/null || mv mc ~/bin/ 2>/dev/null || echo "mc를 PATH에 추가하세요"
    else
        echo "MinIO Client가 이미 설치되어 있습니다."
    fi
    
    # 포트 포워딩 설정
    echo "2. 포트 포워딩 설정..."
    kubectl port-forward svc/minio -n minio-tenant 9000:80 &
    kubectl port-forward svc/minio-tenant-console -n minio-tenant 9001:9090 &
    
    sleep 5
    
    # 서버 연결 설정
    echo "3. MinIO 서버 연결 설정..."
    mc alias set local http://localhost:9000 minio minio123
    
    # 기본 기능 테스트
    echo "4. 기본 기능 테스트..."
    echo "   - 서버 정보 확인..."
    mc admin info local
    
    echo "   - 테스트 버킷 생성..."
    mc mb local/test-bucket
    
    echo "   - 테스트 파일 업로드..."
    echo "Hello MinIO from Kubernetes Lab!" > test-file.txt
    mc cp test-file.txt local/test-bucket/
    
    echo "   - 버킷 내용 확인..."
    mc ls local/test-bucket/
    
    echo ""
    echo -e "${GREEN}✅ Lab 3 완료${NC}"
    echo "MinIO Client 설정 및 기본 기능 테스트가 완료되었습니다."
    echo ""
    echo "웹 콘솔 접근: http://localhost:9001"
    echo "사용자: minio, 비밀번호: minio123"
    read -p "계속하려면 Enter를 누르세요..."
}

lab_4_advanced_s3() {
    echo -e "${GREEN}=== Lab 4: S3 API 고급 기능 테스트 ===${NC}"
    echo ""
    
    # Multipart Upload 테스트
    echo "1. Multipart Upload 테스트..."
    echo "   - 대용량 파일 생성 (50MB)..."
    dd if=/dev/zero of=large-file.dat bs=1M count=50 2>/dev/null
    
    echo "   - Multipart Upload 실행..."
    time mc cp large-file.dat local/test-bucket/
    
    echo "   - Single Part Upload 비교..."
    time mc cp --disable-multipart large-file.dat local/test-bucket/large-file-single.dat
    
    # 메타데이터 테스트
    echo "2. 메타데이터 관리 테스트..."
    echo "   - 커스텀 메타데이터로 파일 업로드..."
    mc cp --attr "Content-Type=text/plain;Author=MinIO-Lab;Version=1.0" test-file.txt local/test-bucket/metadata-test.txt
    
    # 객체 정보 확인
    echo "   - 객체 상세 정보 확인..."
    mc stat local/test-bucket/metadata-test.txt
    
    echo ""
    echo -e "${GREEN}✅ Lab 4 완료${NC}"
    echo "S3 API 고급 기능 테스트가 완료되었습니다."
    read -p "계속하려면 Enter를 누르세요..."
}

lab_5_performance_test() {
    echo -e "${GREEN}=== Lab 5: 성능 테스트 ===${NC}"
    echo ""
    
    # 다양한 크기의 파일 테스트
    echo "1. 다양한 파일 크기별 성능 테스트..."
    
    for size in 1 5 10 25; do
        echo "   - ${size}MB 파일 테스트..."
        dd if=/dev/zero of=test-${size}mb.dat bs=1M count=${size} 2>/dev/null
        echo "     업로드 시간:"
        time mc cp test-${size}mb.dat local/test-bucket/perf-${size}mb.dat
        echo "     다운로드 시간:"
        time mc cp local/test-bucket/perf-${size}mb.dat downloaded-${size}mb.dat
        rm -f test-${size}mb.dat downloaded-${size}mb.dat
    done
    
    # 다중 파일 업로드 테스트
    echo "2. 다중 파일 업로드 테스트..."
    echo "   - 10개의 1MB 파일 생성..."
    for i in {1..10}; do
        dd if=/dev/zero of=multi-${i}.dat bs=1M count=1 2>/dev/null
    done
    
    echo "   - 동시 업로드 시간 측정..."
    time mc cp multi-*.dat local/test-bucket/
    
    # 정리
    rm -f multi-*.dat large-file.dat
    
    echo ""
    echo -e "${GREEN}✅ Lab 5 완료${NC}"
    echo "성능 테스트가 완료되었습니다."
    read -p "계속하려면 Enter를 누르세요..."
}

lab_6_user_management() {
    echo -e "${GREEN}=== Lab 6: 사용자 및 권한 관리 ===${NC}"
    echo ""
    
    # 사용자 생성
    echo "1. 새 사용자 생성..."
    mc admin user add local testuser testpass123
    
    echo "2. 사용자 목록 확인..."
    mc admin user list local
    
    # 정책 생성
    echo "3. 읽기 전용 정책 생성..."
    cat > readonly-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::test-bucket/*",
        "arn:aws:s3:::test-bucket"
      ]
    }
  ]
}
EOF
    
    mc admin policy create local readonly readonly-policy.json
    
    # 정책 할당
    echo "4. 사용자에게 정책 할당..."
    mc admin policy attach local readonly --user testuser
    
    # 새 사용자로 테스트
    echo "5. 새 사용자 권한 테스트..."
    mc alias set testlocal http://localhost:9000 testuser testpass123
    
    echo "   - 읽기 권한 테스트 (성공해야 함)..."
    mc ls testlocal/test-bucket/
    
    echo "   - 쓰기 권한 테스트 (실패해야 함)..."
    echo "This should fail" > write-test.txt
    mc cp write-test.txt testlocal/test-bucket/ || echo "   ✅ 쓰기 권한이 올바르게 차단되었습니다."
    
    # 정리
    rm -f readonly-policy.json write-test.txt
    
    echo ""
    echo -e "${GREEN}✅ Lab 6 완료${NC}"
    echo "사용자 및 권한 관리 테스트가 완료되었습니다."
    read -p "계속하려면 Enter를 누르세요..."
}

cleanup_all() {
    echo -e "${RED}=== 전체 환경 정리 ===${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  이 작업은 모든 MinIO 리소스를 삭제합니다.${NC}"
    read -p "계속하시겠습니까? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "정리 작업 시작..."
        
        # 포트 포워딩 프로세스 종료
        pkill -f "kubectl port-forward.*minio" 2>/dev/null || true
        
        # Tenant 삭제
        kubectl delete tenant minio-tenant -n minio-tenant --ignore-not-found
        
        # 네임스페이스 삭제
        kubectl delete namespace minio-tenant --ignore-not-found
        kubectl delete namespace minio-operator --ignore-not-found
        
        # Operator 삭제
        kubectl delete -k "github.com/minio/operator?ref=v5.0.10" --ignore-not-found
        
        # 임시 파일 정리
        rm -f test-file.txt *.dat
        
        echo -e "${GREEN}✅ 정리 완료${NC}"
    else
        echo "정리 작업이 취소되었습니다."
    fi
}

# 메인 루프
while true; do
    show_menu
    read -p "선택 (0-9, h, q): " choice
    echo ""
    
    case $choice in
        0)
            lab_0_env_check
            ;;
        1)
            lab_1_operator_install
            ;;
        2)
            lab_2_tenant_deploy
            ;;
        3)
            lab_3_client_setup
            ;;
        4)
            lab_4_advanced_s3
            ;;
        5)
            lab_5_performance_test
            ;;
        6)
            lab_6_user_management
            ;;
        7)
            echo "Lab 7: 모니터링 설정 실행 중..."
            ./lab-07-monitoring.sh
            ;;
        8)
            echo "Lab 8: Helm Chart 실습 실행 중..."
            ./lab-08-helm-chart.sh
            ;;
        9)
            cleanup_all
            ;;
        h)
            show_help
            read -p "계속하려면 Enter를 누르세요..."
            ;;
        q)
            echo "실습을 종료합니다."
            # 백그라운드 프로세스 정리
            pkill -f "kubectl port-forward.*minio" 2>/dev/null || true
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 잘못된 선택입니다. 다시 선택해주세요.${NC}"
            read -p "계속하려면 Enter를 누르세요..."
            ;;
    esac
    
    echo ""
done
