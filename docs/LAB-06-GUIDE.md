# Lab 6: 사용자 및 권한 관리

## 📚 학습 목표

이 실습에서는 MinIO의 IAM(Identity and Access Management) 시스템을 학습합니다:

- **IAM 사용자 생성**: 개별 사용자 계정 관리
- **정책 기반 접근 제어**: 세밀한 권한 설정
- **그룹 관리**: 사용자 그룹화 및 권한 상속
- **버킷 정책**: 리소스별 접근 제어
- **임시 자격 증명**: STS(Security Token Service) 활용
- **감사 로깅**: 접근 기록 및 보안 모니터링

## 🎯 핵심 개념

### MinIO IAM 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Root User     │    │   IAM Users     │    │   Service       │
│   (admin)       │    │   (개별 계정)    │    │   Accounts      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Full Access   │    │   Policy-based  │    │   Programmatic  │
│   권한          │    │   권한          │    │   Access        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 권한 모델

| 구분 | 설명 | 적용 범위 |
|------|------|-----------|
| **User Policy** | 사용자별 개별 정책 | 특정 사용자 |
| **Group Policy** | 그룹 공통 정책 | 그룹 멤버 전체 |
| **Bucket Policy** | 버킷별 접근 정책 | 특정 버킷/객체 |
| **Resource Policy** | 리소스별 정책 | 특정 리소스 |

## 🚀 실습 시작

### 1단계: 현재 권한 상태 확인

#### Root 사용자 정보 확인

```bash
# 현재 사용자 정보 확인
mc admin user info local admin

# 현재 정책 목록 확인
mc admin policy list local

# 기본 정책 내용 확인
mc admin policy info local readwrite
mc admin policy info local readonly
mc admin policy info local writeonly
```

#### 현재 버킷 및 객체 상태

```bash
# 기존 버킷 목록
mc ls local

# 테스트용 버킷 생성 (없는 경우)
mc mb local/user-test-bucket
mc mb local/admin-only-bucket
mc mb local/public-bucket

# 테스트 객체 업로드
echo "Admin test file" > admin-test.txt
echo "User test file" > user-test.txt
echo "Public test file" > public-test.txt

mc cp admin-test.txt local/admin-only-bucket/
mc cp user-test.txt local/user-test-bucket/
mc cp public-test.txt local/public-bucket/
```

### 2단계: IAM 사용자 생성

#### 개발자 사용자 생성

```bash
echo "=== 개발자 사용자 생성 ==="

# 개발자 사용자 생성
mc admin user add local developer DevPass123!

# 사용자 정보 확인
mc admin user info local developer

# 사용자 목록 확인
mc admin user list local
```

#### 읽기 전용 사용자 생성

```bash
echo "=== 읽기 전용 사용자 생성 ==="

# 읽기 전용 사용자 생성
mc admin user add local readonly-user ReadPass123!

# 사용자 상태 확인
mc admin user info local readonly-user
```

#### 백업 사용자 생성

```bash
echo "=== 백업 전용 사용자 생성 ==="

# 백업 사용자 생성
mc admin user add local backup-user BackupPass123!

# 사용자 정보 확인
mc admin user info local backup-user
```

### 3단계: 사용자 정의 정책 생성

#### 개발자 정책 생성

```bash
# 개발자 정책 파일 생성
cat > developer-policy.json << 'EOF'
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
        "arn:aws:s3:::user-test-bucket",
        "arn:aws:s3:::user-test-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::public-bucket",
        "arn:aws:s3:::public-bucket/*"
      ]
    }
  ]
}
EOF

# 정책 등록
mc admin policy add local developer-policy developer-policy.json

# 정책 확인
mc admin policy info local developer-policy
```

#### 백업 전용 정책 생성

```bash
# 백업 정책 파일 생성
cat > backup-policy.json << 'EOF'
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
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::backup-*/*"
      ]
    }
  ]
}
EOF

# 백업 정책 등록
mc admin policy add local backup-policy backup-policy.json

# 정책 내용 확인
mc admin policy info local backup-policy
```

### 4단계: 사용자에게 정책 할당

#### 정책 할당

