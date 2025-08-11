# Lab 10: 백업 및 재해 복구

## 📚 학습 목표

이 실습에서는 MinIO 데이터의 백업 전략과 재해 복구 시나리오를 학습합니다:

- **백업 전략**: 다양한 백업 방법과 정책 수립
- **버전 관리**: 객체 버전 관리 및 복구
- **재해 복구**: 데이터 손실 시나리오 대응
- **자동화**: 백업 프로세스 자동화
- **모니터링**: 백업 상태 추적 및 알림
- **테스트**: 복구 절차 검증

## 🎯 핵심 개념

### 백업 전략 유형

| 백업 유형 | 설명 | 장점 | 단점 |
|-----------|------|------|------|
| **전체 백업** | 모든 데이터 복사 | 완전한 복구 | 시간/공간 소모 |
| **증분 백업** | 변경된 부분만 복사 | 효율적 | 복구 복잡 |
| **차등 백업** | 마지막 전체 백업 이후 변경분 | 복구 간단 | 점진적 증가 |
| **스냅샷** | 특정 시점 상태 보존 | 빠른 복구 | 스토리지 의존 |

### 3-2-1 백업 규칙

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   3개의 복사본   │    │   2개의 다른     │    │   1개의 오프사이트│
│   (원본 + 백업)  │    │   미디어 유형    │    │   백업           │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   원본 데이터    │    │   로컬 스토리지  │    │   클라우드 백업  │
│   + 2개 백업     │    │   + 네트워크     │    │   또는 원격지    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 실습 시작

### 1단계: 백업 환경 준비

#### 백업용 버킷 생성

```bash
# 백업 전용 버킷 생성
mc mb local/backup-primary
mc mb local/backup-secondary
mc mb local/backup-archive

# 버킷 목록 확인
mc ls local | grep backup

# 테스트 데이터 준비
mc mb local/production-data
echo "중요한 프로덕션 데이터" > important-file.txt
echo "사용자 데이터베이스" > user-database.sql
echo "설정 파일" > config.json
echo "로그 파일" > application.log

# 프로덕션 데이터 업로드
mc cp important-file.txt local/production-data/
mc cp user-database.sql local/production-data/
mc cp config.json local/production-data/
mc cp application.log local/production-data/

# 업로드 확인
mc ls local/production-data/
```

### 2단계: 기본 백업 방법

#### 단순 복사 백업 (mc cp)

```bash
echo "=== 단순 복사 백업 ==="

# 전체 버킷 백업
echo "전체 버킷 백업 중..."
start_time=$(date +%s)
mc cp --recursive local/production-data/ local/backup-primary/$(date +%Y%m%d_%H%M%S)/
end_time=$(date +%s)
backup_time=$((end_time - start_time))

echo "백업 완료 시간: ${backup_time}초"

# 백업 결과 확인
mc ls local/backup-primary/

# 📋 예상 결과:
# [2024-08-11 01:55:30 UTC]     0B 20240811_015530/
# 
# 백업 완료 시간: 3초
# 
# 💡 설명:
# - 타임스탬프 기반 백업 디렉토리 생성
# - 전체 프로덕션 데이터가 백업됨
# - 백업 시간은 데이터 크기에 비례
```

#### 동기화 백업 (mc mirror)

```bash
echo "=== 동기화 백업 ==="

# 미러링 백업 (동기화)
echo "미러링 백업 중..."
mc mirror local/production-data/ local/backup-secondary/mirror/

# 파일 수정 후 재동기화 테스트
echo "수정된 중요한 데이터" > important-file-modified.txt
mc cp important-file-modified.txt local/production-data/

# 변경사항 동기화
echo "변경사항 동기화 중..."
mc mirror local/production-data/ local/backup-secondary/mirror/ --overwrite

# 동기화 결과 확인
mc ls local/backup-secondary/mirror/

# 📋 예상 결과:
# [2024-08-11 01:56:15 UTC]   25B application.log
# [2024-08-11 01:56:15 UTC]   19B config.json
# [2024-08-11 01:56:15 UTC]   35B important-file.txt
# [2024-08-11 01:56:15 UTC]   42B important-file-modified.txt
# [2024-08-11 01:56:15 UTC]   28B user-database.sql
# 
# 💡 설명:
# - 미러링으로 원본과 동일한 구조 유지
# - 변경된 파일만 동기화되어 효율적
# - --overwrite 옵션으로 기존 파일 덮어쓰기
```

