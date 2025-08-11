# Lab 9: 정적 웹사이트 호스팅 - Lab Guide

## 📚 학습 목표

이 실습에서는 MinIO를 활용한 S3 호환 정적 웹사이트 호스팅을 학습합니다:

- **정적 웹사이트 호스팅**: S3 호환 웹사이트 호스팅 기능
- **버킷 정책 설정**: 공개 접근을 위한 정책 구성
- **인덱스 문서 설정**: 기본 페이지 및 에러 페이지 구성
- **CORS 설정**: 크로스 오리진 리소스 공유 설정
- **CDN 연동 준비**: 콘텐츠 전송 네트워크 연동 기초
- **도메인 연결**: 커스텀 도메인 설정 방법

## 🎯 핵심 개념

### 정적 웹사이트 호스팅 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │───▶│   MinIO Bucket  │───▶│   Static Files  │
│   (사용자)       │    │   (웹 서버)      │    │   (HTML/CSS/JS) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Custom Domain │    │   Bucket Policy │    │   Index/Error   │
│   (선택사항)     │    │   (공개 접근)    │    │   Documents     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 웹사이트 호스팅 요구사항

| 구성 요소 | 설명 | 필수 여부 |
|-----------|------|-----------|
| **버킷 정책** | 공개 읽기 권한 설정 | 필수 |
| **인덱스 문서** | 기본 페이지 (index.html) | 필수 |
| **에러 문서** | 404 에러 페이지 | 권장 |
| **CORS 설정** | 크로스 오리진 요청 허용 | 선택 |
| **커스텀 도메인** | 브랜드 도메인 연결 | 선택 |

## 🚀 실습 시작

### 1단계: 웹사이트 호스팅용 버킷 생성

```bash
# 웹사이트 호스팅용 버킷 생성
mc mb local/my-website

# 버킷 목록 확인
mc ls local

# 버킷 정보 확인
mc stat local/my-website
```

### 2단계: 정적 웹사이트 파일 준비

#### 기본 HTML 파일 생성

