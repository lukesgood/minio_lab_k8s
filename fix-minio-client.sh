#!/bin/bash

# MinIO Client 설치 및 연결 문제 해결 스크립트
# Lab 실행 전 또는 문제 발생 시 사용

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

echo "=== MinIO Client 설치 및 연결 문제 해결 ==="
echo ""

# 1. MinIO Client 설치 확인 및 설치
echo -e "${BLUE}1. MinIO Client 설치 확인${NC}"
echo ""

if command -v mc &> /dev/null; then
    print_success "MinIO Client가 이미 설치되어 있습니다"
    echo "현재 버전: $(mc --version)"
else
    print_warning "MinIO Client가 설치되어 있지 않습니다"
    echo ""
    echo "MinIO Client를 설치하시겠습니까? (y/n)"
    read -p "선택: " install_choice
    
    if [[ $install_choice =~ ^[Yy]$ ]]; then
        echo ""
        echo "MinIO Client 다운로드 중..."
        
        if curl -O https://dl.min.io/client/mc/release/linux-amd64/mc; then
            print_success "MinIO Client 다운로드 완료"
            
            echo "실행 권한 부여 중..."
            chmod +x mc
            
            echo "설치 위치 선택:"
            echo "1) /usr/local/bin/ (시스템 전체, sudo 필요)"
            echo "2) ~/bin/ (사용자 전용)"
            echo "3) 현재 디렉토리 (임시)"
            read -p "선택 (1-3): " location_choice
            
            case $location_choice in
                1)
                    if sudo mv mc /usr/local/bin/; then
                        print_success "MinIO Client를 /usr/local/bin/에 설치했습니다"
                    else
                        print_error "시스템 디렉토리에 설치 실패"
                        exit 1
                    fi
                    ;;
                2)
                    mkdir -p ~/bin
                    if mv mc ~/bin/; then
                        print_success "MinIO Client를 ~/bin/에 설치했습니다"
                        
                        # PATH에 ~/bin 추가
                        if ! echo $PATH | grep -q "$HOME/bin"; then
                            echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
                            export PATH=$PATH:~/bin
                            print_info "PATH에 ~/bin을 추가했습니다"
                        fi
                    else
                        print_error "사용자 디렉토리에 설치 실패"
                        exit 1
                    fi
                    ;;
                3)
                    print_warning "현재 디렉토리에 설치했습니다"
                    echo "./mc 명령어로 실행하거나 PATH를 설정하세요"
                    export PATH=$PATH:$(pwd)
                    ;;
                *)
                    print_error "잘못된 선택입니다"
                    exit 1
                    ;;
            esac
            
            echo ""
            echo "설치 확인:"
            mc --version
            print_success "MinIO Client 설치 완료"
        else
            print_error "MinIO Client 다운로드 실패"
            echo ""
            echo "해결 방법:"
            echo "1. 네트워크 연결 확인"
            echo "2. 방화벽 설정 확인"
            echo "3. 수동 다운로드: https://dl.min.io/client/mc/release/linux-amd64/mc"
            exit 1
        fi
    else
        print_error "MinIO Client 설치가 필요합니다"
        exit 1
    fi
fi

echo ""

# 2. MinIO 서버 연결 확인
echo -e "${BLUE}2. MinIO 서버 연결 확인${NC}"
echo ""

# 기존 연결 확인
if mc admin info local &> /dev/null; then
    print_success "MinIO 서버에 이미 연결되어 있습니다"
    echo ""
    echo "서버 정보:"
    mc admin info local
else
    print_warning "MinIO 서버에 연결되어 있지 않습니다"
    echo ""
    echo "MinIO 서버 연결을 설정하시겠습니까? (y/n)"
    read -p "선택: " connect_choice
    
    if [[ $connect_choice =~ ^[Yy]$ ]]; then
        echo ""
        echo "MinIO 서버 연결 설정:"
        echo ""
        
        # 기본값 제공
        echo "기본값을 사용하시겠습니까?"
        echo "URL: http://localhost:9000"
        echo "사용자명: admin"
        echo "비밀번호: password123"
        echo ""
        read -p "기본값 사용 (y/n): " default_choice
        
        if [[ $default_choice =~ ^[Yy]$ ]]; then
            minio_url="http://localhost:9000"
            username="admin"
            password="password123"
        else
            read -p "MinIO URL: " minio_url
            read -p "사용자명: " username
            read -s -p "비밀번호: " password
            echo ""
        fi
        
        echo ""
        echo "연결 설정 중..."
        
        if mc alias set local $minio_url $username $password; then
            print_success "MinIO 서버 연결 설정 완료"
            
            echo ""
            echo "연결 테스트 중..."
            if mc admin info local &> /dev/null; then
                print_success "MinIO 서버 연결 확인됨"
                echo ""
                echo "서버 정보:"
                mc admin info local
            else
                print_error "MinIO 서버 연결 실패"
                echo ""
                echo "문제 해결 방법:"
                echo "1. MinIO 서버가 실행 중인지 확인:"
                echo "   kubectl get pods -n minio-tenant"
                echo ""
                echo "2. 포트 포워딩 설정 확인:"
                echo "   kubectl port-forward svc/minio -n minio-tenant 9000:80 &"
                echo ""
                echo "3. 인증 정보 확인 (Lab 2에서 설정한 값)"
                echo ""
                exit 1
            fi
        else
            print_error "MinIO 서버 연결 설정 실패"
            exit 1
        fi
    else
        print_warning "MinIO 서버 연결이 필요합니다"
        echo ""
        echo "수동으로 연결하려면 다음 명령어를 사용하세요:"
        echo "mc alias set local http://localhost:9000 admin password123"
        exit 1
    fi
