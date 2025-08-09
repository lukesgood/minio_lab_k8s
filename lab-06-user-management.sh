#!/bin/bash

echo "=== Lab 6: 사용자 및 권한 관리 ==="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# MinIO Client 명령어 확인
MC_CMD="mc"
if ! command -v mc &> /dev/null; then
    if [ -f "./mc" ]; then
        MC_CMD="./mc"
    else
        echo -e "${RED}❌ MinIO Client가 설치되지 않았습니다.${NC}"
        echo "먼저 Lab 3을 실행하여 MinIO Client를 설치하세요."
        exit 1
    fi
fi

# 연결 확인
echo "1. MinIO 서버 연결 확인..."
if ! $MC_CMD admin info local &>/dev/null; then
    echo -e "${RED}❌ MinIO 서버에 연결할 수 없습니다.${NC}"
    echo "먼저 Lab 3을 실행하여 포트 포워딩을 설정하세요."
    exit 1
fi
echo -e "${GREEN}✅ MinIO 서버 연결 확인${NC}"

# 테스트용 버킷 생성
echo ""
echo "2. 테스트용 버킷 및 데이터 준비..."
$MC_CMD mb local/user-test-bucket 2>/dev/null || echo "버킷이 이미 존재합니다."
echo "Test data for user management" > user-test-file.txt
$MC_CMD cp user-test-file.txt local/user-test-bucket/
rm -f user-test-file.txt

# 사용자 생성
echo ""
echo "3. 새 사용자 생성..."
echo "   - testuser 사용자 생성..."
$MC_CMD admin user add local testuser testpass123

echo "   - readonly-user 사용자 생성..."
$MC_CMD admin user add local readonly-user readonly123

echo ""
echo "   - 사용자 목록 확인..."
$MC_CMD admin user list local

# 정책 생성
echo ""
echo "4. IAM 정책 생성..."

# 읽기 전용 정책
echo "   - 읽기 전용 정책 생성..."
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
        "arn:aws:s3:::user-test-bucket/*",
        "arn:aws:s3:::user-test-bucket"
      ]
    }
  ]
}
EOF

$MC_CMD admin policy create local readonly readonly-policy.json