```bash
# 웹사이트 파일 디렉토리 생성
mkdir -p website-files

# 메인 인덱스 페이지 생성
cat > website-files/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MinIO 정적 웹사이트 호스팅</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>MinIO로 호스팅하는 정적 웹사이트</h1>
        <nav>
            <ul>
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h2>MinIO S3 호환 스토리지로 웹사이트 호스팅</h2>
            <p>이 웹사이트는 MinIO 객체 스토리지를 사용하여 호스팅되고 있습니다.</p>
            <button onclick="loadDynamicContent()">동적 콘텐츠 로드</button>
        </section>
        
        <section class="features">
            <h3>주요 기능</h3>
            <div class="feature-grid">
                <div class="feature">
                    <h4>S3 호환성</h4>
                    <p>AWS S3와 완벽 호환되는 API</p>
                </div>
                <div class="feature">
                    <h4>고성능</h4>
                    <p>빠른 콘텐츠 전송 속도</p>
                </div>
                <div class="feature">
                    <h4>확장성</h4>
                    <p>무제한 스토리지 확장</p>
                </div>
            </div>
        </section>
        
        <section id="dynamic-content">
            <!-- JavaScript로 동적 로드될 영역 -->
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 웹사이트 호스팅 실습. All rights reserved.</p>
    </footer>
    
    <script src="script.js"></script>
</body>
</html>
EOF

# CSS 스타일 파일 생성
cat > website-files/styles.css << 'EOF'
/* MinIO 웹사이트 스타일 */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Arial', sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f4f4f4;
}

header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 1rem 0;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}

header h1 {
    text-align: center;
    margin-bottom: 1rem;
}

nav ul {
    list-style: none;
    display: flex;
    justify-content: center;
    gap: 2rem;
}

nav a {
    color: white;
    text-decoration: none;
    padding: 0.5rem 1rem;
    border-radius: 5px;
    transition: background-color 0.3s;
}

nav a:hover {
    background-color: rgba(255,255,255,0.2);
}

main {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1rem;
}

.hero {
    background: white;
    padding: 3rem;
    border-radius: 10px;
    text-align: center;
    margin-bottom: 2rem;
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
}

.hero h2 {
    color: #667eea;
    margin-bottom: 1rem;
}

.hero button {
    background: #667eea;
    color: white;
    border: none;
    padding: 1rem 2rem;
    border-radius: 5px;
    cursor: pointer;
    font-size: 1rem;
    margin-top: 1rem;
    transition: background-color 0.3s;
}

.hero button:hover {
    background: #5a67d8;
}

.features {
    background: white;
    padding: 2rem;
    border-radius: 10px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
}

.features h3 {
    text-align: center;
    margin-bottom: 2rem;
    color: #667eea;
}

.feature-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
}

.feature {
    text-align: center;
    padding: 1.5rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    transition: transform 0.3s, border-color 0.3s;
}

.feature:hover {
    transform: translateY(-5px);
    border-color: #667eea;
}

.feature h4 {
    color: #667eea;
    margin-bottom: 1rem;
}

#dynamic-content {
    background: white;
    padding: 2rem;
    border-radius: 10px;
    margin-top: 2rem;
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    display: none;
}

footer {
    background: #2d3748;
    color: white;
    text-align: center;
    padding: 2rem;
    margin-top: 3rem;
}

/* 반응형 디자인 */
@media (max-width: 768px) {
    nav ul {
        flex-direction: column;
        gap: 1rem;
    }
    
    .hero {
        padding: 2rem 1rem;
    }
    
    .feature-grid {
        grid-template-columns: 1fr;
    }
}
EOF

# JavaScript 파일 생성
cat > website-files/script.js << 'EOF'
// MinIO 웹사이트 JavaScript

// 동적 콘텐츠 로드 함수
function loadDynamicContent() {
    const dynamicSection = document.getElementById('dynamic-content');
    
    // 동적 콘텐츠 HTML 생성
    const content = `
        <h3>동적으로 로드된 콘텐츠</h3>
        <p>현재 시간: ${new Date().toLocaleString('ko-KR')}</p>
        <div class="stats">
            <div class="stat">
                <h4>방문자 수</h4>
                <p id="visitor-count">${Math.floor(Math.random() * 1000) + 100}</p>
            </div>
            <div class="stat">
                <h4>페이지 로드 시간</h4>
                <p>${(performance.now() / 1000).toFixed(2)}초</p>
            </div>
            <div class="stat">
                <h4>서버 응답 시간</h4>
                <p>${Math.floor(Math.random() * 100) + 50}ms</p>
            </div>
        </div>
        <button onclick="refreshStats()">통계 새로고침</button>
    `;
    
    dynamicSection.innerHTML = content;
    dynamicSection.style.display = 'block';
    
    // 애니메이션 효과
    dynamicSection.style.opacity = '0';
    dynamicSection.style.transform = 'translateY(20px)';
    
    setTimeout(() => {
        dynamicSection.style.transition = 'all 0.5s ease';
        dynamicSection.style.opacity = '1';
        dynamicSection.style.transform = 'translateY(0)';
    }, 100);
}

// 통계 새로고침 함수
function refreshStats() {
    const visitorCount = document.getElementById('visitor-count');
    if (visitorCount) {
        visitorCount.textContent = Math.floor(Math.random() * 1000) + 100;
        
        // 애니메이션 효과
        visitorCount.style.transform = 'scale(1.2)';
        visitorCount.style.color = '#667eea';
        
        setTimeout(() => {
            visitorCount.style.transform = 'scale(1)';
            visitorCount.style.color = 'inherit';
        }, 300);
    }
}

// 페이지 로드 시 실행
document.addEventListener('DOMContentLoaded', function() {
    console.log('MinIO 정적 웹사이트가 로드되었습니다.');
    
    // 네비게이션 활성화
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const navLinks = document.querySelectorAll('nav a');
    
    navLinks.forEach(link => {
        if (link.getAttribute('href') === currentPage) {
            link.style.backgroundColor = 'rgba(255,255,255,0.3)';
        }
    });
});

// 에러 처리
window.addEventListener('error', function(e) {
    console.error('JavaScript 에러:', e.error);
});
EOF

# 추가 페이지 생성
cat > website-files/about.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>소개 - MinIO 웹사이트</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>MinIO 웹사이트 소개</h1>
        <nav>
            <ul>
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h2>MinIO 정적 웹사이트 호스팅에 대하여</h2>
            <p>이 프로젝트는 MinIO 객체 스토리지를 활용한 정적 웹사이트 호스팅 실습입니다.</p>
        </section>
        
        <section class="features">
            <h3>기술 스택</h3>
            <ul>
                <li>MinIO 객체 스토리지</li>
                <li>Kubernetes 오케스트레이션</li>
                <li>HTML5, CSS3, JavaScript</li>
                <li>S3 호환 API</li>
            </ul>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 웹사이트 호스팅 실습. All rights reserved.</p>
    </footer>
</body>
</html>
EOF

cat > website-files/contact.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>연락처 - MinIO 웹사이트</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>연락처</h1>
        <nav>
            <ul>
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h2>문의하기</h2>
            <p>MinIO 웹사이트 호스팅에 대한 문의사항이 있으시면 연락주세요.</p>
        </section>
        
        <section class="features">
            <h3>연락 정보</h3>
            <p>이메일: admin@example.com</p>
            <p>전화: 02-1234-5678</p>
            <p>주소: 서울시 강남구 테헤란로 123</p>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 웹사이트 호스팅 실습. All rights reserved.</p>
    </footer>
</body>
</html>
EOF

# 404 에러 페이지 생성
cat > website-files/404.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>페이지를 찾을 수 없습니다 - MinIO 웹사이트</title>
    <link rel="stylesheet" href="styles.css">
    <style>
        .error-page {
            text-align: center;
            padding: 4rem 2rem;
        }
        .error-code {
            font-size: 6rem;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 1rem;
        }
        .error-message {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
        .back-button {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 1rem 2rem;
            text-decoration: none;
            border-radius: 5px;
            transition: background-color 0.3s;
        }
        .back-button:hover {
            background: #5a67d8;
        }
    </style>
</head>
<body>
    <header>
        <h1>MinIO 웹사이트</h1>
        <nav>
            <ul>
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="error-page">
            <div class="error-code">404</div>
            <div class="error-message">요청하신 페이지를 찾을 수 없습니다.</div>
            <p>페이지가 이동되었거나 삭제되었을 수 있습니다.</p>
            <a href="index.html" class="back-button">홈으로 돌아가기</a>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 웹사이트 호스팅 실습. All rights reserved.</p>
    </footer>
</body>
</html>
EOF

# 파일 목록 확인
echo "생성된 웹사이트 파일:"
ls -la website-files/

# 📋 예상 결과:
# total 32
# drwxrwxr-x 2 user user 4096 Aug 11 01:50 .
# drwxrwxr-x 3 user user 4096 Aug 11 01:50 ..
# -rw-rw-r-- 1 user user 2156 Aug 11 01:50 404.html
# -rw-rw-r-- 1 user user 1834 Aug 11 01:50 about.html
# -rw-rw-r-- 1 user user 1756 Aug 11 01:50 contact.html
# -rw-rw-r-- 1 user user 3245 Aug 11 01:50 index.html
# -rw-rw-r-- 1 user user 2890 Aug 11 01:50 script.js
# -rw-rw-r-- 1 user user 4567 Aug 11 01:50 styles.css
# 
# 💡 설명:
# - 완전한 정적 웹사이트 구조 생성
# - HTML, CSS, JavaScript 파일 포함
# - 404 에러 페이지까지 준비 완료
```