fi

echo ""

# 3. 포트 포워딩 확인
echo -e "${BLUE}3. 포트 포워딩 상태 확인${NC}"
echo ""

if netstat -tlnp 2>/dev/null | grep :9000 > /dev/null || ss -tlnp 2>/dev/null | grep :9000 > /dev/null; then
    print_success "포트 9000이 사용 중입니다 (포트 포워딩 활성)"
    
    # 포트 포워딩 프로세스 확인
    if pgrep -f "kubectl port-forward.*minio.*9000" > /dev/null; then
        print_success "MinIO 포트 포워딩이 실행 중입니다"
        echo "프로세스 ID: $(pgrep -f 'kubectl port-forward.*minio.*9000')"
    else
        print_warning "포트 9000은 사용 중이지만 kubectl port-forward가 아닐 수 있습니다"
    fi
else
    print_warning "포트 9000이 사용되지 않고 있습니다"
    echo ""
    echo "포트 포워딩을 설정하시겠습니까? (y/n)"
    read -p "선택: " port_choice
    
    if [[ $port_choice =~ ^[Yy]$ ]]; then
        echo ""
        echo "MinIO 서비스 확인 중..."
        
        if kubectl get svc minio -n minio-tenant &> /dev/null; then
            print_success "MinIO 서비스가 존재합니다"
            
            echo ""
            echo "포트 포워딩 시작 중..."
            echo "명령어: kubectl port-forward svc/minio -n minio-tenant 9000:80"
            
            # 백그라운드에서 포트 포워딩 시작
            kubectl port-forward svc/minio -n minio-tenant 9000:80 > /dev/null 2>&1 &
            PF_PID=$!
            
            # 잠시 대기 후 확인
            sleep 3
            
            if ps -p $PF_PID > /dev/null; then
                print_success "포트 포워딩이 시작되었습니다 (PID: $PF_PID)"
                echo ""
                echo "포트 포워딩을 중단하려면 다음 명령어를 사용하세요:"
                echo "kill $PF_PID"
            else
                print_error "포트 포워딩 시작 실패"
                echo ""
                echo "수동으로 포트 포워딩을 시작하세요:"
                echo "kubectl port-forward svc/minio -n minio-tenant 9000:80 &"
            fi
        else
            print_error "MinIO 서비스를 찾을 수 없습니다"
            echo ""
            echo "MinIO Tenant가 배포되어 있는지 확인하세요:"
            echo "kubectl get pods -n minio-tenant"
            echo "kubectl get svc -n minio-tenant"
        fi
    else
        print_info "포트 포워딩을 건너뜁니다"
    fi
fi

echo ""

# 4. 최종 연결 테스트
echo -e "${BLUE}4. 최종 연결 테스트${NC}"
echo ""

echo "MinIO 서버 최종 연결 테스트 중..."

if mc admin info local &> /dev/null; then
    print_success "✅ MinIO Client 설정이 완료되었습니다!"
    echo ""
    echo "이제 다음 Lab들을 실행할 수 있습니다:"
    echo "• ./lab-04-advanced-s3.sh"
    echo "• ./lab-05-performance-test.sh"
    echo "• ./lab-06-user-management.sh"
    echo ""
    echo "현재 연결 정보:"
    mc alias list local
else
    print_error "❌ MinIO 서버 연결에 문제가 있습니다"
    echo ""
    echo "문제 해결을 위한 체크리스트:"
    echo "1. ☐ MinIO Tenant Pod 실행 상태 확인"
    echo "   kubectl get pods -n minio-tenant"
    echo ""
    echo "2. ☐ MinIO 서비스 상태 확인"
    echo "   kubectl get svc -n minio-tenant"
    echo ""
    echo "3. ☐ 포트 포워딩 설정"
    echo "   kubectl port-forward svc/minio -n minio-tenant 9000:80 &"
    echo ""
    echo "4. ☐ 인증 정보 확인"
    echo "   Lab 2에서 설정한 관리자 계정 정보 확인"
    echo ""
    echo "5. ☐ 네트워크 연결 테스트"
    echo "   curl -I http://localhost:9000/minio/health/live"
fi

echo ""
echo "스크립트 실행 완료!"