```bash
echo "=== 사용자별 정책 할당 ==="

# 개발자에게 개발자 정책 할당
mc admin policy set local developer-policy user=developer

# 읽기 전용 사용자에게 readonly 정책 할당
mc admin policy set local readonly user=readonly-user

# 백업 사용자에게 백업 정책 할당
mc admin policy set local backup-policy user=backup-user

# 할당 결과 확인
echo "개발자 사용자 정책:"
mc admin user info local developer

echo "읽기 전용 사용자 정책:"
mc admin user info local readonly-user

echo "백업 사용자 정책:"
mc admin user info local backup-user
```

### 5단계: 권한 테스트

#### 개발자 사용자 권한 테스트

```bash
echo "=== 개발자 사용자 권한 테스트 ==="

# 개발자 사용자로 별칭 생성
mc alias set dev-user http://localhost:9000 developer DevPass123!

# 허용된 버킷 접근 테스트
echo "1. user-test-bucket 접근 테스트 (허용되어야 함):"
mc ls dev-user/user-test-bucket

echo "2. user-test-bucket에 파일 업로드 테스트 (허용되어야 함):"
echo "Developer uploaded file" > dev-upload.txt
mc cp dev-upload.txt dev-user/user-test-bucket/

echo "3. public-bucket 읽기 테스트 (허용되어야 함):"
mc ls dev-user/public-bucket

echo "4. admin-only-bucket 접근 테스트 (거부되어야 함):"
mc ls dev-user/admin-only-bucket 2>&1 || echo "접근 거부됨 (정상)"

echo "5. public-bucket에 쓰기 테스트 (거부되어야 함):"
mc cp dev-upload.txt dev-user/public-bucket/ 2>&1 || echo "쓰기 거부됨 (정상)"
```

#### 읽기 전용 사용자 권한 테스트

```bash
echo "=== 읽기 전용 사용자 권한 테스트 ==="

# 읽기 전용 사용자로 별칭 생성
mc alias set readonly-user-alias http://localhost:9000 readonly-user ReadPass123!

echo "1. 버킷 목록 조회 테스트 (허용되어야 함):"
mc ls readonly-user-alias

echo "2. 객체 다운로드 테스트 (허용되어야 함):"
mc cp readonly-user-alias/user-test-bucket/user-test.txt downloaded-by-readonly.txt

echo "3. 객체 업로드 테스트 (거부되어야 함):"
echo "Readonly user upload attempt" > readonly-upload.txt
mc cp readonly-upload.txt readonly-user-alias/user-test-bucket/ 2>&1 || echo "업로드 거부됨 (정상)"

echo "4. 객체 삭제 테스트 (거부되어야 함):"
mc rm readonly-user-alias/user-test-bucket/user-test.txt 2>&1 || echo "삭제 거부됨 (정상)"
```

#### 백업 사용자 권한 테스트

```bash
echo "=== 백업 사용자 권한 테스트 ==="

# 백업 사용자로 별칭 생성
mc alias set backup-user-alias http://localhost:9000 backup-user BackupPass123!

# 백업 전용 버킷 생성 (admin 권한으로)
mc mb local/backup-storage

echo "1. 모든 버킷 읽기 테스트 (허용되어야 함):"
mc ls backup-user-alias

echo "2. 기존 데이터 백업 테스트 (허용되어야 함):"
mc cp backup-user-alias/user-test-bucket/user-test.txt backup-downloaded.txt

echo "3. backup- 접두사 버킷에 업로드 테스트 (허용되어야 함):"
echo "Backup data" > backup-data.txt
mc cp backup-data.txt backup-user-alias/backup-storage/

echo "4. 일반 버킷에 업로드 테스트 (거부되어야 함):"
mc cp backup-data.txt backup-user-alias/user-test-bucket/ 2>&1 || echo "업로드 거부됨 (정상)"
```

### 6단계: 그룹 관리

#### 사용자 그룹 생성

```bash
echo "=== 사용자 그룹 생성 ==="

# 개발팀 그룹 생성
mc admin group add local developers developer

# 운영팀 그룹 생성
mc admin group add local operations backup-user

# 읽기 전용 그룹 생성
mc admin group add local viewers readonly-user

# 그룹 목록 확인
mc admin group list local

# 그룹 정보 확인
mc admin group info local developers
mc admin group info local operations
mc admin group info local viewers
```

#### 그룹 정책 생성 및 할당

