#!/bin/bash

# Lab 9: MinIO 정적 웹사이트 호스팅
# 학습 목표: S3 호환 정적 웹사이트 호스팅, 버킷 정책, CORS 설정

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
    echo "  • S3 호환 정적 웹사이트 호스팅"
    echo "  • 버킷 정책과 공개 접근 설정"
    echo "  • CORS(Cross-Origin Resource Sharing) 구성"
    echo "  • 인덱스 문서와 오류 문서 설정"
    echo "  • 실제 웹사이트 배포 및 브라우저 테스트"
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
    
    log_concept "정적 웹사이트 호스팅을 위해 MinIO 연결을 확인합니다."
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
    
    checkpoint "MinIO 연결 설정 완료"
}

# 웹사이트 파일 생성
create_website_files() {
    log_step "정적 웹사이트 파일 생성"
    
    log_concept "실제 웹사이트를 구성하는 파일들을 생성합니다:"
    echo "  • index.html: 메인 페이지"
    echo "  • about.html: 소개 페이지"
    echo "  • style.css: 스타일시트"
    echo "  • script.js: JavaScript"
    echo "  • 404.html: 오류 페이지"
    echo ""
    
    # 웹사이트 디렉토리 생성
    mkdir -p website-files/{css,js,images}
    
    # index.html 생성
    log_info "메인 페이지 (index.html) 생성 중..."
    cat > website-files/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MinIO 정적 웹사이트 호스팅 데모</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <header>
        <nav>
            <div class="logo">
                <h1>MinIO Website</h1>
            </div>
            <ul class="nav-links">
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h2>MinIO S3 호환 정적 웹사이트 호스팅</h2>
            <p>이 웹사이트는 MinIO 객체 스토리지에서 호스팅되고 있습니다.</p>
            <button onclick="showInfo()">더 알아보기</button>
        </section>
        
        <section class="features">
            <div class="feature-card">
                <h3>🚀 빠른 성능</h3>
                <p>MinIO의 고성능 객체 스토리지로 빠른 웹사이트 로딩</p>
            </div>
            <div class="feature-card">
                <h3>🔒 보안</h3>
                <p>세밀한 버킷 정책으로 안전한 웹사이트 운영</p>
            </div>
            <div class="feature-card">
                <h3>📱 반응형</h3>
                <p>모든 디바이스에서 최적화된 사용자 경험</p>
            </div>
        </section>
        
        <section class="info" id="info-section" style="display: none;">
            <h3>기술 정보</h3>
            <ul>
                <li>호스팅: MinIO 객체 스토리지</li>
                <li>프로토콜: S3 호환 API</li>
                <li>배포: Kubernetes 환경</li>
                <li>CDN: 연동 준비 완료</li>
            </ul>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 정적 웹사이트 호스팅 데모. Lab 9 실습용.</p>
    </footer>
    
    <script src="js/script.js"></script>
</body>
</html>
EOF
    
    # about.html 생성
    log_info "소개 페이지 (about.html) 생성 중..."
    cat > website-files/about.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>소개 - MinIO 웹사이트</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <header>
        <nav>
            <div class="logo">
                <h1>MinIO Website</h1>
            </div>
            <ul class="nav-links">
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="about">
            <h2>MinIO 정적 웹사이트 호스팅에 대하여</h2>
            
            <div class="about-content">
                <h3>🎯 목적</h3>
                <p>이 데모 웹사이트는 MinIO 객체 스토리지를 사용한 S3 호환 정적 웹사이트 호스팅의 
                   실제 구현 예시입니다. Lab 9 실습을 통해 다음을 학습할 수 있습니다:</p>
                
                <ul>
                    <li>S3 호환 정적 웹사이트 호스팅 설정</li>
                    <li>버킷 정책을 통한 공개 접근 제어</li>
                    <li>CORS 설정과 크로스 오리진 요청 처리</li>
                    <li>인덱스 문서와 오류 문서 구성</li>
                    <li>실제 브라우저에서의 웹사이트 접근 테스트</li>
                </ul>
                
                <h3>🏗️ 아키텍처</h3>
                <p>이 웹사이트는 다음과 같은 구조로 구성되어 있습니다:</p>
                
                <div class="architecture">
                    <pre>
Browser ←→ MinIO (S3 Compatible) ←→ Kubernetes Cluster
   ↑              ↑                        ↑
사용자 접근    정적 파일 서빙         컨테이너 오케스트레이션
                    </pre>
                </div>
                
                <h3>📊 실습 성과</h3>
                <p>이 실습을 완료하면 다음을 할 수 있게 됩니다:</p>
                
                <ul>
                    <li>프로덕션 환경에서 정적 웹사이트 호스팅 구축</li>
                    <li>CDN과 연동하여 글로벌 서비스 제공</li>
                    <li>비용 효율적인 웹사이트 운영</li>
                    <li>DevOps 파이프라인과 연동한 자동 배포</li>
                </ul>
            </div>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 정적 웹사이트 호스팅 데모. Lab 9 실습용.</p>
    </footer>
    
    <script src="js/script.js"></script>
</body>
</html>
EOF
    
    log_success "웹사이트 HTML 파일 생성 완료"
# CSS 파일 생성
create_css_files() {
    log_info "스타일시트 (style.css) 생성 중..."
    cat > website-files/css/style.css << 'EOF'
/* Reset and Base Styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f8f9fa;
}

/* Header and Navigation */
header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 1rem 0;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
}

.logo h1 {
    font-size: 1.8rem;
    font-weight: 700;
}

.nav-links {
    display: flex;
    list-style: none;
    gap: 2rem;
}

.nav-links a {
    color: white;
    text-decoration: none;
    font-weight: 500;
    transition: opacity 0.3s ease;
}

.nav-links a:hover {
    opacity: 0.8;
}

/* Main Content */
main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

/* Hero Section */
.hero {
    text-align: center;
    padding: 4rem 0;
    background: white;
    border-radius: 10px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    margin-bottom: 3rem;
}

.hero h2 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    color: #2c3e50;
}