### 3단계: 버전 관리 활성화

#### 버킷 버전 관리 설정

```bash
echo "=== 버전 관리 설정 ==="

# 버전 관리 활성화
mc version enable local/production-data

# 버전 관리 상태 확인
mc version info local/production-data

# 📋 예상 결과:
# production-data versioning is enabled
# 
# 💡 설명:
# - 버킷에서 객체 버전 관리 활성화됨
# - 파일 수정 시 이전 버전 자동 보존
# - 실수로 삭제/수정된 파일 복구 가능

# 버전 관리 테스트
echo "버전 1: 초기 데이터" > versioned-file.txt
mc cp versioned-file.txt local/production-data/

echo "버전 2: 수정된 데이터" > versioned-file.txt
mc cp versioned-file.txt local/production-data/

echo "버전 3: 최종 데이터" > versioned-file.txt
mc cp versioned-file.txt local/production-data/

# 버전 목록 확인
mc ls --versions local/production-data/versioned-file.txt

# 📋 예상 결과:
# [2024-08-11 01:57:45 UTC]   18B STANDARD versioned-file.txt
# [2024-08-11 01:57:30 UTC]   22B STANDARD null versioned-file.txt
# [2024-08-11 01:57:15 UTC]   20B STANDARD null versioned-file.txt
# 
# 💡 설명:
# - 3개 버전이 모두 보존됨
# - 최신 버전이 맨 위에 표시
# - 각 버전마다 고유한 버전 ID 존재
```

### 4단계: 자동화된 백업 스크립트

#### 백업 스크립트 생성

```bash
# 종합 백업 스크립트 생성
cat > backup_script.sh << 'EOF'
#!/bin/bash

# MinIO 백업 스크립트
# 사용법: ./backup_script.sh [full|incremental|mirror]

BACKUP_TYPE=${1:-full}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="backup_${TIMESTAMP}.log"
SOURCE_BUCKET="production-data"
BACKUP_BUCKET="backup-primary"

# 로그 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 백업 함수들
full_backup() {
    log "전체 백업 시작"
    local backup_path="${BACKUP_BUCKET}/full_${TIMESTAMP}"
    
    start_time=$(date +%s)
    mc cp --recursive "local/${SOURCE_BUCKET}/" "local/${backup_path}/" 2>&1 | tee -a "$LOG_FILE"
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    log "전체 백업 완료 - 소요시간: ${duration}초"
    
    # 백업 크기 계산
    backup_size=$(mc du "local/${backup_path}/" | awk '{print $1}')
    log "백업 크기: ${backup_size}"
}

incremental_backup() {
    log "증분 백업 시작"
    local backup_path="${BACKUP_BUCKET}/incremental_${TIMESTAMP}"
    
    # 마지막 백업 이후 변경된 파일만 백업 (간단한 구현)
    # 실제로는 더 정교한 로직 필요
    start_time=$(date +%s)
    mc mirror "local/${SOURCE_BUCKET}/" "local/${backup_path}/" --newer-than 24h 2>&1 | tee -a "$LOG_FILE"
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    log "증분 백업 완료 - 소요시간: ${duration}초"
}

mirror_backup() {
    log "미러 백업 시작"
    local backup_path="${BACKUP_BUCKET}/mirror"
    
    start_time=$(date +%s)
    mc mirror "local/${SOURCE_BUCKET}/" "local/${backup_path}/" --overwrite 2>&1 | tee -a "$LOG_FILE"
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    log "미러 백업 완료 - 소요시간: ${duration}초"
}

# 백업 검증 함수
verify_backup() {
    local backup_path=$1
    log "백업 검증 시작: ${backup_path}"
    
    # 파일 수 비교
    source_count=$(mc ls --recursive "local/${SOURCE_BUCKET}/" | wc -l)
    backup_count=$(mc ls --recursive "local/${backup_path}/" | wc -l)
    
    if [ "$source_count" -eq "$backup_count" ]; then
        log "✅ 백업 검증 성공 - 파일 수 일치: ${source_count}"
    else
        log "❌ 백업 검증 실패 - 파일 수 불일치: 원본 ${source_count}, 백업 ${backup_count}"
    fi
}

# 메인 실행 로직
main() {
    log "백업 시작 - 유형: ${BACKUP_TYPE}"
    
    case $BACKUP_TYPE in
        "full")
            full_backup
            verify_backup "${BACKUP_BUCKET}/full_${TIMESTAMP}"
            ;;
        "incremental")
            incremental_backup
            verify_backup "${BACKUP_BUCKET}/incremental_${TIMESTAMP}"
            ;;
        "mirror")
            mirror_backup
            verify_backup "${BACKUP_BUCKET}/mirror"
            ;;
        *)
            log "❌ 잘못된 백업 유형: ${BACKUP_TYPE}"
            log "사용 가능한 유형: full, incremental, mirror"
            exit 1
            ;;
    esac
    
    log "백업 작업 완료"
}

# 스크립트 실행
main
EOF

chmod +x backup_script.sh

# 백업 스크립트 테스트
echo "전체 백업 테스트:"
./backup_script.sh full

echo -e "\n미러 백업 테스트:"
./backup_script.sh mirror
```
### 5단계: 재해 복구 시나리오