```bash
# 개발팀 그룹 정책 생성
cat > dev-team-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::dev-*",
        "arn:aws:s3:::dev-*/*",
        "arn:aws:s3:::test-*",
        "arn:aws:s3:::test-*/*"
      ]
    }
  ]
}
EOF

# 그룹 정책 등록
mc admin policy add local dev-team-policy dev-team-policy.json

# 그룹에 정책 할당
mc admin policy set local dev-team-policy group=developers

# 그룹 정책 확인
mc admin group info local developers
```

### 7단계: 버킷 정책 설정

#### 공개 읽기 버킷 정책

```bash
echo "=== 버킷 정책 설정 ==="

# 공개 읽기 정책 생성
cat > public-read-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::public-bucket/*"
      ]
    }
  ]
}
EOF

# 버킷 정책 적용
mc policy set-json public-read-policy.json local/public-bucket

# 버킷 정책 확인
mc policy get local/public-bucket
```

#### 특정 사용자만 접근 가능한 버킷 정책

```bash
# 개발자 전용 버킷 정책 생성
cat > developer-only-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam:::user/developer"
        ]
      },
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::user-test-bucket",
        "arn:aws:s3:::user-test-bucket/*"
      ]
    }
  ]
}
EOF

# 버킷 정책 적용
mc policy set-json developer-only-policy.json local/user-test-bucket

# 정책 확인
mc policy get local/user-test-bucket
```

### 8단계: 임시 자격 증명 (STS) 활용

#### STS 토큰 생성

```bash
echo "=== STS 임시 자격 증명 테스트 ==="

# STS 설정 확인
mc admin config get local identity_openid

# 임시 자격 증명 생성 (개발자 사용자로)
echo "임시 자격 증명 생성 중..."

# 개발자 사용자의 임시 토큰 생성 (실제로는 STS API 사용)
# 여기서는 개념적 설명을 위한 예시
echo "STS 토큰 생성은 다음과 같은 방식으로 작동합니다:"
echo "1. 사용자 인증"
echo "2. 임시 자격 증명 발급 (AccessKey, SecretKey, SessionToken)"
echo "3. 제한된 시간 동안 유효한 토큰 사용"
```

### 9단계: 감사 로깅 및 모니터링

#### 접근 로그 확인

```bash
echo "=== 접근 로그 및 감사 ==="

# MinIO 서버 로그 확인
kubectl logs -n minio-tenant -l app=minio --tail=50

# 실시간 API 호출 추적
echo "실시간 API 추적을 시작합니다..."
echo "다른 터미널에서 다음 명령을 실행하세요:"
echo "mc admin trace local --verbose"

# 테스트 활동 생성
echo "테스트 활동 생성 중..."
mc ls dev-user/user-test-bucket
mc cp dev-upload.txt dev-user/user-test-bucket/audit-test.txt
mc rm dev-user/user-test-bucket/audit-test.txt
```

#### 사용자 활동 모니터링

```bash
# 사용자별 활동 통계
echo "=== 사용자 활동 통계 ==="

# 현재 활성 세션 확인
mc admin user list local

# 정책 사용 현황
mc admin policy list local

# 그룹 멤버십 현황
mc admin group list local
```

### 10단계: 보안 강화 설정

#### 비밀번호 정책 강화

```bash
echo "=== 보안 강화 설정 ==="

# 강력한 비밀번호로 사용자 생성
mc admin user add local secure-user 'SecureP@ssw0rd123!'

# 사용자 상태 비활성화/활성화 테스트
echo "사용자 비활성화:"
mc admin user disable local secure-user

echo "사용자 상태 확인:"
mc admin user info local secure-user

echo "사용자 재활성화:"
mc admin user enable local secure-user
```

#### 접근 제한 정책

```bash
# IP 기반 접근 제한 정책 생성
cat > ip-restricted-policy.json << 'EOF'
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
        "arn:aws:s3:::user-test-bucket",
        "arn:aws:s3:::user-test-bucket/*"
      ],
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "127.0.0.1/32",
            "10.0.0.0/8"
          ]
        }
      }
    }
  ]
}
EOF

# IP 제한 정책 등록
mc admin policy add local ip-restricted-policy ip-restricted-policy.json

# 정책 내용 확인
mc admin policy info local ip-restricted-policy
```

### 11단계: 권한 관리 자동화

#### 사용자 관리 스크립트