### 3단계: 웹사이트 파일 업로드

```bash
echo "=== 웹사이트 파일 업로드 ==="

# 모든 웹사이트 파일을 버킷에 업로드
mc cp --recursive website-files/ local/my-website/

# 업로드된 파일 확인
mc ls local/my-website/

# 📋 예상 결과:
# [2024-08-11 01:52:15 UTC]  2.1KiB 404.html
# [2024-08-11 01:52:15 UTC]  1.8KiB about.html
# [2024-08-11 01:52:15 UTC]  1.7KiB contact.html
# [2024-08-11 01:52:15 UTC]  3.2KiB index.html
# [2024-08-11 01:52:15 UTC]  2.8KiB script.js
# [2024-08-11 01:52:15 UTC]  4.5KiB styles.css
# 
# 💡 설명:
# - 모든 웹사이트 파일이 성공적으로 업로드됨
# - 파일 크기와 업로드 시간 확인 가능
# - MinIO 버킷에 웹사이트 콘텐츠 저장 완료

# 파일별 상세 정보 확인
for file in index.html styles.css script.js about.html contact.html 404.html; do
    echo "파일: $file"
    mc stat local/my-website/$file
    echo "---"
done
```

### 4단계: 버킷 정책 설정 (공개 접근)

#### 공개 읽기 정책 생성

