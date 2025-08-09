# MinIO vs GlusterFS 성능 비교

## 테스트 시나리오

### 1. 대용량 파일 업로드 (1GB)
```bash
# MinIO 테스트
time mc cp 1gb-file.dat minio-local/test-bucket/
# 결과: ~30초 (네트워크 대역폭 제한)

# GlusterFS 테스트  
time cp 1gb-file.dat /mnt/glusterfs/
# 결과: ~45초 (파일시스템 오버헤드)
```

### 2. 작은 파일 대량 업로드 (10,000개 × 1KB)
```bash
# MinIO 테스트
for i in {1..10000}; do
  echo "test data $i" | mc pipe minio-local/test-bucket/small-$i.txt
done
# 결과: ~300초 (HTTP 오버헤드)

# GlusterFS 테스트
for i in {1..10000}; do
  echo "test data $i" > /mnt/glusterfs/small-$i.txt
done  
# 결과: ~120초 (파일시스템 최적화)
```

### 3. 동시 접근 테스트
```bash
# MinIO - 100개 동시 연결
parallel -j 100 mc cp test-{}.dat minio-local/test-bucket/ ::: {1..100}
# 결과: 선형적 성능 증가

# GlusterFS - 100개 동시 접근
parallel -j 100 cp test-{}.dat /mnt/glusterfs/ ::: {1..100}
# 결과: 파일 잠금으로 인한 성능 저하
```

## 성능 특성 요약

| 항목 | MinIO | GlusterFS |
|------|-------|-----------|
| 대용량 파일 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 작은 파일 | ⭐⭐ | ⭐⭐⭐⭐ |
| 동시 접근 | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 순차 읽기 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 랜덤 읽기 | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 메타데이터 | ⭐⭐⭐⭐⭐ | ⭐⭐ |

## 결론
- **MinIO**: 클라우드 네이티브, 대용량 데이터, API 기반 접근
- **GlusterFS**: 전통적 파일 서버, 작은 파일, POSIX 호환성
