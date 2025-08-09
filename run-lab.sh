#!/bin/bash

echo "=== MinIO Kubernetes Lab 실행 가이드 ==="
echo ""

show_menu() {
    echo "실습 메뉴를 선택하세요:"
    echo "1) MinIO Operator 설치"
    echo "2) MinIO Tenant 배포"
    echo "3) MinIO Helm (Standalone) 설치"
    echo "4) MinIO Helm (Distributed) 설치"
    echo "5) MinIO Client 설정"
    echo "6) 성능 테스트 실행"
    echo "7) 모니터링 설정"
    echo "8) 전체 정리"
    echo "9) 종료"
    echo ""
}

cleanup_all() {
    echo "=== 전체 환경 정리 ==="
    kubectl delete namespace minio-operator --ignore-not-found
    kubectl delete namespace minio-tenant --ignore-not-found
    kubectl delete namespace minio-helm --ignore-not-found
    kubectl delete namespace minio-distributed --ignore-not-found
    helm uninstall minio-standalone -n minio-helm --ignore-not-found
    helm uninstall minio-distributed -n minio-distributed --ignore-not-found
    echo "정리 완료"
}

while true; do
    show_menu
    read -p "선택 (1-9): " choice
    
    case $choice in
        1)
            echo "MinIO Operator 설치 중..."
            chmod +x minio-operator-install.sh
            ./minio-operator-install.sh
            ;;
        2)
            echo "MinIO Tenant 배포 중..."
            chmod +x deploy-tenant.sh
            ./deploy-tenant.sh
            ;;
        3)
            echo "MinIO Helm (Standalone) 설치 중..."
            chmod +x minio-helm-install.sh
            ./minio-helm-install.sh
            ;;
        4)
            echo "MinIO Helm (Distributed) 설치 중..."
            chmod +x deploy-distributed.sh
            ./deploy-distributed.sh
            ;;
        5)
            echo "MinIO Client 설정..."
            chmod +x setup-mc.sh
            ./setup-mc.sh
            ;;
        6)
            echo "성능 테스트 실행..."
            chmod +x performance-test.sh
            ./performance-test.sh
            ;;
        7)
            echo "모니터링 설정..."
            kubectl apply -f monitoring-setup.yaml
            ;;
        8)
            cleanup_all
            ;;
        9)
            echo "실습을 종료합니다."
            exit 0
            ;;
        *)
            echo "잘못된 선택입니다. 1-9 사이의 숫자를 입력하세요."
            ;;
    esac
    
    echo ""
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
done
