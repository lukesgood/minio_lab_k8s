#!/bin/bash

# Lab 10: MinIO Backup and Disaster Recovery
# 학습 목표: MinIO 데이터 백업, 복구 전략, 재해 복구 시나리오 실습

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_concept() {
    echo -e "${CYAN}[CONCEPT]${NC} $1"
}

# 사용자 입력 대기 함수
wait_for_user() {
    echo -e "${YELLOW}계속하려면 Enter를 누르세요...${NC}"
    read -r
}

# 체크포인트 함수
checkpoint() {
    echo -e "\n${GREEN}=== 체크포인트: $1 ===${NC}"
    wait_for_user
}

# 실습 환경 확인
check_prerequisites() {
    log_step "실습 환경 사전 확인"
    
    log_concept "이 실습에서는 다음을 학습합니다:"
    echo "  • MinIO 데이터 백업 전략"
    echo "  • mc mirror를 활용한 실시간 동기화"
    echo "  • 버전 관리 및 객체 잠금"
    echo "  • 재해 복구 시나리오 실습"
    echo "  • 백업 자동화 스크립트 작성"
    echo ""
    
    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # MinIO Client 확인
    if ! command -v mc &> /dev/null; then
        log_error "MinIO Client (mc)가 설치되지 않았습니다."
        log_info "Lab 3을 먼저 완료해주세요."
        exit 1
    fi
    
    # MinIO 서비스 확인
    if ! kubectl get svc minio -n minio-tenant &> /dev/null; then
        log_error "MinIO 서비스가 실행되지 않았습니다."
        log_info "Lab 2를 먼저 완료해주세요."
        exit 1
    fi
    
    log_success "사전 요구사항 확인 완료"
    checkpoint "환경 확인 완료"
}