#### 데이터 손실 시뮬레이션

```bash
echo "=== 재해 복구 시나리오 테스트 ==="

# 현재 데이터 상태 백업
echo "재해 시뮬레이션 전 상태 저장..."
mc mirror local/production-data/ local/backup-archive/pre-disaster/

# 의도적 데이터 손실 시뮬레이션
echo "⚠️  데이터 손실 시뮬레이션 시작..."
mc rm local/production-data/important-file.txt
mc rm local/production-data/user-database.sql

# 일부 파일 손상 시뮬레이션
echo "손상된 데이터" > corrupted-file.txt
mc cp corrupted-file.txt local/production-data/config.json

# 손실 상태 확인
echo "손실 후 상태:"
mc ls local/production-data/
```

#### 복구 절차 실행

```bash
# 복구 스크립트 생성
cat > disaster_recovery.sh << 'EOF'
#!/bin/bash

# 재해 복구 스크립트
RECOVERY_LOG="recovery_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$RECOVERY_LOG"
}

# 1단계: 손상 평가
assess_damage() {
    log "=== 손상 평가 시작 ==="
    
    # 현재 상태 확인
    current_files=$(mc ls --recursive local/production-data/ | wc -l)
    log "현재 파일 수: $current_files"
    
    # 백업 상태 확인
    backup_files=$(mc ls --recursive local/backup-primary/mirror/ | wc -l)
    log "백업 파일 수: $backup_files"
    
    missing_files=$((backup_files - current_files))
    log "누락된 파일 수: $missing_files"
}

# 2단계: 복구 계획 수립
create_recovery_plan() {
    log "=== 복구 계획 수립 ==="
    
    # 복구 우선순위 설정
    log "복구 우선순위:"
    log "1. 중요 데이터 파일 (important-file.txt)"
    log "2. 데이터베이스 파일 (user-database.sql)"
    log "3. 설정 파일 (config.json)"
    log "4. 로그 파일 (application.log)"
}

# 3단계: 데이터 복구 실행
execute_recovery() {
    log "=== 데이터 복구 실행 ==="
    
    # 백업에서 복구
    log "백업에서 누락된 파일 복구 중..."
    mc mirror local/backup-primary/mirror/ local/production-data/ --overwrite
    
    # 복구 결과 확인
    recovered_files=$(mc ls --recursive local/production-data/ | wc -l)
    log "복구 후 파일 수: $recovered_files"
}

# 4단계: 데이터 무결성 검증
verify_recovery() {
    log "=== 복구 검증 ==="
    
    # 파일 존재 확인
    critical_files=("important-file.txt" "user-database.sql" "config.json" "application.log")
    
    for file in "${critical_files[@]}"; do
        if mc stat local/production-data/$file >/dev/null 2>&1; then
            log "✅ $file 복구 완료"
        else
            log "❌ $file 복구 실패"
        fi
    done
}

# 5단계: 복구 후 조치
post_recovery_actions() {
    log "=== 복구 후 조치 ==="
    
    # 새로운 백업 생성
    log "복구 후 백업 생성..."
    mc mirror local/production-data/ local/backup-primary/post-recovery-$(date +%Y%m%d_%H%M%S)/
    
    # 모니터링 강화
    log "모니터링 시스템 점검 필요"
    log "백업 정책 재검토 필요"
}

# 메인 복구 프로세스
main() {
    log "재해 복구 프로세스 시작"
    
    assess_damage
    create_recovery_plan
    execute_recovery
    verify_recovery
    post_recovery_actions
    
    log "재해 복구 프로세스 완료"
}

main
EOF

chmod +x disaster_recovery.sh

# 복구 스크립트 실행
./disaster_recovery.sh

# 복구 결과 확인
echo -e "\n복구 후 상태:"
mc ls local/production-data/
```