```bash
# 공개 읽기 정책 파일 생성
cat > website-public-policy.json << 'EOF'
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
        "arn:aws:s3:::my-website/*"
      ]
    }
  ]
}
EOF

# 버킷에 공개 정책 적용
mc policy set-json website-public-policy.json local/my-website

# 정책 적용 확인
mc policy get local/my-website

# 📋 예상 결과:
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": "*",
#       "Action": [
#         "s3:GetObject"
#       ],
#       "Resource": [
#         "arn:aws:s3:::my-website/*"
#       ]
#     }
#   ]
# }
# 
# 💡 설명:
# - 공개 읽기 정책이 성공적으로 적용됨
# - 모든 사용자(*) 가 GetObject 권한 보유
# - 웹사이트 파일에 공개 접근 가능
```

### 5단계: 웹사이트 호스팅 설정

#### MinIO 웹사이트 호스팅 활성화

```bash
echo "=== 웹사이트 호스팅 설정 ==="

# 웹사이트 호스팅 설정 (인덱스 및 에러 문서 지정)
# MinIO에서는 mc admin config를 통해 설정하거나 직접 접근 방식 사용

# 포트 포워딩 확인 (필요시 재실행)
kubectl port-forward -n minio-tenant svc/minio 9000:80 &
sleep 3

# 웹사이트 접근 테스트
echo "웹사이트 접근 테스트:"
echo "메인 페이지: http://localhost:9000/my-website/index.html"
echo "소개 페이지: http://localhost:9000/my-website/about.html"
echo "연락처 페이지: http://localhost:9000/my-website/contact.html"
echo "404 페이지: http://localhost:9000/my-website/404.html"

# curl을 통한 접근 테스트
echo -e "\n=== HTTP 응답 테스트 ==="
curl -I http://localhost:9000/my-website/index.html

# 📋 예상 결과:
# HTTP/1.1 200 OK
# Accept-Ranges: bytes
# Content-Length: 3245
# Content-Type: text/html
# ETag: "9bb58f26192e4ba00f01e2e7b136bbd8"
# Last-Modified: Sun, 11 Aug 2024 01:52:15 GMT
# Server: MinIO
# Vary: Origin
# X-Amz-Request-Id: 17C8B2F4A1B2C3D4
# Date: Sun, 11 Aug 2024 01:55:30 GMT
# 
# 💡 설명:
# - HTTP 200 OK 응답으로 정상 접근 확인
# - Content-Type이 text/html로 올바르게 설정
# - MinIO 서버에서 웹 콘텐츠 제공 중
```

## 🎯 실습 완료 체크리스트

- [ ] 정적 웹사이트 파일 생성 완료
- [ ] MinIO 버킷에 파일 업로드 완료
- [ ] 공개 접근 정책 설정 완료
- [ ] 웹사이트 호스팅 활성화 완료
- [ ] 브라우저 접근 테스트 완료

## 🧹 정리

실습이 완료되면 웹사이트 리소스를 정리합니다:

```bash
# 웹사이트 버킷 삭제
mc rm --recursive local/my-website --force
mc rb local/my-website

# 로컬 파일 정리
rm -rf website-files/
rm -f *.json *.txt *.md *.sh

echo "웹사이트 호스팅 실습 정리 완료"
```

## 📚 다음 단계

이제 **Lab 10: 백업 및 재해 복구**로 진행하여 MinIO 데이터의 백업 전략을 학습해보세요.

## 💡 핵심 포인트

1. **S3 호환성**: AWS S3와 동일한 방식으로 정적 웹사이트 호스팅 가능
2. **공개 정책**: 버킷 정책을 통한 공개 접근 제어
3. **성능 최적화**: CDN 연동으로 전 세계 사용자에게 빠른 서비스 제공
4. **비용 효율성**: 별도의 웹 서버 없이 객체 스토리지만으로 웹사이트 운영
5. **확장성**: 트래픽 증가에 따른 자동 확장 가능

---

**🔗 관련 문서:**
- [LAB-09-CONCEPTS.md](LAB-09-CONCEPTS.md) - 정적 웹사이트 호스팅 상세 개념
- [LAB-10-GUIDE.md](LAB-10-GUIDE.md) - 다음 Lab Guide: 백업 및 재해 복구