# MinIO 연결 확인 및 설정
setup_minio_connection() {
    log_step "MinIO 연결 설정 확인"
    
    log_concept "백업 실습을 위해 MinIO 연결을 확인합니다."
    echo "  • 기존 alias 확인"
    echo "  • 포트 포워딩 상태 확인"
    echo "  • 연결 테스트"
    echo ""
    
    # 포트 포워딩 확인
    if ! pgrep -f "kubectl port-forward.*minio.*9000" > /dev/null; then
        log_warning "MinIO API 포트 포워딩이 실행되지 않았습니다."
        log_info "포트 포워딩을 시작합니다..."
        kubectl port-forward svc/minio -n minio-tenant 9000:80 > /dev/null 2>&1 &
        sleep 3
    fi
    
    # MinIO alias 확인
    if mc alias list | grep -q "local"; then
        log_success "MinIO alias 'local' 확인됨"
    else
        log_warning "MinIO alias가 설정되지 않았습니다."
        log_info "alias를 설정합니다..."
        mc alias set local http://localhost:9000 admin password123
    fi
    
    # 연결 테스트
    if mc admin info local > /dev/null 2>&1; then
        log_success "MinIO 연결 테스트 성공"
    else
        log_error "MinIO 연결에 실패했습니다."
        log_info "Lab 3을 다시 확인해주세요."
        exit 1
    fi
    
# 백업 실습 데이터 준비
prepare_backup_data() {
    log_step "백업 실습용 데이터 준비"
    
    log_concept "백업 실습을 위한 다양한 유형의 데이터를 생성합니다:"
    echo "  • 텍스트 파일 (로그, 설정 파일 시뮬레이션)"
    echo "  • 바이너리 파일 (이미지, 문서 시뮬레이션)"
    echo "  • 대용량 파일 (데이터베이스 백업 시뮬레이션)"
    echo "  • 버전 관리가 필요한 파일"
    echo ""
    
    # 백업 실습용 디렉토리 생성
    mkdir -p backup-lab-data/{logs,configs,databases,documents,images}
    
    # 다양한 유형의 테스트 데이터 생성
    log_info "텍스트 파일 생성 중..."
    echo "Application started at $(date)" > backup-lab-data/logs/app.log
    echo "User login: admin at $(date)" >> backup-lab-data/logs/app.log
    echo "Database connection established" >> backup-lab-data/logs/app.log
    
    echo "server_name=production" > backup-lab-data/configs/app.conf
    echo "database_url=postgresql://localhost:5432/mydb" >> backup-lab-data/configs/app.conf
    echo "log_level=INFO" >> backup-lab-data/configs/app.conf
    
    log_info "바이너리 파일 생성 중..."
    dd if=/dev/urandom of=backup-lab-data/images/photo1.jpg bs=1M count=2 2>/dev/null
    dd if=/dev/urandom of=backup-lab-data/documents/report.pdf bs=1M count=3 2>/dev/null
    
    log_info "대용량 파일 생성 중..."
    dd if=/dev/zero of=backup-lab-data/databases/db_backup.sql bs=1M count=10 2>/dev/null
    
    # 버킷 생성 및 데이터 업로드
    log_info "백업 실습용 버킷 생성..."
    mc mb local/production-data 2>/dev/null || true
    mc mb local/backup-storage 2>/dev/null || true
    mc mb local/archive-storage 2>/dev/null || true
    
    log_info "프로덕션 데이터 업로드..."
    mc cp --recursive backup-lab-data/ local/production-data/
    
    log_success "백업 실습 데이터 준비 완료"
    
    # 업로드된 데이터 확인
    echo ""
    log_info "업로드된 데이터 확인:"
    mc ls --recursive local/production-data/
    
    checkpoint "백업 데이터 준비 완료"
}

# 기본 백업 전략 실습
basic_backup_strategies() {
    log_step "기본 백업 전략 실습"
    
    log_concept "MinIO에서 사용할 수 있는 주요 백업 전략들:"
    echo "  1. mc cp: 단순 복사 백업"
    echo "  2. mc mirror: 동기화 백업 (증분 백업)"
    echo "  3. mc sync: 양방향 동기화"
    echo "  4. 버전 관리: 객체 버전 히스토리 유지"
    echo ""
    
    log_info "=== 1. 단순 복사 백업 (mc cp) ==="
    log_concept "전체 데이터를 새로운 위치로 복사하는 가장 기본적인 백업 방법"
    
    echo "백업 명령어 실행:"
    echo "mc cp --recursive local/production-data/ local/backup-storage/backup-$(date +%Y%m%d-%H%M%S)/"
    
    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    mc cp --recursive local/production-data/ local/backup-storage/backup-${BACKUP_TIMESTAMP}/
    
    log_success "단순 복사 백업 완료"
    
    echo ""
    log_info "백업 결과 확인:"
    mc ls local/backup-storage/
    
    wait_for_user
    
    log_info "=== 2. 동기화 백업 (mc mirror) ==="
    log_concept "소스와 대상을 동기화하여 변경된 파일만 복사하는 효율적인 백업 방법"
    
    # 프로덕션 데이터에 변경사항 추가
    echo "New log entry at $(date)" >> backup-lab-data/logs/app.log
    mc cp backup-lab-data/logs/app.log local/production-data/logs/app.log
    
    echo "동기화 백업 명령어 실행:"
    echo "mc mirror local/production-data/ local/backup-storage/mirror-backup/"
    
    mc mirror local/production-data/ local/backup-storage/mirror-backup/
    
    log_success "동기화 백업 완료"
    
    echo ""
    log_info "동기화 결과 확인:"
    mc ls --recursive local/backup-storage/mirror-backup/
    
    checkpoint "기본 백업 전략 실습 완료"
}

# 버전 관리 및 객체 잠금 실습
versioning_and_locking() {
    log_step "버전 관리 및 객체 잠금 실습"
    
    log_concept "MinIO의 고급 데이터 보호 기능:"
    echo "  • 버전 관리: 객체의 여러 버전 유지"
    echo "  • 객체 잠금: 실수로 인한 삭제 방지"
    echo "  • 라이프사이클 정책: 자동 아카이빙"
    echo ""
    
    # 버전 관리 활성화
    log_info "=== 버전 관리 활성화 ==="
    log_concept "버전 관리를 통해 파일의 변경 히스토리를 추적할 수 있습니다"
    
    mc mb local/versioned-data 2>/dev/null || true
    mc version enable local/versioned-data
    
    log_success "버전 관리 활성화 완료"
    
    # 버전 관리 테스트
    log_info "버전 관리 테스트..."
    
    # 첫 번째 버전
    echo "Version 1 content" > test-versioned-file.txt
    mc cp test-versioned-file.txt local/versioned-data/
    
    # 두 번째 버전
    echo "Version 2 content - Updated!" > test-versioned-file.txt
    mc cp test-versioned-file.txt local/versioned-data/
    
    # 세 번째 버전
    echo "Version 3 content - Final update!" > test-versioned-file.txt
    mc cp test-versioned-file.txt local/versioned-data/
    
    log_info "파일 버전 히스토리 확인:"
    mc ls --versions local/versioned-data/
    
    log_success "버전 관리 테스트 완료"
    
# 재해 복구 시나리오 실습
disaster_recovery_scenarios() {
    log_step "재해 복구 시나리오 실습"
    
    log_concept "실제 운영 환경에서 발생할 수 있는 재해 상황과 복구 방법:"
    echo "  • 시나리오 1: 실수로 인한 파일 삭제"
    echo "  • 시나리오 2: 버킷 전체 손실"
    echo "  • 시나리오 3: 데이터 손상"
    echo "  • 시나리오 4: 전체 시스템 장애"
    echo ""
    
    log_info "=== 시나리오 1: 실수로 인한 파일 삭제 복구 ==="
    log_concept "버전 관리를 통한 삭제된 파일 복구"
    
    # 파일 삭제 시뮬레이션
    log_warning "중요한 파일을 실수로 삭제하는 상황을 시뮬레이션합니다..."
    mc rm local/versioned-data/test-versioned-file.txt
    
    log_info "파일 삭제 후 상태 확인:"
    mc ls local/versioned-data/ || log_warning "파일이 삭제되었습니다!"
    
    log_info "버전 히스토리에서 복구 가능한 버전 확인:"
    mc ls --versions local/versioned-data/
    
    # 최신 버전 복구
    log_info "최신 버전으로 파일 복구 중..."
    LATEST_VERSION=$(mc ls --versions local/versioned-data/ | grep test-versioned-file.txt | head -1 | awk '{print $4}')
    if [ ! -z "$LATEST_VERSION" ]; then
        mc cp --version-id "$LATEST_VERSION" local/versioned-data/test-versioned-file.txt local/versioned-data/test-versioned-file.txt
        log_success "파일 복구 완료!"
    else
        log_warning "복구할 버전을 찾을 수 없습니다."
    fi
    
    wait_for_user
    
    log_info "=== 시나리오 2: 버킷 전체 손실 복구 ==="
    log_concept "백업에서 전체 버킷 복구"
    
    # 테스트용 버킷 생성 및 데이터 추가
    mc mb local/test-production 2>/dev/null || true
    echo "Critical production data" > critical-data.txt
    mc cp critical-data.txt local/test-production/
    
    log_warning "프로덕션 버킷이 손실되는 상황을 시뮬레이션합니다..."
    mc rb --force local/test-production
    
    log_info "버킷 손실 확인:"
    mc ls local/ | grep test-production || log_warning "버킷이 완전히 삭제되었습니다!"
    
    log_info "백업에서 버킷 복구 중..."
    mc mb local/test-production-recovered
    mc mirror local/backup-storage/mirror-backup/ local/test-production-recovered/
    
    log_success "버킷 복구 완료!"
    log_info "복구된 데이터 확인:"
    mc ls --recursive local/test-production-recovered/
    
    checkpoint "재해 복구 시나리오 실습 완료"
}

# 백업 자동화 스크립트 생성
create_backup_automation() {
    log_step "백업 자동화 스크립트 생성"
    
    log_concept "운영 환경에서 사용할 수 있는 백업 자동화 스크립트:"
    echo "  • 일일 백업 스크립트"
    echo "  • 증분 백업 스크립트"
    echo "  • 백업 검증 스크립트"
    echo "  • 로그 및 알림 기능"
    echo ""
    
    # 일일 백업 스크립트 생성
    log_info "일일 백업 스크립트 생성 중..."
    
    cat > daily-backup.sh << 'EOF'
#!/bin/bash

# MinIO 일일 백업 스크립트
# 사용법: ./daily-backup.sh [source-bucket] [backup-bucket]

set -e

# 설정
SOURCE_BUCKET=${1:-"production-data"}
BACKUP_BUCKET=${2:-"backup-storage"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="backup-${TIMESTAMP}.log"

# 로깅 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 백업 실행
log "=== MinIO 일일 백업 시작 ==="
log "소스: local/$SOURCE_BUCKET"
log "대상: local/$BACKUP_BUCKET/daily-backup-$TIMESTAMP"

# 백업 실행
if mc mirror "local/$SOURCE_BUCKET/" "local/$BACKUP_BUCKET/daily-backup-$TIMESTAMP/"; then
    log "백업 성공적으로 완료"
    
    # 백업 검증
    SOURCE_COUNT=$(mc ls --recursive "local/$SOURCE_BUCKET/" | wc -l)
    BACKUP_COUNT=$(mc ls --recursive "local/$BACKUP_BUCKET/daily-backup-$TIMESTAMP/" | wc -l)
    
    log "소스 파일 수: $SOURCE_COUNT"
    log "백업 파일 수: $BACKUP_COUNT"
    
    if [ "$SOURCE_COUNT" -eq "$BACKUP_COUNT" ]; then
        log "백업 검증 성공"
        exit 0
    else
        log "백업 검증 실패 - 파일 수 불일치"
        exit 1
    fi
else
    log "백업 실패"
    exit 1
fi
EOF
    
    chmod +x daily-backup.sh
    log_success "일일 백업 스크립트 생성 완료: daily-backup.sh"
    
    # 증분 백업 스크립트 생성
    log_info "증분 백업 스크립트 생성 중..."
    
    cat > incremental-backup.sh << 'EOF'
#!/bin/bash

# MinIO 증분 백업 스크립트
# 변경된 파일만 백업하여 효율성 향상

set -e

SOURCE_BUCKET=${1:-"production-data"}
BACKUP_BUCKET=${2:-"backup-storage"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="incremental-backup-${TIMESTAMP}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== MinIO 증분 백업 시작 ==="

# 증분 백업 실행 (mirror는 자동으로 변경된 파일만 동기화)
if mc mirror --overwrite "local/$SOURCE_BUCKET/" "local/$BACKUP_BUCKET/incremental-backup/"; then
    log "증분 백업 완료"
    
    # 백업 통계
    TOTAL_SIZE=$(mc du "local/$BACKUP_BUCKET/incremental-backup/" | awk '{print $1}')
    log "총 백업 크기: $TOTAL_SIZE"
    
    exit 0
else
    log "증분 백업 실패"
    exit 1
fi
EOF
    
    chmod +x incremental-backup.sh
    log_success "증분 백업 스크립트 생성 완료: incremental-backup.sh"
    
    # 백업 스크립트 테스트
    log_info "백업 스크립트 테스트 실행..."
    
    log_info "일일 백업 스크립트 테스트:"
    ./daily-backup.sh production-data backup-storage
    
    log_info "증분 백업 스크립트 테스트:"
    ./incremental-backup.sh production-data backup-storage
    
    log_success "백업 자동화 스크립트 테스트 완료"
    
    checkpoint "백업 자동화 설정 완료"
}

# 백업 모니터링 및 알림
backup_monitoring() {
    log_step "백업 모니터링 및 알림 설정"
    
    log_concept "백업 시스템의 신뢰성을 위한 모니터링:"
    echo "  • 백업 상태 확인 스크립트"
    echo "  • 백업 무결성 검증"
    echo "  • 알림 시스템 (이메일, Slack 등)"
    echo "  • 백업 보고서 생성"
    echo ""
    
    # 백업 상태 확인 스크립트
    cat > backup-status.sh << 'EOF'
#!/bin/bash

# 백업 상태 확인 및 보고서 생성

BACKUP_BUCKET="backup-storage"
REPORT_FILE="backup-report-$(date +%Y%m%d).txt"

echo "=== MinIO 백업 상태 보고서 ===" > "$REPORT_FILE"
echo "생성 시간: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 백업 버킷 목록
echo "백업 버킷 목록:" >> "$REPORT_FILE"
mc ls "local/$BACKUP_BUCKET/" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 최신 백업 정보
echo "최신 백업 정보:" >> "$REPORT_FILE"
LATEST_BACKUP=$(mc ls "local/$BACKUP_BUCKET/" | grep daily-backup | tail -1 | awk '{print $5}')
if [ ! -z "$LATEST_BACKUP" ]; then
    echo "최신 백업: $LATEST_BACKUP" >> "$REPORT_FILE"
    mc ls --recursive "local/$BACKUP_BUCKET/$LATEST_BACKUP/" | wc -l | xargs echo "파일 수:" >> "$REPORT_FILE"
    mc du "local/$BACKUP_BUCKET/$LATEST_BACKUP/" | awk '{print "총 크기: " $1}' >> "$REPORT_FILE"
else
    echo "백업을 찾을 수 없습니다!" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "보고서 생성 완료: $REPORT_FILE"
cat "$REPORT_FILE"
EOF
    
    chmod +x backup-status.sh
    
    log_info "백업 상태 보고서 생성 중..."
    ./backup-status.sh
    
    log_success "백업 모니터링 스크립트 생성 완료"
    
# 실습 정리
cleanup_lab() {
    log_step "실습 환경 정리"
    
    log_concept "실습에서 생성된 리소스들을 정리합니다:"
    echo "  • 테스트 데이터 파일"
    echo "  • 백업 스크립트"
    echo "  • 임시 버킷 (선택적)"
    echo ""
    
    read -p "생성된 파일들을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "임시 파일 정리 중..."
        rm -rf backup-lab-data/
        rm -f test-versioned-file.txt critical-data.txt
        rm -f backup-*.log incremental-backup-*.log
        rm -f backup-report-*.txt
        log_success "임시 파일 정리 완료"
    fi
    
    read -p "테스트 버킷들을 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "테스트 버킷 정리 중..."
        mc rb --force local/versioned-data 2>/dev/null || true
        mc rb --force local/test-production-recovered 2>/dev/null || true
        log_success "테스트 버킷 정리 완료"
    fi
    
    log_info "백업 스크립트는 보존됩니다:"
    echo "  • daily-backup.sh"
    echo "  • incremental-backup.sh" 
    echo "  • backup-status.sh"
    echo ""
    log_info "이 스크립트들은 실제 운영 환경에서 활용할 수 있습니다."
    
    log_success "실습 정리 완료"
}

# 실습 요약 및 다음 단계
lab_summary() {
    log_step "Lab 10 실습 요약"
    
    echo -e "${GREEN}=== 학습 완료 내용 ===${NC}"
    echo "✅ MinIO 백업 전략 이해"
    echo "   • 단순 복사 백업 (mc cp)"
    echo "   • 동기화 백업 (mc mirror)"
    echo "   • 증분 백업 개념"
    echo ""
    echo "✅ 버전 관리 및 데이터 보호"
    echo "   • 객체 버전 관리 활성화"
    echo "   • 버전 히스토리 추적"
    echo "   • 삭제된 파일 복구"
    echo ""
    echo "✅ 재해 복구 시나리오"
    echo "   • 파일 삭제 복구"
    echo "   • 버킷 전체 복구"
    echo "   • 데이터 무결성 검증"
    echo ""
    echo "✅ 백업 자동화"
    echo "   • 일일 백업 스크립트"
    echo "   • 증분 백업 스크립트"
    echo "   • 백업 모니터링 도구"
    echo ""
    
    echo -e "${BLUE}=== 핵심 개념 정리 ===${NC}"
    echo "• 백업 전략: 복사 vs 동기화 vs 증분"
    echo "• 버전 관리: 데이터 변경 히스토리 추적"
    echo "• 재해 복구: 체계적인 복구 절차"
    echo "• 자동화: 스크립트를 통한 백업 자동화"
    echo "• 모니터링: 백업 상태 추적 및 검증"
    echo ""
    
    echo -e "${YELLOW}=== 실무 활용 팁 ===${NC}"
    echo "• 정기적인 백업 스케줄링 (cron 활용)"
    echo "• 백업 데이터의 정기적인 복구 테스트"
    echo "• 백업 보존 정책 수립 (3-2-1 백업 규칙)"
    echo "• 백업 암호화 및 접근 제어"
    echo "• 원격 백업 저장소 활용"
    echo ""
    
    echo -e "${PURPLE}=== 다음 단계 권장사항 ===${NC}"
    echo "• 실제 운영 환경에 백업 스크립트 적용"
    echo "• 백업 스케줄링 설정 (crontab)"
    echo "• 백업 알림 시스템 구축"
    echo "• 백업 성능 최적화"
    echo "• 다중 사이트 백업 전략 수립"
    echo ""
    
    log_success "Lab 10: Backup and Disaster Recovery 실습 완료!"
    echo ""
    echo "생성된 백업 스크립트들을 활용하여 실제 운영 환경에서"
    echo "안정적인 백업 시스템을 구축해보세요."
}

# 메인 함수
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Lab 10: MinIO Backup                     ║"
    echo "║                  and Disaster Recovery                       ║"
    echo "║                                                              ║"
    echo "║  학습 목표:                                                  ║"
    echo "║  • MinIO 데이터 백업 전략 이해                              ║"
    echo "║  • 버전 관리 및 객체 잠금 활용                              ║"
    echo "║  • 재해 복구 시나리오 실습                                  ║"
    echo "║  • 백업 자동화 스크립트 작성                                ║"
    echo "║                                                              ║"
    echo "║  예상 소요시간: 25-30분                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    wait_for_user
    
    # 실습 단계별 실행
    check_prerequisites
    setup_minio_connection
    prepare_backup_data
    basic_backup_strategies
    versioning_and_locking
    disaster_recovery_scenarios
    create_backup_automation
    backup_monitoring
    
    # 실습 완료
    lab_summary
    
    # 정리 옵션
    echo ""
    read -p "실습 환경을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_lab
    else
        log_info "실습 환경이 보존되었습니다."
        log_info "나중에 정리하려면 다음 명령어를 실행하세요:"
        echo "  ./lab-10-backup-recovery.sh cleanup"
    fi
}

# 스크립트 실행
if [ "$1" = "cleanup" ]; then
    cleanup_lab
else
    main
fi