# 읽기/쓰기 정책
echo "   - 읽기/쓰기 정책 생성..."
cat > readwrite-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::user-test-bucket/*",
        "arn:aws:s3:::user-test-bucket"
      ]
    }
  ]
}
EOF

$MC_CMD admin policy create local readwrite readwrite-policy.json

echo ""
echo "   - 정책 목록 확인..."
$MC_CMD admin policy list local

# 정책 할당
echo ""
echo "5. 사용자에게 정책 할당..."
echo "   - readonly-user에게 읽기 전용 정책 할당..."
$MC_CMD admin policy attach local readonly --user readonly-user

echo "   - testuser에게 읽기/쓰기 정책 할당..."
$MC_CMD admin policy attach local readwrite --user testuser

echo ""
echo "   - 사용자 정보 확인..."
echo "     readonly-user 정보:"
$MC_CMD admin user info local readonly-user

echo ""
echo "     testuser 정보:"
$MC_CMD admin user info local testuser

# 권한 테스트
echo ""
echo "6. 권한 테스트..."

# 읽기 전용 사용자 테스트
echo "   - 읽기 전용 사용자 테스트..."
$MC_CMD alias set readonly-local http://localhost:9000 readonly-user readonly123

echo "     읽기 권한 테스트 (성공해야 함):"
$MC_CMD ls readonly-local/user-test-bucket/

echo "     쓰기 권한 테스트 (실패해야 함):"
echo "This should fail" > write-test.txt
if $MC_CMD cp write-test.txt readonly-local/user-test-bucket/ 2>/dev/null; then
    echo -e "${RED}❌ 쓰기 권한이 차단되지 않았습니다!${NC}"
else
    echo -e "${GREEN}✅ 쓰기 권한이 올바르게 차단되었습니다.${NC}"
fi

# 읽기/쓰기 사용자 테스트
echo ""
echo "   - 읽기/쓰기 사용자 테스트..."
$MC_CMD alias set readwrite-local http://localhost:9000 testuser testpass123

echo "     읽기 권한 테스트 (성공해야 함):"
$MC_CMD ls readwrite-local/user-test-bucket/

echo "     쓰기 권한 테스트 (성공해야 함):"
echo "This should succeed" > write-success.txt
if $MC_CMD cp write-success.txt readwrite-local/user-test-bucket/; then
    echo -e "${GREEN}✅ 쓰기 권한이 올바르게 작동합니다.${NC}"
else
    echo -e "${RED}❌ 쓰기 권한이 작동하지 않습니다!${NC}"
fi

echo ""
echo "     업로드된 파일 확인:"
$MC_CMD ls readwrite-local/user-test-bucket/

# 버킷 정책 테스트
echo ""
echo "7. 버킷 정책 관리..."
echo "   - 현재 버킷 정책 확인..."
$MC_CMD policy get local/user-test-bucket

echo ""
echo "   - 버킷을 공개 읽기로 설정..."
$MC_CMD policy set public local/user-test-bucket

echo "   - 변경된 버킷 정책 확인..."
$MC_CMD policy get local/user-test-bucket

# 그룹 관리 (가능한 경우)
echo ""
echo "8. 고급 사용자 관리..."
echo "   - 사용자 상태 관리..."
echo "     사용자 비활성화:"
$MC_CMD admin user disable local readonly-user

echo "     사용자 목록 (비활성화 상태 확인):"
$MC_CMD admin user list local

echo "     사용자 재활성화:"
$MC_CMD admin user enable local readonly-user

# 정리
echo ""
echo "9. 테스트 리소스 정리..."
rm -f readonly-policy.json readwrite-policy.json write-test.txt write-success.txt

# 사용자 및 정책 정리 (선택사항)
echo ""
echo -e "${YELLOW}정리 옵션:${NC}"
read -p "테스트 사용자 및 정책을 삭제하시겠습니까? (y/N): " cleanup_confirm

if [[ $cleanup_confirm =~ ^[Yy]$ ]]; then
    echo "   - 사용자 삭제..."
    $MC_CMD admin user remove local testuser
    $MC_CMD admin user remove local readonly-user
    
    echo "   - 정책 삭제..."
    $MC_CMD admin policy remove local readonly
    $MC_CMD admin policy remove local readwrite
    
    echo "   - 별칭 제거..."
    $MC_CMD alias remove readonly-local
    $MC_CMD alias remove readwrite-local
    
    echo "   - 테스트 버킷 삭제..."
    $MC_CMD rm --recursive --force local/user-test-bucket/
    $MC_CMD rb local/user-test-bucket
    
    echo -e "${GREEN}✅ 테스트 리소스 정리 완료${NC}"
else
    echo "테스트 리소스가 보존되었습니다."
    echo "수동 정리 명령어:"
    echo "  $MC_CMD admin user remove local testuser"
    echo "  $MC_CMD admin user remove local readonly-user"
    echo "  $MC_CMD admin policy remove local readonly"
    echo "  $MC_CMD admin policy remove local readwrite"
fi

echo ""
echo -e "${GREEN}✅ Lab 6 완료${NC}"
echo "사용자 및 권한 관리 테스트가 완료되었습니다."
echo ""
echo -e "${BLUE}📋 학습 내용 요약:${NC}"
echo "- ✅ IAM 사용자 생성 및 관리"
echo "- ✅ 정책 기반 접근 제어 (PBAC)"
echo "- ✅ 읽기 전용 vs 읽기/쓰기 권한 테스트"
echo "- ✅ 버킷 정책 설정"
echo "- ✅ 사용자 상태 관리 (활성화/비활성화)"
echo ""
echo -e "${YELLOW}💡 보안 모범 사례:${NC}"
echo "- 최소 권한 원칙 적용"
echo "- 정기적인 사용자 권한 검토"
echo "- 강력한 비밀번호 정책 사용"
echo "- 불필요한 사용자 및 정책 정리"