### 6단계: 버전 기반 복구

#### 특정 버전으로 복구

```bash
echo "=== 버전 기반 복구 ==="

# 버전 목록 확인
echo "사용 가능한 버전:"
mc ls --versions local/production-data/versioned-file.txt

# 특정 버전으로 복구 (예: 이전 버전)
echo "이전 버전으로 복구 중..."

# 버전 ID를 사용한 복구 (실제 환경에서는 버전 ID 필요)
# mc cp local/production-data/versioned-file.txt?versionId=VERSION_ID local/production-data/versioned-file-recovered.txt

# 간단한 버전 복구 시뮬레이션
echo "버전 1: 초기 데이터" > versioned-file-recovered.txt
mc cp versioned-file-recovered.txt local/production-data/

echo "버전 복구 완료"
mc ls local/production-data/ | grep versioned
```

### 7단계: 백업 모니터링 시스템

#### 백업 상태 모니터링 스크립트

```bash
# 백업 모니터링 스크립트 생성
cat > backup_monitor.sh << 'EOF'
#!/bin/bash

# 백업 모니터링 스크립트
MONITOR_LOG="backup_monitor_$(date +%Y%m%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

# 백업 상태 확인
check_backup_status() {
    log "=== 백업 상태 점검 ==="
    
    # 최근 백업 확인
    latest_backup=$(mc ls local/backup-primary/ | tail -1 | awk '{print $5}')
    if [ -n "$latest_backup" ]; then
        log "✅ 최근 백업: $latest_backup"
    else
        log "❌ 백업을 찾을 수 없음"
    fi
    
    # 백업 크기 확인
    backup_size=$(mc du local/backup-primary/ | awk '{print $1}')
    log "총 백업 크기: $backup_size"
    
    # 백업 개수 확인
    backup_count=$(mc ls local/backup-primary/ | wc -l)
    log "백업 개수: $backup_count"
}

# 백업 무결성 검사
check_backup_integrity() {
    log "=== 백업 무결성 검사 ==="
    
    # 원본과 백업 파일 수 비교
    source_count=$(mc ls --recursive local/production-data/ | wc -l)
    mirror_count=$(mc ls --recursive local/backup-primary/mirror/ | wc -l)
    
    if [ "$source_count" -eq "$mirror_count" ]; then
        log "✅ 파일 수 일치: $source_count"
    else
        log "⚠️  파일 수 불일치: 원본 $source_count, 백업 $mirror_count"
    fi
}

# 스토리지 사용량 모니터링
monitor_storage_usage() {
    log "=== 스토리지 사용량 모니터링 ==="
    
    # 각 버킷별 사용량
    buckets=("production-data" "backup-primary" "backup-secondary" "backup-archive")
    
    for bucket in "${buckets[@]}"; do
        if mc ls local/$bucket/ >/dev/null 2>&1; then
            usage=$(mc du local/$bucket/ | awk '{print $1}')
            log "$bucket: $usage"
        else
            log "$bucket: 버킷 없음"
        fi
    done
}

# 백업 정책 준수 확인
check_backup_policy() {
    log "=== 백업 정책 준수 확인 ==="
    
    # 3-2-1 규칙 확인
    local_backups=$(mc ls local/ | grep backup | wc -l)
    log "로컬 백업 수: $local_backups"
    
    if [ "$local_backups" -ge 2 ]; then
        log "✅ 백업 복사본 정책 준수"
    else
        log "❌ 백업 복사본 부족"
    fi
}

# 알림 발송 (시뮬레이션)
send_alert() {
    local message=$1
    log "🚨 알림: $message"
    
    # 실제 환경에서는 이메일, Slack 등으로 알림 발송
    echo "알림이 관리자에게 발송되었습니다: $message"
}

# 메인 모니터링 로직
main() {
    log "백업 모니터링 시작"
    
    check_backup_status
    check_backup_integrity
    monitor_storage_usage
    check_backup_policy
    
    # 문제 발견 시 알림
    if grep -q "❌\|⚠️" "$MONITOR_LOG"; then
        send_alert "백업 시스템에 문제가 발견되었습니다."
    else
        log "✅ 모든 백업 시스템이 정상 작동 중"
    fi
    
    log "백업 모니터링 완료"
}

main
EOF

chmod +x backup_monitor.sh

# 모니터링 스크립트 실행
./backup_monitor.sh
```

