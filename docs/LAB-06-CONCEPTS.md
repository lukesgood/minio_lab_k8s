# Lab 6 핵심 개념: MinIO IAM 및 권한 관리

## 개요

Lab 6에서는 MinIO의 Identity and Access Management (IAM) 시스템을 학습합니다. 사용자 생성, 정책 기반 접근 제어, 그룹 관리 등을 통해 엔터프라이즈급 보안 시스템을 구축하는 방법을 이해합니다.

## 핵심 개념

### 1. MinIO IAM 시스템 구조

MinIO IAM은 AWS IAM과 호환되는 정책 기반 접근 제어 시스템입니다.

#### 구성 요소

```
MinIO IAM 시스템
├── Root User (관리자)
│   ├── 모든 권한 보유
│   └── 시스템 관리 전담
├── IAM Users (일반 사용자)
│   ├── 제한된 권한
│   └── 액세스 키 기반 인증
├── Groups (그룹)
│   ├── 사용자 집합
│   └── 권한 일괄 관리
├── Policies (정책)
│   ├── JSON 기반 권한 정의
│   └── 세밀한 접근 제어
└── Access Keys (액세스 키)
    ├── 프로그래밍 방식 접근
    └── Access Key ID + Secret Key
```

#### 권한 상속 구조

```
Root User (최고 권한)
    ↓
IAM User (기본 권한 없음)
    ↓
+ User Policy (사용자별 정책)
    ↓
+ Group Policy (그룹 정책)
    ↓
= 최종 권한 (정책들의 합집합)
```

### 2. 정책 기반 접근 제어 (PBAC)

#### Policy-Based Access Control 원리

MinIO는 JSON 형식의 정책을 사용하여 세밀한 권한 제어를 제공합니다.

**기본 구조:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow|Deny",
            "Action": ["s3:GetObject", "s3:PutObject"],
            "Resource": ["arn:aws:s3:::bucket/*"],
            "Condition": {
                "StringEquals": {
                    "s3:prefix": ["documents/"]
                }
            }
        }
    ]
}
```

#### 정책 구성 요소

1. **Version**: 정책 언어 버전 (항상 "2012-10-17")
2. **Statement**: 권한 규칙 배열
3. **Effect**: Allow (허용) 또는 Deny (거부)
4. **Action**: 허용/거부할 작업 목록
5. **Resource**: 대상 리소스 (버킷, 객체)
6. **Condition**: 조건부 접근 제어 (선택사항)

#### 주요 Actions

**버킷 관리:**
- `s3:CreateBucket`: 버킷 생성
- `s3:DeleteBucket`: 버킷 삭제
- `s3:ListBucket`: 버킷 내용 조회
- `s3:GetBucketLocation`: 버킷 위치 조회

**객체 관리:**
- `s3:GetObject`: 객체 다운로드
- `s3:PutObject`: 객체 업로드
- `s3:DeleteObject`: 객체 삭제
- `s3:ListMultipartUploadParts`: 멀티파트 업로드 조회

**관리 작업:**
- `admin:*`: 모든 관리 작업
- `admin:ServerInfo`: 서버 정보 조회
- `admin:UserList`: 사용자 목록 조회

#### Resource ARN 형식

Amazon Resource Name (ARN) 형식을 사용합니다:

```
arn:aws:s3:::bucket-name           # 버킷 자체
arn:aws:s3:::bucket-name/*         # 버킷 내 모든 객체
arn:aws:s3:::bucket-name/prefix/*  # 특정 프리픽스 객체들
arn:aws:s3:::*                     # 모든 버킷
```

### 3. 사용자 관리

#### 사용자 생성 및 관리

```bash
# 사용자 생성
mc admin user add local username password

# 사용자 정보 조회
mc admin user info local username

# 사용자 비활성화
mc admin user disable local username

# 사용자 삭제
mc admin user remove local username
```

#### 액세스 키 관리

각 사용자는 고유한 액세스 키 쌍을 가집니다:
- **Access Key ID**: 공개 식별자
- **Secret Access Key**: 비밀 키

**보안 모범 사례:**
- 정기적인 키 로테이션 (3-6개월)
- 최소 권한 원칙 적용
- 키 노출 방지 및 안전한 저장
- 사용하지 않는 키 즉시 삭제

#### 사용자 상태 관리

```bash
# 사용자 활성화/비활성화
mc admin user enable local username
mc admin user disable local username

# 사용자 목록 조회
mc admin user list local

# 사용자별 정책 확인
mc admin user info local username
```

### 4. 그룹 기반 권한 관리

#### 그룹의 장점

1. **효율적 관리**: 여러 사용자에게 동일한 권한 일괄 적용
2. **유지보수성**: 정책 변경 시 그룹만 수정
3. **확장성**: 새 사용자를 그룹에 추가만 하면 됨
4. **역할 기반**: 조직 구조에 맞는 권한 체계

#### 그룹 관리 명령어

```bash
# 그룹 생성
mc admin group add local groupname

# 그룹에 사용자 추가
mc admin group add local groupname username

# 그룹에서 사용자 제거
mc admin group remove local groupname username

# 그룹 정보 조회
mc admin group info local groupname

# 그룹 목록 조회
mc admin group list local
```

#### 그룹 정책 적용

```bash
# 그룹에 정책 적용
mc admin policy set local policyname group=groupname

# 그룹 정책 확인
mc admin group info local groupname
```

### 5. 정책 설계 패턴

#### 역할 기반 정책 설계

**1. 읽기 전용 사용자 (Read-Only User)**
```json
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
                "arn:aws:s3:::public-*",
                "arn:aws:s3:::public-*/*"
            ]
        }
    ]
}
```

**2. 개발자 (Developer)**
```json
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
                "arn:aws:s3:::dev-*",
                "arn:aws:s3:::dev-*/*"
            ]
        },
        {
            "Effect": "Deny",
            "Action": [
                "s3:DeleteBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*"
            ]
        }
    ]
}
```

**3. 관리자 (Administrator)**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::*"
            ]
        },
        {
            "Effect": "Deny",
            "Action": [
                "admin:UserAdd",
                "admin:UserRemove"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

#### 조건부 접근 제어

**IP 주소 기반 제한:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": ["arn:aws:s3:::*"],
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": ["192.168.1.0/24", "10.0.0.0/8"]
                }
            }
        }
    ]
}
```