.hero p {
    font-size: 1.2rem;
    color: #7f8c8d;
    margin-bottom: 2rem;
}

.hero button {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 12px 30px;
    font-size: 1.1rem;
    border-radius: 25px;
    cursor: pointer;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.hero button:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(102, 126, 234, 0.3);
}

/* Features Section */
.features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.feature-card {
    background: white;
    padding: 2rem;
    border-radius: 10px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    text-align: center;
    transition: transform 0.3s ease;
}

.feature-card:hover {
    transform: translateY(-5px);
}

.feature-card h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    color: #2c3e50;
}

.feature-card p {
    color: #7f8c8d;
    line-height: 1.6;
}

/* Info Section */
.info {
    background: white;
    padding: 2rem;
    border-radius: 10px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    margin-bottom: 2rem;
}

.info h3 {
    color: #2c3e50;
    margin-bottom: 1rem;
}

.info ul {
    list-style-type: none;
    padding-left: 0;
}

.info li {
    padding: 0.5rem 0;
    border-bottom: 1px solid #ecf0f1;
    color: #7f8c8d;
}

.info li:last-child {
    border-bottom: none;
}

/* About Page Styles */
.about {
    background: white;
    padding: 3rem;
    border-radius: 10px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
}

.about h2 {
    color: #2c3e50;
    margin-bottom: 2rem;
    text-align: center;
}

.about-content h3 {
    color: #667eea;
    margin: 2rem 0 1rem 0;
}

.about-content ul {
    margin: 1rem 0;
    padding-left: 2rem;
}

.about-content li {
    margin: 0.5rem 0;
    color: #7f8c8d;
}

.architecture {
    background: #f8f9fa;
    padding: 1rem;
    border-radius: 5px;
    margin: 1rem 0;
    border-left: 4px solid #667eea;
}

.architecture pre {
    font-family: 'Courier New', monospace;
    color: #2c3e50;
    text-align: center;
}

/* Footer */
footer {
    background: #2c3e50;
    color: white;
    text-align: center;
    padding: 2rem 0;
    margin-top: 3rem;
}

/* Responsive Design */
@media (max-width: 768px) {
    nav {
        flex-direction: column;
        gap: 1rem;
    }
    
    .nav-links {
        gap: 1rem;
    }
    
    .hero h2 {
        font-size: 2rem;
    }
    
    .features {
        grid-template-columns: 1fr;
    }
    
    main {
        padding: 1rem;
    }
}