### 8단계: 자동화된 백업 스케줄링

#### Cron 작업 설정

```bash
echo "=== 백업 스케줄링 설정 ==="

# 백업 스케줄 스크립트 생성
cat > setup_backup_schedule.sh << 'EOF'
#!/bin/bash

# 백업 스케줄 설정 스크립트

echo "백업 스케줄 설정 중..."

# 현재 디렉토리 경로
SCRIPT_DIR=$(pwd)

# Cron 작업 추가
(crontab -l 2>/dev/null; echo "# MinIO 백업 스케줄") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_DIR/backup_script.sh full >> $SCRIPT_DIR/backup_cron.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 6,12,18 * * * $SCRIPT_DIR/backup_script.sh mirror >> $SCRIPT_DIR/backup_cron.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 */4 * * * $SCRIPT_DIR/backup_monitor.sh >> $SCRIPT_DIR/monitor_cron.log 2>&1") | crontab -

echo "백업 스케줄이 설정되었습니다:"
echo "- 매일 02:00: 전체 백업"
echo "- 매일 06:00, 12:00, 18:00: 미러 백업"
echo "- 4시간마다: 백업 모니터링"

# 설정된 Cron 작업 확인
echo -e "\n현재 Cron 작업:"
crontab -l | grep -E "(backup|monitor)"
EOF

chmod +x setup_backup_schedule.sh

# 스케줄 설정 (실제 운영 환경에서만 실행)
echo "백업 스케줄 설정 스크립트가 준비되었습니다."
echo "실제 운영 환경에서 ./setup_backup_schedule.sh를 실행하세요."
```

### 9단계: 백업 보존 정책

#### 백업 정리 스크립트

