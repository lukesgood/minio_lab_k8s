#!/bin/bash

echo "=== MinIO Client (mc) 설정 ==="

# MinIO Client 다운로드
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# 별칭 설정 (포트 포워딩 후 실행)
echo "포트 포워딩 후 다음 명령어 실행:"
echo "mc alias set minio-local http://localhost:9000 admin password123"

echo ""
echo "=== 기본 명령어 예제 ==="
echo "# 버킷 목록 확인"
echo "mc ls minio-local"
echo ""
echo "# 버킷 생성"
echo "mc mb minio-local/test-bucket"
echo ""
echo "# 파일 업로드"
echo "mc cp /path/to/file minio-local/test-bucket/"
echo ""
echo "# 서버 정보 확인"
echo "mc admin info minio-local"
echo ""
echo "# 성능 테스트"
echo "mc speed test minio-local"