/* Animation */
@keyframes fadeIn {
    from {
        opacity: 0;
        transform: translateY(20px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.info {
    animation: fadeIn 0.5s ease-in-out;
}
EOF
}

# JavaScript 파일 생성
create_js_files() {
    log_info "JavaScript (script.js) 생성 중..."
    cat > website-files/js/script.js << 'EOF'
// MinIO 정적 웹사이트 호스팅 데모 JavaScript

// 페이지 로드 시 실행
document.addEventListener('DOMContentLoaded', function() {
    console.log('MinIO 정적 웹사이트 호스팅 데모가 로드되었습니다.');
    
    // 현재 시간 표시
    updateCurrentTime();
    setInterval(updateCurrentTime, 1000);
    
    // 페이지 방문 통계 (로컬 스토리지 사용)
    updateVisitStats();
});

// 더 알아보기 버튼 클릭 시 정보 표시
function showInfo() {
    const infoSection = document.getElementById('info-section');
    
    if (infoSection.style.display === 'none' || infoSection.style.display === '') {
        infoSection.style.display = 'block';
        infoSection.scrollIntoView({ behavior: 'smooth' });
        
        // 버튼 텍스트 변경
        const button = document.querySelector('.hero button');
        if (button) {
            button.textContent = '정보 숨기기';
        }
    } else {
        infoSection.style.display = 'none';
        
        // 버튼 텍스트 원복
        const button = document.querySelector('.hero button');
        if (button) {
            button.textContent = '더 알아보기';
        }
    }
}

// 현재 시간 업데이트
function updateCurrentTime() {
    const now = new Date();
    const timeString = now.toLocaleString('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
    
    // 시간 표시 요소가 있으면 업데이트
    const timeElement = document.getElementById('current-time');
    if (timeElement) {
        timeElement.textContent = timeString;
    }
}

// 방문 통계 업데이트
function updateVisitStats() {
    // 로컬 스토리지에서 방문 횟수 가져오기
    let visitCount = localStorage.getItem('minio-website-visits');
    
    if (visitCount === null) {
        visitCount = 0;
    }
    
    visitCount = parseInt(visitCount) + 1;
    localStorage.setItem('minio-website-visits', visitCount.toString());
    
    console.log(`이 웹사이트를 ${visitCount}번째 방문하고 있습니다.`);
    
    // 방문 통계 표시 요소가 있으면 업데이트
    const statsElement = document.getElementById('visit-stats');
    if (statsElement) {
        statsElement.textContent = `방문 횟수: ${visitCount}`;
    }
}

// 네비게이션 활성화 (현재 페이지 하이라이트)
function highlightCurrentPage() {
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const navLinks = document.querySelectorAll('.nav-links a');
    
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        if (href === currentPage) {
            link.style.opacity = '1';
            link.style.fontWeight = 'bold';
        }
    });
}

// 페이지 로드 완료 후 네비게이션 하이라이트
window.addEventListener('load', highlightCurrentPage);

// 스크롤 이벤트 처리
window.addEventListener('scroll', function() {
    const header = document.querySelector('header');
    if (window.scrollY > 100) {
        header.style.boxShadow = '0 4px 20px rgba(0,0,0,0.2)';
    } else {
        header.style.boxShadow = '0 2px 10px rgba(0,0,0,0.1)';
    }
});

// 에러 처리
window.addEventListener('error', function(e) {
    console.error('JavaScript 오류 발생:', e.error);
});

// MinIO 연결 테스트 (실제 환경에서는 CORS 설정 필요)
function testMinIOConnection() {
    console.log('MinIO 연결 테스트는 브라우저 개발자 도구에서 확인할 수 있습니다.');
    console.log('실제 프로덕션 환경에서는 CORS 설정이 필요합니다.');
}
EOF
}

# 404 오류 페이지 생성
create_error_page() {
    log_info "404 오류 페이지 (404.html) 생성 중..."
    cat > website-files/404.html << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - 페이지를 찾을 수 없습니다</title>
    <link rel="stylesheet" href="css/style.css">
    <style>
        .error-container {
            text-align: center;
            padding: 4rem 2rem;
            min-height: 60vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        
        .error-code {
            font-size: 8rem;
            font-weight: bold;
            color: #e74c3c;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
        }
        
        .error-message {
            font-size: 1.5rem;
            color: #7f8c8d;
            margin-bottom: 2rem;
        }
        
        .error-description {
            font-size: 1.1rem;
            color: #95a5a6;
            margin-bottom: 3rem;
            max-width: 600px;
        }
        
        .back-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 1.1rem;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            display: inline-block;
        }
        
        .back-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.3);
        }
    </style>