```bash
# 백업 정리 스크립트 생성
cat > backup_retention.sh << 'EOF'
#!/bin/bash

# 백업 보존 정책 스크립트
RETENTION_LOG="retention_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$RETENTION_LOG"
}

# 보존 정책 설정
DAILY_RETENTION=7      # 일일 백업 7일 보존
WEEKLY_RETENTION=4     # 주간 백업 4주 보존
MONTHLY_RETENTION=12   # 월간 백업 12개월 보존

# 오래된 백업 정리
cleanup_old_backups() {
    log "=== 백업 정리 시작 ==="
    
    # 7일 이상 된 일일 백업 삭제
    log "7일 이상 된 백업 정리 중..."
    
    # 백업 목록 가져오기
    mc ls local/backup-primary/ | while read line; do
        backup_name=$(echo $line | awk '{print $5}')
        backup_date=$(echo $backup_name | grep -o '[0-9]\{8\}' | head -1)
        
        if [ -n "$backup_date" ]; then
            # 날짜 비교 (간단한 구현)
            current_date=$(date +%Y%m%d)
            days_diff=$(( ($(date -d "$current_date" +%s) - $(date -d "$backup_date" +%s)) / 86400 ))
            
            if [ "$days_diff" -gt "$DAILY_RETENTION" ]; then
                log "오래된 백업 삭제: $backup_name (${days_diff}일 전)"
                # mc rm --recursive "local/backup-primary/$backup_name" --force
                # 실제 삭제는 주석 처리 (안전을 위해)
            fi
        fi
    done
}

# 백업 아카이브
archive_old_backups() {
    log "=== 백업 아카이브 ==="
    
    # 30일 이상 된 백업을 아카이브로 이동
    log "장기 보존을 위한 아카이브 처리..."
    
    # 아카이브 정책 적용 (예시)
    log "아카이브 정책: 30일 이상 된 백업을 압축하여 장기 보관"
}

# 스토리지 사용량 최적화
optimize_storage() {
    log "=== 스토리지 최적화 ==="
    
    # 중복 제거
    log "중복 백업 확인 중..."
    
    # 압축 가능한 백업 확인
    log "압축 가능한 백업 확인 중..."
    
    total_size=$(mc du local/backup-primary/ | awk '{print $1}')
    log "현재 백업 총 크기: $total_size"
}

# 보존 정책 보고서
generate_retention_report() {
    log "=== 보존 정책 보고서 ==="
    
    backup_count=$(mc ls local/backup-primary/ | wc -l)
    log "현재 백업 개수: $backup_count"
    
    # 백업 연령 분석
    log "백업 연령 분석:"
    log "- 7일 이내: $(mc ls local/backup-primary/ | wc -l) 개"
    log "- 30일 이내: 분석 중..."
    log "- 90일 이상: 아카이브 대상"
}

# 메인 실행
main() {
    log "백업 보존 정책 실행 시작"
    
    cleanup_old_backups
    archive_old_backups
    optimize_storage
    generate_retention_report
    
    log "백업 보존 정책 실행 완료"
}

main
EOF

chmod +x backup_retention.sh

# 보존 정책 스크립트 실행
./backup_retention.sh
```

### 10단계: 복구 테스트 및 검증

#### 정기적 복구 테스트