**시간 기반 제한:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": ["arn:aws:s3:::*"],
            "Condition": {
                "DateGreaterThan": {
                    "aws:CurrentTime": "2024-01-01T00:00:00Z"
                },
                "DateLessThan": {
                    "aws:CurrentTime": "2024-12-31T23:59:59Z"
                }
            }
        }
    ]
}
```

**MFA 요구:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:DeleteObject"],
            "Resource": ["arn:aws:s3:::critical-data/*"],
            "Condition": {
                "Bool": {
                    "aws:MultiFactorAuthPresent": "true"
                }
            }
        }
    ]
}
```

### 6. 보안 모범 사례

#### 최소 권한 원칙 (Principle of Least Privilege)

사용자에게 업무 수행에 필요한 최소한의 권한만 부여합니다.

**구현 방법:**
1. 기본적으로 모든 권한 거부
2. 필요한 권한만 명시적으로 허용
3. 정기적인 권한 검토 및 정리
4. 임시 권한은 만료 시간 설정

#### 명시적 거부 우선 (Explicit Deny)

Allow와 Deny가 충돌할 때 Deny가 우선합니다.

**예시:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": ["arn:aws:s3:::*"]
        },
        {
            "Effect": "Deny",
            "Action": ["s3:DeleteBucket"],
            "Resource": ["arn:aws:s3:::critical-*"]
        }
    ]
}
```
→ critical-* 버킷은 삭제할 수 없음

#### 정책 검증 및 테스트

**정책 문법 검증:**
```bash
# JSON 문법 검증
jq empty policy.json

# 정책 등록 테스트
mc admin policy add local test-policy policy.json
```

**권한 테스트:**
```bash
# 사용자별 연결 설정
mc alias set user-test http://localhost:9000 username password

# 권한 테스트
mc ls user-test/bucket/  # 읽기 권한 테스트
mc cp file.txt user-test/bucket/  # 쓰기 권한 테스트
```

#### 감사 및 모니터링

**사용자 활동 로깅:**
```bash
# 실시간 API 호출 추적
mc admin trace local

# 사용자별 활동 로그
mc admin logs local | grep username
```

**정기적인 권한 검토:**
- 월별 사용자 목록 검토
- 분기별 정책 유효성 검증
- 연간 전체 권한 체계 재평가

### 7. 실제 시나리오별 구현

#### 시나리오 1: 부서별 데이터 격리

**요구사항:**
- 각 부서는 자신의 데이터만 접근
- 공통 데이터는 모든 부서가 읽기 가능
- 관리자는 모든 데이터 접근 가능

**구현:**
```bash
# 부서별 그룹 생성
mc admin group add local engineering
mc admin group add local marketing
mc admin group add local finance