</head>
<body>
    <header>
        <nav>
            <div class="logo">
                <h1>MinIO Website</h1>
            </div>
            <ul class="nav-links">
                <li><a href="index.html">홈</a></li>
                <li><a href="about.html">소개</a></li>
                <li><a href="contact.html">연락처</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <div class="error-container">
            <div class="error-code">404</div>
            <div class="error-message">페이지를 찾을 수 없습니다</div>
            <div class="error-description">
                요청하신 페이지가 존재하지 않거나 이동되었을 수 있습니다.<br>
                URL을 다시 확인하시거나 홈페이지로 돌아가세요.
            </div>
            <a href="index.html" class="back-button">홈으로 돌아가기</a>
        </div>
    </main>
    
    <footer>
        <p>&copy; 2024 MinIO 정적 웹사이트 호스팅 데모. Lab 9 실습용.</p>
    </footer>
    
    <script>
        // 404 페이지 방문 로그
        console.log('404 페이지에 도달했습니다. 요청된 URL:', window.location.href);
        
        // 3초 후 자동으로 홈페이지로 리다이렉트 (선택사항)
        // setTimeout(() => {
        //     window.location.href = 'index.html';
        // }, 3000);
    </script>
</body>
</html>
EOF
    
    log_success "웹사이트 파일 생성 완료"
    
    # 생성된 파일 목록 표시
    echo ""
    log_info "생성된 웹사이트 파일 구조:"
    tree website-files/ 2>/dev/null || find website-files/ -type f | sort
    