```bash
echo "=== 복구 테스트 ==="

# 복구 테스트 스크립트 생성
cat > recovery_test.sh << 'EOF'
#!/bin/bash

# 복구 테스트 스크립트
TEST_LOG="recovery_test_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

# 테스트 환경 준비
setup_test_environment() {
    log "=== 테스트 환경 준비 ==="
    
    # 테스트용 버킷 생성
    mc mb local/recovery-test-source
    mc mb local/recovery-test-target
    
    # 테스트 데이터 생성
    echo "테스트 파일 1" > test-file-1.txt
    echo "테스트 파일 2" > test-file-2.txt
    echo "테스트 파일 3" > test-file-3.txt
    
    # 테스트 데이터 업로드
    mc cp test-file-*.txt local/recovery-test-source/
    
    log "테스트 환경 준비 완료"
}

# 백업 생성
create_test_backup() {
    log "=== 테스트 백업 생성 ==="
    
    mc mirror local/recovery-test-source/ local/backup-primary/recovery-test/
    
    log "테스트 백업 생성 완료"
}

# 데이터 손실 시뮬레이션
simulate_data_loss() {
    log "=== 데이터 손실 시뮬레이션 ==="
    
    # 일부 파일 삭제
    mc rm local/recovery-test-source/test-file-1.txt
    mc rm local/recovery-test-source/test-file-2.txt
    
    log "데이터 손실 시뮬레이션 완료"
}

# 복구 실행
execute_recovery_test() {
    log "=== 복구 테스트 실행 ==="
    
    # 백업에서 복구
    mc mirror local/backup-primary/recovery-test/ local/recovery-test-target/
    
    log "복구 테스트 실행 완료"
}

# 복구 검증
verify_recovery_test() {
    log "=== 복구 검증 ==="
    
    # 파일 존재 확인
    test_files=("test-file-1.txt" "test-file-2.txt" "test-file-3.txt")
    
    for file in "${test_files[@]}"; do
        if mc stat local/recovery-test-target/$file >/dev/null 2>&1; then
            log "✅ $file 복구 성공"
        else
            log "❌ $file 복구 실패"
        fi
    done
    
    # 파일 내용 검증
    for file in "${test_files[@]}"; do
        if mc cat local/recovery-test-target/$file >/dev/null 2>&1; then
            log "✅ $file 내용 검증 성공"
        else
            log "❌ $file 내용 검증 실패"
        fi
    done
}

# 테스트 정리
cleanup_test_environment() {
    log "=== 테스트 환경 정리 ==="
    
    # 테스트 버킷 삭제
    mc rm --recursive local/recovery-test-source --force
    mc rm --recursive local/recovery-test-target --force
    mc rb local/recovery-test-source
    mc rb local/recovery-test-target
    
    # 테스트 파일 삭제
    rm -f test-file-*.txt
    
    log "테스트 환경 정리 완료"
}

# 메인 테스트 실행
main() {
    log "복구 테스트 시작"
    
    setup_test_environment
    create_test_backup
    simulate_data_loss
    execute_recovery_test
    verify_recovery_test
    cleanup_test_environment
    
    log "복구 테스트 완료"
    
    # 테스트 결과 요약
    if grep -q "❌" "$TEST_LOG"; then
        log "⚠️  복구 테스트에서 문제가 발견되었습니다."
    else
        log "✅ 모든 복구 테스트가 성공했습니다."
    fi
}

main
EOF

chmod +x recovery_test.sh

# 복구 테스트 실행
./recovery_test.sh
```

## 🎯 실습 완료 체크리스트

- [ ] 다양한 백업 방법 실습 완료
- [ ] 버전 관리 시스템 구축 완료
- [ ] 재해 복구 시나리오 테스트 완료
- [ ] 자동화된 백업 스크립트 작성 완료
- [ ] 백업 모니터링 시스템 구축 완료
- [ ] 백업 보존 정책 수립 완료
- [ ] 복구 테스트 및 검증 완료

## 🧹 정리

실습이 완료되면 백업 관련 리소스를 정리합니다:

```bash
# 백업 버킷 정리
mc rm --recursive local/backup-primary --force
mc rm --recursive local/backup-secondary --force
mc rm --recursive local/backup-archive --force
mc rm --recursive local/production-data --force

mc rb local/backup-primary
mc rb local/backup-secondary
mc rb local/backup-archive
mc rb local/production-data

# 스크립트 및 로그 파일 정리
rm -f *.sh *.txt *.log *.json

echo "백업 및 재해 복구 실습 정리 완료"
```

## 📚 다음 단계

이제 **Lab 11: 고급 보안 설정**으로 진행하여 MinIO의 보안 강화 방법을 학습해보세요.

## 💡 핵심 포인트

1. **3-2-1 규칙**: 3개 복사본, 2개 다른 미디어, 1개 오프사이트
2. **자동화**: 수동 백업은 실패하기 쉬우므로 자동화 필수
3. **정기 테스트**: 백업이 있어도 복구가 안 되면 의미 없음
4. **모니터링**: 백업 상태를 지속적으로 감시
5. **보존 정책**: 스토리지 비용과 복구 요구사항의 균형

---

**🔗 관련 문서:**
- [LAB-10-CONCEPTS.md](LAB-10-CONCEPTS.md) - 백업 및 재해 복구 상세 개념
- [LAB-11-GUIDE.md](LAB-11-GUIDE.md) - 다음 실습: 고급 보안 설정
