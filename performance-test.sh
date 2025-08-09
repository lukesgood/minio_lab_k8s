#!/bin/bash

echo "=== MinIO 성능 테스트 ==="

# 테스트 데이터 생성
echo "테스트 파일 생성 중..."
dd if=/dev/zero of=test-1mb.dat bs=1M count=1
dd if=/dev/zero of=test-10mb.dat bs=1M count=10
dd if=/dev/zero of=test-100mb.dat bs=1M count=100

# MinIO 별칭 설정 (사전에 포트 포워딩 필요)
mc alias set minio-test http://localhost:9000 admin password123

# 테스트 버킷 생성
mc mb minio-test/performance-test

echo ""
echo "=== 업로드 성능 테스트 ==="
time mc cp test-1mb.dat minio-test/performance-test/
time mc cp test-10mb.dat minio-test/performance-test/
time mc cp test-100mb.dat minio-test/performance-test/

echo ""
echo "=== 다운로드 성능 테스트 ==="
time mc cp minio-test/performance-test/test-1mb.dat ./download-1mb.dat
time mc cp minio-test/performance-test/test-10mb.dat ./download-10mb.dat
time mc cp minio-test/performance-test/test-100mb.dat ./download-100mb.dat

echo ""
echo "=== 병렬 업로드 테스트 ==="
for i in {1..5}; do
  cp test-10mb.dat test-10mb-$i.dat
  mc cp test-10mb-$i.dat minio-test/performance-test/ &
done
wait

echo ""
echo "=== 서버 성능 정보 ==="
mc admin info minio-test

echo ""
echo "=== 내장 성능 테스트 ==="
mc speed test minio-test

# 정리
rm -f test-*.dat download-*.dat