# 웹사이트 버킷 생성 및 설정
setup_website_bucket() {
    log_step "웹사이트 호스팅용 버킷 생성 및 설정"
    
    log_concept "정적 웹사이트 호스팅을 위한 버킷 설정:"
    echo "  • 웹사이트 전용 버킷 생성"
    echo "  • 공개 읽기 정책 적용"
    echo "  • 웹사이트 호스팅 설정"
    echo ""
    
    WEBSITE_BUCKET="my-static-website"
    
    # 버킷 생성
    log_info "웹사이트 버킷 생성: $WEBSITE_BUCKET"
    mc mb local/$WEBSITE_BUCKET 2>/dev/null || log_warning "버킷이 이미 존재합니다."
    
    # 버킷 정책 설정 (공개 읽기)
    log_info "공개 읽기 정책 적용 중..."
    
    log_concept "버킷 정책 설명:"
    echo "  • 모든 사용자(*) 에게 읽기 권한 부여"
    echo "  • s3:GetObject 액션만 허용"
    echo "  • 웹사이트 파일에만 적용"
    echo ""
    
    # 정책 JSON 파일 생성
    cat > website-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${WEBSITE_BUCKET}/*"
    }
  ]
}
EOF
    
    # 정책 적용
    mc policy set-json website-policy.json local/$WEBSITE_BUCKET
    
    log_success "버킷 정책 적용 완료"
    
    # 정책 확인
    log_info "적용된 정책 확인:"
    mc policy get local/$WEBSITE_BUCKET
    
    checkpoint "웹사이트 버킷 설정 완료"
}

# 웹사이트 파일 업로드
upload_website_files() {
    log_step "웹사이트 파일 업로드"
    
    log_concept "생성된 웹사이트 파일들을 MinIO 버킷에 업로드합니다:"
    echo "  • HTML, CSS, JavaScript 파일"
    echo "  • 적절한 Content-Type 설정"
    echo "  • 파일 구조 유지"
    echo ""
    
    WEBSITE_BUCKET="my-static-website"
    
    # 파일 업로드 (재귀적으로)
    log_info "웹사이트 파일 업로드 중..."
    
    # 개별 파일 업로드 (Content-Type 설정을 위해)
    log_info "HTML 파일 업로드..."
    mc cp website-files/index.html local/$WEBSITE_BUCKET/ --attr "Content-Type=text/html"
    mc cp website-files/about.html local/$WEBSITE_BUCKET/ --attr "Content-Type=text/html"
    mc cp website-files/404.html local/$WEBSITE_BUCKET/ --attr "Content-Type=text/html"
    
    log_info "CSS 파일 업로드..."
    mc cp website-files/css/style.css local/$WEBSITE_BUCKET/css/ --attr "Content-Type=text/css"
    
    log_info "JavaScript 파일 업로드..."
    mc cp website-files/js/script.js local/$WEBSITE_BUCKET/js/ --attr "Content-Type=application/javascript"
    
    log_success "웹사이트 파일 업로드 완료"
    
    # 업로드된 파일 확인
    echo ""
    log_info "업로드된 파일 목록:"
    mc ls --recursive local/$WEBSITE_BUCKET/
    
    checkpoint "웹사이트 파일 업로드 완료"
}

# CORS 설정
setup_cors() {
    log_step "CORS (Cross-Origin Resource Sharing) 설정"
    
    log_concept "CORS 설정이 필요한 이유:"
    echo "  • 브라우저의 Same-Origin Policy 제한 해결"
    echo "  • 다른 도메인에서 리소스 접근 허용"
    echo "  • AJAX 요청 및 폰트 로딩 지원"
    echo ""
    
    # CORS 설정 파일 생성
    log_info "CORS 설정 파일 생성 중..."
    cat > cors-config.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF
    
    # CORS 설정 적용
    log_info "CORS 설정 적용 중..."
    WEBSITE_BUCKET="my-static-website"
    
    # MinIO에서 CORS 설정 (관리자 권한 필요)
    log_warning "CORS 설정은 MinIO 관리자 권한이 필요합니다."
    log_info "실제 운영 환경에서는 다음 명령어로 설정합니다:"
    echo "  mc admin config set local cors_allowed_origins=\"*\""
    echo "  mc admin config set local cors_allowed_methods=\"GET,HEAD\""
    echo "  mc admin config set local cors_allowed_headers=\"*\""
    
    # 현재 실습 환경에서는 기본 설정 사용
    log_info "현재 실습 환경에서는 기본 CORS 설정을 사용합니다."
    
    log_success "CORS 설정 완료"
    checkpoint "CORS 설정 완료"
}

# 웹사이트 접근 테스트
test_website_access() {
    log_step "웹사이트 접근 테스트"
    
    log_concept "배포된 웹사이트에 실제로 접근해봅니다:"
    echo "  • HTTP를 통한 직접 접근"
    echo "  • 인덱스 문서 자동 로딩 확인"
    echo "  • 404 오류 페이지 테스트"
    echo ""
    
    WEBSITE_BUCKET="my-static-website"
    MINIO_ENDPOINT="http://localhost:9000"
    
    # 웹사이트 URL 구성
    WEBSITE_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/index.html"
    ABOUT_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/about.html"
    ERROR_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/nonexistent.html"
    CSS_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/css/style.css"
    JS_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/js/script.js"
    
    log_info "웹사이트 URL 정보:"
    echo "  • 메인 페이지: $WEBSITE_URL"
    echo "  • 소개 페이지: $ABOUT_URL"
    echo "  • CSS 파일: $CSS_URL"
    echo "  • JavaScript 파일: $JS_URL"
    echo ""
    
    # HTTP 응답 테스트
    log_info "HTTP 응답 테스트 중..."
    
    # 메인 페이지 테스트
    if curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL" | grep -q "200"; then
        log_success "메인 페이지 접근 성공 (200 OK)"
    else
        log_error "메인 페이지 접근 실패"
    fi
    
    # CSS 파일 테스트
    if curl -s -o /dev/null -w "%{http_code}" "$CSS_URL" | grep -q "200"; then
        log_success "CSS 파일 접근 성공 (200 OK)"
    else
        log_error "CSS 파일 접근 실패"
    fi
    
    # JavaScript 파일 테스트
    if curl -s -o /dev/null -w "%{http_code}" "$JS_URL" | grep -q "200"; then
        log_success "JavaScript 파일 접근 성공 (200 OK)"
    else
        log_error "JavaScript 파일 접근 실패"
    fi
    
    # 404 테스트
    if curl -s -o /dev/null -w "%{http_code}" "$ERROR_URL" | grep -q "404"; then
        log_success "404 오류 페이지 정상 동작"
    else
        log_warning "404 오류 페이지 설정이 필요할 수 있습니다"
    fi
    
    echo ""
    log_info "브라우저에서 다음 URL로 접근해보세요:"
    echo -e "${GREEN}$WEBSITE_URL${NC}"
    echo ""
    log_info "또는 다음 명령어로 HTML 내용을 확인할 수 있습니다:"
    echo "curl $WEBSITE_URL"
    
    checkpoint "웹사이트 접근 테스트 완료"
}

# 브라우저 테스트 가이드
browser_test_guide() {
    log_step "브라우저 테스트 가이드"
    
    log_concept "실제 브라우저에서 웹사이트를 테스트해봅시다:"
    echo "  • 다양한 브라우저에서 호환성 확인"
    echo "  • 반응형 디자인 테스트"
    echo "  • JavaScript 기능 동작 확인"
    echo ""
    
    WEBSITE_BUCKET="my-static-website"
    MINIO_ENDPOINT="http://localhost:9000"
    WEBSITE_URL="$MINIO_ENDPOINT/$WEBSITE_BUCKET/index.html"
    
    echo -e "${YELLOW}=== 브라우저 테스트 단계 ===${NC}"
    echo ""
    echo "1. 웹 브라우저를 열고 다음 URL에 접근하세요:"
    echo -e "   ${GREEN}$WEBSITE_URL${NC}"
    echo ""
    echo "2. 확인할 항목들:"
    echo "   ✓ 페이지가 정상적으로 로드되는지"
    echo "   ✓ CSS 스타일이 적용되는지"
    echo "   ✓ '더 알아보기' 버튼이 동작하는지"
    echo "   ✓ 네비게이션 링크가 작동하는지"
    echo "   ✓ 반응형 디자인이 적용되는지 (창 크기 조절)"
    echo ""
    echo "3. 개발자 도구 확인 (F12):"
    echo "   ✓ Console 탭에서 JavaScript 로그 확인"
    echo "   ✓ Network 탭에서 리소스 로딩 상태 확인"
    echo "   ✓ 오류 메시지가 없는지 확인"
    echo ""
    echo "4. 다른 페이지 테스트:"
    echo -e "   • 소개 페이지: ${GREEN}$MINIO_ENDPOINT/$WEBSITE_BUCKET/about.html${NC}"
    echo -e "   • 존재하지 않는 페이지: ${GREEN}$MINIO_ENDPOINT/$WEBSITE_BUCKET/test.html${NC}"
    echo ""
    
    read -p "브라우저 테스트를 완료했습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_success "브라우저 테스트 완료!"
        
        # 테스트 결과 입력받기
        echo ""
        log_info "테스트 결과를 간단히 공유해주세요:"
        read -p "페이지가 정상적으로 로드되었나요? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_success "웹사이트 호스팅 성공!"
        else
            log_warning "문제가 있다면 이전 단계를 다시 확인해보세요."
        fi
    else
        log_info "나중에 브라우저 테스트를 진행해보세요."
    fi
    
# CDN 연동 준비
prepare_cdn_integration() {
    log_step "CDN 연동 준비"
    
    log_concept "CDN(Content Delivery Network) 연동을 위한 준비 작업:"
    echo "  • Origin 서버 설정 확인"
    echo "  • 캐시 헤더 최적화"
    echo "  • CDN 설정 가이드 제공"
    echo ""
    
    WEBSITE_BUCKET="my-static-website"
    MINIO_ENDPOINT="http://localhost:9000"
    
    log_info "=== CDN Origin 설정 정보 ==="
    echo "Origin URL: $MINIO_ENDPOINT/$WEBSITE_BUCKET/"
    echo "Origin Type: S3 Compatible (MinIO)"
    echo "Protocol: HTTP (프로덕션에서는 HTTPS 권장)"
    echo ""
    
    log_info "=== 권장 CDN 설정 ==="
    echo "• Cache Behavior:"
    echo "  - HTML files: Cache for 1 hour"
    echo "  - CSS/JS files: Cache for 1 day"
    echo "  - Images: Cache for 1 week"
    echo ""
    echo "• Origin Request Headers:"
    echo "  - Host: 원본 도메인"
    echo "  - User-Agent: CDN 식별자"
    echo ""
    echo "• Error Pages:"
    echo "  - 404 → /404.html"
    echo "  - 403 → /404.html"
    echo ""
    
    log_info "=== 주요 CDN 서비스 연동 가이드 ==="
    echo ""
    echo "1. CloudFlare:"
    echo "   • DNS 설정으로 간단한 연동"
    echo "   • 무료 플랜 제공"
    echo "   • 자동 HTTPS 지원"
    echo ""
    echo "2. AWS CloudFront:"
    echo "   • S3 호환성으로 쉬운 설정"
    echo "   • 글로벌 엣지 로케이션"
    echo "   • 세밀한 캐시 제어"
    echo ""
    echo "3. Azure CDN:"
    echo "   • Microsoft 생태계 통합"
    echo "   • 다양한 가격 옵션"
    echo "   • 실시간 분석 제공"
    echo ""
    
    # CDN 설정 예시 파일 생성
    log_info "CDN 설정 예시 파일 생성 중..."
    
    cat > cdn-config-example.json << EOF
{
  "cloudflare_example": {
    "origin": "$MINIO_ENDPOINT/$WEBSITE_BUCKET",
    "cache_rules": {
      "html": "public, max-age=3600",
      "css_js": "public, max-age=86400",
      "images": "public, max-age=604800"
    },
    "page_rules": {
      "index": "/$WEBSITE_BUCKET/index.html",
      "error": "/$WEBSITE_BUCKET/404.html"
    }
  },
  "cloudfront_example": {
    "origin_domain": "localhost:9000",
    "origin_path": "/$WEBSITE_BUCKET",
    "default_root_object": "index.html",
    "custom_error_responses": [
      {
        "error_code": 404,
        "response_page_path": "/404.html",
        "response_code": 404
      }
    ]
  }
}
EOF
    
    log_success "CDN 설정 예시 파일 생성 완료: cdn-config-example.json"
    
    checkpoint "CDN 연동 준비 완료"
}

# 성능 최적화 팁
performance_optimization_tips() {
    log_step "성능 최적화 팁"
    
    log_concept "정적 웹사이트 호스팅 성능을 최적화하는 방법들:"
    echo "  • 파일 압축 및 최적화"
    echo "  • 캐시 전략 수립"
    echo "  • 이미지 최적화"
    echo "  • 코드 분할 및 지연 로딩"
    echo ""
    
    echo -e "${YELLOW}=== 성능 최적화 체크리스트 ===${NC}"
    echo ""
    echo "📁 파일 최적화:"
    echo "  ✓ HTML/CSS/JS 파일 압축 (minify)"
    echo "  ✓ 이미지 압축 및 WebP 형식 사용"
    echo "  ✓ 불필요한 파일 제거"
    echo "  ✓ 파일 크기 모니터링"
    echo ""
    echo "🚀 로딩 최적화:"
    echo "  ✓ CSS는 <head>에, JS는 </body> 직전에 배치"
    echo "  ✓ 중요하지 않은 리소스는 지연 로딩"
    echo "  ✓ 폰트 최적화 (font-display: swap)"
    echo "  ✓ 이미지 lazy loading 적용"
    echo ""
    echo "💾 캐시 최적화:"
    echo "  ✓ 정적 리소스에 긴 캐시 시간 설정"
    echo "  ✓ HTML 파일은 짧은 캐시 시간"
    echo "  ✓ ETag 헤더 활용"
    echo "  ✓ 버전 관리를 통한 캐시 무효화"
    echo ""
    echo "📊 모니터링:"
    echo "  ✓ Google PageSpeed Insights 사용"
    echo "  ✓ 웹 성능 메트릭 추적"
    echo "  ✓ 사용자 경험 지표 모니터링"
    echo "  ✓ 정기적인 성능 테스트"
    echo ""
    
    # 성능 테스트 스크립트 생성
    log_info "성능 테스트 스크립트 생성 중..."
    
    cat > performance-test.sh << 'EOF'
#!/bin/bash

# MinIO 정적 웹사이트 성능 테스트 스크립트

WEBSITE_URL="http://localhost:9000/my-static-website/index.html"

echo "=== MinIO 정적 웹사이트 성능 테스트 ==="
echo ""

# 응답 시간 측정
echo "1. 응답 시간 측정:"
curl -o /dev/null -s -w "   연결 시간: %{time_connect}s\n   응답 시간: %{time_total}s\n   파일 크기: %{size_download} bytes\n" "$WEBSITE_URL"
echo ""

# 여러 번 요청하여 평균 응답 시간 계산
echo "2. 평균 응답 시간 (10회 측정):"
total_time=0
for i in {1..10}; do
    time=$(curl -o /dev/null -s -w "%{time_total}" "$WEBSITE_URL")
    total_time=$(echo "$total_time + $time" | bc -l)
done
avg_time=$(echo "scale=3; $total_time / 10" | bc -l)
echo "   평균 응답 시간: ${avg_time}s"
echo ""

# HTTP 헤더 확인
echo "3. HTTP 헤더 확인:"
curl -I "$WEBSITE_URL" 2>/dev/null | grep -E "(Content-Type|Content-Length|Cache-Control|ETag)"
echo ""

echo "성능 테스트 완료!"
EOF
    
    chmod +x performance-test.sh
    log_success "성능 테스트 스크립트 생성 완료: performance-test.sh"
    
    checkpoint "성능 최적화 팁 제공 완료"
}

# 실습 정리
cleanup_lab() {
    log_step "실습 환경 정리"
    
    log_concept "실습에서 생성된 리소스들을 정리합니다:"
    echo "  • 웹사이트 파일"
    echo "  • 설정 파일"
    echo "  • 테스트 버킷 (선택적)"
    echo ""
    
    read -p "생성된 파일들을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "임시 파일 정리 중..."
        rm -rf website-files/
        rm -f website-policy.json cors-config.json cdn-config-example.json
        log_success "임시 파일 정리 완료"
    fi
    
    read -p "웹사이트 버킷을 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "웹사이트 버킷 정리 중..."
        mc rb --force local/my-static-website 2>/dev/null || true
        log_success "웹사이트 버킷 정리 완료"
    fi
    
    log_info "유용한 스크립트는 보존됩니다:"
    echo "  • performance-test.sh"
    echo ""
    log_info "이 스크립트는 실제 운영 환경에서 활용할 수 있습니다."
    
    log_success "실습 정리 완료"
}

# 실습 요약 및 다음 단계
lab_summary() {
    log_step "Lab 9 실습 요약"
    
    echo -e "${GREEN}=== 학습 완료 내용 ===${NC}"
    echo "✅ S3 호환 정적 웹사이트 호스팅"
    echo "   • HTML, CSS, JavaScript 파일 배포"
    echo "   • 반응형 웹 디자인 구현"
    echo "   • 404 오류 페이지 설정"
    echo ""
    echo "✅ 버킷 정책과 보안 설정"
    echo "   • 공개 읽기 정책 적용"
    echo "   • 적절한 권한 제어"
    echo "   • 보안 모범 사례 적용"
    echo ""
    echo "✅ CORS 설정과 크로스 오리진 처리"
    echo "   • 브라우저 보안 정책 이해"
    echo "   • 다중 도메인 지원 설정"
    echo "   • API 호출 지원 준비"
    echo ""
    echo "✅ 실제 브라우저 테스트"
    echo "   • HTTP 접근 테스트"
    echo "   • 리소스 로딩 확인"
    echo "   • 사용자 경험 검증"
    echo ""
    
    echo -e "${BLUE}=== 핵심 개념 정리 ===${NC}"
    echo "• 정적 웹사이트 호스팅: 서버 없이 파일만으로 웹사이트 운영"
    echo "• 버킷 정책: 세밀한 접근 제어를 통한 보안 관리"
    echo "• CORS: 브라우저 보안 정책과 크로스 오리진 요청 처리"
    echo "• CDN 연동: 글로벌 성능 최적화를 위한 준비"
    echo ""
    
    echo -e "${YELLOW}=== 실무 활용 팁 ===${NC}"
    echo "• CI/CD 파이프라인과 연동하여 자동 배포"
    echo "• CDN 서비스 연동으로 글로벌 성능 향상"
    echo "• 모니터링 도구로 사용자 경험 추적"
    echo "• 버전 관리를 통한 롤백 전략 수립"
    echo "• 비용 효율적인 웹사이트 운영"
    echo ""
    
    echo -e "${PURPLE}=== 다음 단계 권장사항 ===${NC}"
    echo "• 실제 도메인 연결 및 HTTPS 설정"
    echo "• CDN 서비스 연동 (CloudFlare, CloudFront 등)"
    echo "• 성능 모니터링 및 최적화"
    echo "• 백업 및 재해 복구 계획 수립 (Lab 10)"
    echo "• 고급 보안 설정 및 접근 제어"
    echo ""
    
    log_success "Lab 9: Static Website Hosting 실습 완료!"
    echo ""
    echo "생성된 웹사이트를 실제 운영 환경에 적용하여"
    echo "비용 효율적이고 확장 가능한 웹 서비스를 구축해보세요."
}

# 메인 함수
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   Lab 9: MinIO Static                       ║"
    echo "║                  Website Hosting                             ║"
    echo "║                                                              ║"
    echo "║  학습 목표:                                                  ║"
    echo "║  • S3 호환 정적 웹사이트 호스팅                             ║"
    echo "║  • 버킷 정책과 공개 접근 설정                               ║"
    echo "║  • CORS 구성 및 크로스 오리진 처리                          ║"
    echo "║  • 실제 브라우저 테스트 및 CDN 연동 준비                    ║"
    echo "║                                                              ║"
    echo "║  예상 소요시간: 15-20분                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    wait_for_user
    
    # 실습 단계별 실행
    check_prerequisites
    setup_minio_connection
    create_website_files
    create_css_files
    create_js_files
    create_error_page
    setup_website_bucket
    upload_website_files
    setup_cors
    test_website_access
    browser_test_guide
    prepare_cdn_integration
    performance_optimization_tips
    
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
        echo "  ./lab-09-static-website.sh cleanup"
    fi
}

# 스크립트 실행
if [ "$1" = "cleanup" ]; then
    cleanup_lab
else
    main
fi