# 부서별 정책 생성
cat > engineering-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": [
                "arn:aws:s3:::engineering-*",
                "arn:aws:s3:::engineering-*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:ListBucket"],
            "Resource": [
                "arn:aws:s3:::common-*",
                "arn:aws:s3:::common-*/*"
            ]
        }
    ]
}
EOF

# 정책 적용
mc admin policy add local engineering-policy engineering-policy.json
mc admin policy set local engineering-policy group=engineering
```

#### 시나리오 2: 임시 권한 부여

**요구사항:**
- 외부 컨설턴트에게 특정 프로젝트 데이터만 접근 허용
- 프로젝트 종료 후 자동으로 권한 제거
- 다운로드만 가능, 수정/삭제 불가

**구현:**
```json
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
                "arn:aws:s3:::project-alpha",
                "arn:aws:s3:::project-alpha/*"
            ],
            "Condition": {
                "DateLessThan": {
                    "aws:CurrentTime": "2024-06-30T23:59:59Z"
                }
            }
        }
    ]
}
```

#### 시나리오 3: 계층적 권한 구조

**요구사항:**
- 팀장: 팀 데이터 전체 관리
- 팀원: 자신의 폴더만 관리
- 인턴: 읽기 전용 접근

**구현:**
```bash
# 계층별 그룹 생성
mc admin group add local team-leaders
mc admin group add local team-members
mc admin group add local interns

# 팀장 정책
cat > team-leader-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": [
                "arn:aws:s3:::team-data",
                "arn:aws:s3:::team-data/*"
            ]
        }
    ]
}
EOF

# 팀원 정책 (사용자명 기반 폴더 접근)
cat > team-member-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": [
                "arn:aws:s3:::team-data/\${aws:username}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::team-data"],
            "Condition": {
                "StringLike": {
                    "s3:prefix": ["\${aws:username}/*"]
                }
            }
        }
    ]
}
EOF
```

## 문제 해결

### 일반적인 문제들

#### 1. 권한 거부 오류
**증상**: Access Denied 오류 발생
**해결 단계:**
```bash
# 1. 사용자 존재 확인
mc admin user info local username

# 2. 정책 적용 확인
mc admin user info local username | grep -i policy

# 3. 정책 내용 확인
mc admin policy info local policyname

# 4. 리소스 ARN 확인
# 정책의 Resource와 실제 접근하려는 리소스 일치 여부 확인
```

#### 2. 정책 적용 안됨
**증상**: 정책 설정했지만 권한 변화 없음
**해결 단계:**
```bash
# 1. 정책 문법 검증
jq empty policy.json

# 2. 정책 재적용
mc admin policy set local policyname user=username

# 3. 사용자 연결 재설정
mc alias remove user-alias
mc alias set user-alias http://localhost:9000 username password
```

#### 3. 그룹 정책 충돌
**증상**: 그룹과 개별 정책이 충돌
**해결 방법:**
- 명시적 거부(Deny)가 허용(Allow)보다 우선
- 정책 우선순위: Deny > Allow
- 충돌 시 더 제한적인 정책 적용

### 디버깅 도구

#### 정책 시뮬레이터
```bash
# 특정 작업에 대한 권한 확인
mc admin policy simulate local username s3:GetObject arn:aws:s3:::bucket/object
```

#### 실시간 로그 모니터링
```bash
# API 호출 실시간 추적
mc admin trace local --verbose

# 특정 사용자 활동만 필터링
mc admin trace local | grep username
```

## 성능 고려사항

### 정책 최적화

1. **정책 수 최소화**: 복잡한 정책보다 단순한 정책 여러 개
2. **조건 최적화**: 불필요한 조건 제거
3. **리소스 패턴**: 와일드카드 사용 최적화

### 확장성 고려사항

1. **사용자 수 제한**: 대규모 환경에서는 LDAP/AD 연동 고려
2. **정책 캐싱**: 정책 평가 결과 캐싱으로 성능 향상
3. **그룹 활용**: 개별 사용자 정책보다 그룹 정책 활용

## 다음 단계

Lab 6 완료 후 다음 내용을 학습할 수 있습니다:

1. **Lab 7**: 모니터링 설정
   - IAM 활동 모니터링
   - 보안 이벤트 알림
   - 권한 사용 패턴 분석

2. **Lab 9**: 정적 웹사이트 호스팅
   - 버킷 정책을 활용한 공개 웹사이트
   - 세밀한 접근 제어 적용

## 참고 자료

- [MinIO IAM 공식 문서](https://docs.min.io/docs/minio-identity-management.html)
- [AWS IAM 정책 참조](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
- [JSON 정책 언어](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_grammar.html)
- [보안 모범 사례](https://docs.min.io/docs/minio-security-best-practices.html)