```bash
# 사용자 관리 자동화 스크립트 생성
cat > user_management.sh << 'EOF'
#!/bin/bash

# 사용자 생성 함수
create_user() {
    local username=$1
    local password=$2
    local policy=$3
    
    echo "사용자 생성: $username"
    mc admin user add local "$username" "$password"
    
    if [ -n "$policy" ]; then
        echo "정책 할당: $policy"
        mc admin policy set local "$policy" user="$username"
    fi
    
    echo "사용자 $username 생성 완료"
    echo "---"
}

# 배치 사용자 생성
echo "=== 배치 사용자 생성 ==="

create_user "analyst1" "AnalystPass123!" "readonly"
create_user "analyst2" "AnalystPass123!" "readonly"
create_user "dev1" "DevPass123!" "developer-policy"
create_user "dev2" "DevPass123!" "developer-policy"

# 생성된 사용자 목록 확인
echo "=== 생성된 사용자 목록 ==="
mc admin user list local
EOF

chmod +x user_management.sh
./user_management.sh
```

### 12단계: 결과 분석 및 정리

#### 권한 테스트 결과 요약

```bash
echo "=== 권한 관리 실습 결과 요약 ==="

echo "1. 생성된 사용자:"
mc admin user list local

echo -e "\n2. 등록된 정책:"
mc admin policy list local

echo -e "\n3. 생성된 그룹:"
mc admin group list local

echo -e "\n4. 버킷별 정책:"
for bucket in user-test-bucket public-bucket admin-only-bucket; do
    echo "  - $bucket:"
    mc policy get local/$bucket 2>/dev/null || echo "    기본 정책 사용"
done

echo -e "\n5. 권한 테스트 결과:"
echo "  ✅ 개발자: user-test-bucket 읽기/쓰기 가능"
echo "  ✅ 읽기 전용: 모든 버킷 읽기만 가능"
echo "  ✅ 백업 사용자: 읽기 + backup-* 버킷 쓰기 가능"
echo "  ✅ 그룹 정책: 정상 작동"
echo "  ✅ 버킷 정책: 정상 적용"
```

## 🎯 실습 완료 체크리스트

- [ ] IAM 사용자 생성 및 관리
- [ ] 사용자 정의 정책 생성 및 적용
- [ ] 그룹 기반 권한 관리
- [ ] 버킷 정책 설정 및 테스트
- [ ] 권한 테스트 및 검증
- [ ] 보안 강화 설정 적용
- [ ] 감사 로깅 확인
- [ ] 사용자 관리 자동화

## 🧹 정리

실습이 완료되면 테스트 사용자와 정책을 정리합니다:

```bash
# 테스트 사용자 삭제
mc admin user remove local developer
mc admin user remove local readonly-user
mc admin user remove local backup-user
mc admin user remove local secure-user
mc admin user remove local analyst1
mc admin user remove local analyst2
mc admin user remove local dev1
mc admin user remove local dev2

# 테스트 정책 삭제
mc admin policy remove local developer-policy
mc admin policy remove local backup-policy
mc admin policy remove local dev-team-policy
mc admin policy remove local ip-restricted-policy

# 테스트 그룹 삭제
mc admin group remove local developers
mc admin group remove local operations
mc admin group remove local viewers

# 테스트 파일 정리
rm -f *.txt *.json user_management.sh

# 테스트 버킷 정리 (선택사항)
mc rm --recursive local/user-test-bucket --force
mc rm --recursive local/admin-only-bucket --force
mc rm --recursive local/public-bucket --force
mc rm --recursive local/backup-storage --force
mc rb local/user-test-bucket
mc rb local/admin-only-bucket
mc rb local/public-bucket
mc rb local/backup-storage
```

## 📚 다음 단계

이제 **Lab 7: 모니터링 설정**으로 진행하여 MinIO 클러스터의 모니터링 시스템을 구축해보세요.

## 💡 핵심 포인트

1. **최소 권한 원칙**: 사용자에게 필요한 최소한의 권한만 부여
2. **정책 기반 제어**: JSON 정책을 통한 세밀한 권한 설정
3. **그룹 활용**: 유사한 권한을 가진 사용자들의 효율적 관리
4. **버킷 정책**: 리소스 레벨에서의 접근 제어
5. **정기적인 권한 검토**: 보안 유지를 위한 지속적인 관리

---

**🔗 관련 문서:**
- [LAB-06-CONCEPTS.md](LAB-06-CONCEPTS.md) - 사용자 및 권한 관리 상세 개념 (예정)
- [LAB-07-GUIDE.md](LAB-07-GUIDE.md) - 다음 실습: 모니터링 설정
