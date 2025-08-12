## Step 2: MinIO 권장 로컬 스토리지 구성

### 💡 개념 설명

MinIO의 핵심 권장사항인 **로컬 연결 스토리지**를 구성합니다. 이는 최고의 성능과 안정성을 제공합니다.

### 🔍 워커 노드별 스토리지 준비

```bash
echo "=== 워커 노드 스토리지 준비 ==="

# 워커 노드 목록 가져오기
WORKER_NODES=($(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=":metadata.name"))

echo "워커 노드 목록: ${WORKER_NODES[@]}"
echo "총 워커 노드 수: ${#WORKER_NODES[@]}"

# 각 워커 노드에 MinIO 전용 스토리지 디렉토리 생성
for node in "${WORKER_NODES[@]}"; do
    echo "=== 노드 $node 스토리지 설정 ==="
    
    # Multipass 환경인 경우
    if multipass list 2>/dev/null | grep -q "$node"; then
        echo "Multipass 노드 $node 설정 중..."
        
        # MinIO 전용 디렉토리 생성
        multipass exec "$node" -- sudo mkdir -p /mnt/minio-storage/disk1 /mnt/minio-storage/disk2
        
        # MinIO 사용자 권한 설정 (UID:GID = 1000:1000)
        multipass exec "$node" -- sudo chown -R 1000:1000 /mnt/minio-storage/
        
        # 성능 최적화를 위한 마운트 옵션 설정 (실제 디스크가 있는 경우)
        # multipass exec "$node" -- sudo mount -o noatime,nodiratime /dev/sdb1 /mnt/minio-storage/disk1
        # multipass exec "$node" -- sudo mount -o noatime,nodiratime /dev/sdc1 /mnt/minio-storage/disk2
        
        echo "✅ 노드 $node 스토리지 설정 완료"
    else
        echo "⚠️  노드 $node에 직접 접근하여 다음 명령어를 실행하세요:"
        echo "sudo mkdir -p /mnt/minio-storage/disk1 /mnt/minio-storage/disk2"
        echo "sudo chown -R 1000:1000 /mnt/minio-storage/"
        echo ""
    fi
done
```

### 🏗️ MinIO 최적화 스토리지 클래스 생성

```bash
echo "=== MinIO 최적화 스토리지 클래스 생성 ==="

cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    # MinIO 최적화 어노테이션
    minio.min.io/optimized: "true"
    minio.min.io/storage-type: "local-attached"
    minio.min.io/performance-tier: "high"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: false
parameters:
  # 성능 최적화 파라미터
  fsType: "ext4"
  # 추가 마운트 옵션 (성능 최적화)
  mountOptions: "noatime,nodiratime"
EOF

echo "✅ MinIO 최적화 스토리지 클래스 생성 완료"
```

### 📦 워커 노드별 Local Persistent Volume 생성

```bash
echo "=== 워커 노드별 Local PV 생성 ==="

# 각 워커 노드에 대해 PV 생성
for i in "${!WORKER_NODES[@]}"; do
    node="${WORKER_NODES[$i]}"
    
    echo "노드 $node에 대한 PV 생성 중..."
    
    # 각 노드에 2개의 디스크 PV 생성 (MinIO 권장)
    for disk in 1 2; do
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-local-pv-${node}-disk${disk}
  labels:
    minio.min.io/node: "${node}"
    minio.min.io/disk: "disk${disk}"
    minio.min.io/storage-type: "local-attached"
    minio.min.io/performance-tier: "high"
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: minio-local-storage
  local:
    path: /mnt/minio-storage/disk${disk}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - ${node}
EOF
    done
    
    echo "✅ 노드 $node PV 생성 완료"
done

echo "=== Local PV 생성 완료 ==="
```

### 🔍 스토리지 구성 검증

```bash
echo "=== 스토리지 구성 검증 ==="

# 1. 스토리지 클래스 확인
echo "1. 스토리지 클래스:"
kubectl get storageclass minio-local-storage

# 2. 생성된 PV 확인
echo -e "\n2. 생성된 Local PV:"
kubectl get pv -l minio.min.io/storage-type=local-attached

# 3. PV 상세 정보
echo -e "\n3. PV 상세 정보:"
kubectl get pv -l minio.min.io/storage-type=local-attached -o wide

# 4. 노드별 PV 분포 확인
echo -e "\n4. 노드별 PV 분포:"
for node in "${WORKER_NODES[@]}"; do
    pv_count=$(kubectl get pv -l minio.min.io/node=$node --no-headers | wc -l)
    echo "노드 $node: ${pv_count}개 PV"
done

# 5. 총 스토리지 용량 계산
total_pvs=$(kubectl get pv -l minio.min.io/storage-type=local-attached --no-headers | wc -l)
total_capacity=$((total_pvs * 100))
echo -e "\n5. 총 스토리지 구성:"
echo "총 PV 수: ${total_pvs}개"
echo "총 용량: ${total_capacity}Gi"
echo "예상 사용 가능 용량 (EC:2): $((total_capacity / 2))Gi"
```

### 🛑 체크포인트
- [ ] 모든 워커 노드에 스토리지 디렉토리 생성
- [ ] MinIO 최적화 스토리지 클래스 생성
- [ ] 워커 노드별 Local PV 생성 (노드당 2개)
- [ ] 모든 PV가 Available 상태
