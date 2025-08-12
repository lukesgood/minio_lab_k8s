#!/bin/bash

# Change PV Path Script - Quick Setup for Custom Storage Paths
# This script helps you change the default PV paths for better organization

set -e

echo "🔧 Change Persistent Volume Path Configuration"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CUSTOM_PATH=${1:-"/data/minio-storage"}
STORAGE_CLASS_NAME=${2:-"minio-local-storage"}

show_menu() {
    echo ""
    echo "Select PV path change method:"
    echo "1) Modify existing local-path-provisioner (affects all PVs)"
    echo "2) Create custom storage class with specific path"
    echo "3) Create manual PVs with custom paths"
    echo "4) Show current PV paths"
    echo "5) Cleanup test resources"
    echo "6) Exit"
    echo ""
}

modify_local_path_provisioner() {
    echo -e "${YELLOW}Modifying local-path-provisioner configuration...${NC}"
    echo "New path: $CUSTOM_PATH"
    
    # Create custom configuration
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["$CUSTOM_PATH"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0755 -p "\$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
EOF

    # Restart provisioner
    echo "Restarting local-path-provisioner..."
    kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
    kubectl rollout status deployment/local-path-provisioner -n local-path-storage
    
    echo -e "${GREEN}✅ Local-path-provisioner updated successfully${NC}"
    echo "All new PVs will be created in: $CUSTOM_PATH"
}

create_custom_storage_class() {
    echo -e "${YELLOW}Creating custom storage class: $STORAGE_CLASS_NAME${NC}"
    echo "Path: $CUSTOM_PATH"
    
    # Create custom storage class
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF

    # Create custom configmap for this storage class
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${STORAGE_CLASS_NAME}-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["$CUSTOM_PATH"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0755 -p "\$VOL_DIR"
    # Set proper ownership for MinIO
    chown 1000:1000 "\$VOL_DIR" 2>/dev/null || true
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
EOF

    echo -e "${GREEN}✅ Custom storage class created: $STORAGE_CLASS_NAME${NC}"
    echo "Use this storage class in your PVCs to use the custom path"
}

create_manual_pvs() {
    echo -e "${YELLOW}Creating manual PVs with custom paths...${NC}"
    
    # Get the first node name
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    # Create storage class for manual PVs
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-manual-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: false
EOF

    # Create 4 manual PVs for MinIO
    for i in {1..4}; do
        echo "Creating PV: minio-pv-${i}"
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-${i}
  labels:
    type: local
    app: minio
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-manual-storage
  hostPath:
    path: ${CUSTOM_PATH}/drive-${i}
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
EOF
    done
    
    echo -e "${GREEN}✅ Created 4 manual PVs with custom paths${NC}"
    echo "Storage class: minio-manual-storage"
    echo "Paths: ${CUSTOM_PATH}/drive-{1..4}"
}

show_current_paths() {
    echo -e "${BLUE}Current PV Configuration:${NC}"
    echo ""
    
    echo "Storage Classes:"
    kubectl get storageclass
    
    echo ""
    echo "Persistent Volumes:"
    if kubectl get pv &>/dev/null; then
        kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,PATH:.spec.hostPath.path,STATUS:.status.phase 2>/dev/null || \
        kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase
    else
        echo "No PVs found"
    fi
    
    echo ""
    echo "Local Path Provisioner Configuration:"
    if kubectl get configmap local-path-config -n local-path-storage &>/dev/null; then
        kubectl get configmap local-path-config -n local-path-storage -o jsonpath='{.data.config\.json}' | jq . 2>/dev/null || \
        kubectl get configmap local-path-config -n local-path-storage -o yaml
    else
        echo "Local path provisioner not found"
    fi
}

cleanup_test_resources() {
    echo -e "${YELLOW}Cleaning up test resources...${NC}"
    
    # Delete test PVCs and pods
    kubectl delete pod test-custom-path-pod --ignore-not-found=true
    kubectl delete pvc test-custom-path-pvc --ignore-not-found=true
    
    # Delete manual PVs
    for i in {1..4}; do
        kubectl delete pv minio-pv-${i} --ignore-not-found=true
    done
    
    # Delete custom storage classes
    kubectl delete storageclass minio-manual-storage --ignore-not-found=true
    kubectl delete storageclass $STORAGE_CLASS_NAME --ignore-not-found=true
    
    # Delete custom configmaps
    kubectl delete configmap ${STORAGE_CLASS_NAME}-config -n local-path-storage --ignore-not-found=true
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

test_custom_path() {
    echo -e "${BLUE}Testing custom path configuration...${NC}"
    
    # Create test PVC
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-custom-path-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: $STORAGE_CLASS_NAME
EOF

    # Create test pod
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-custom-path-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-custom-path-pvc
EOF

    echo "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/test-custom-path-pod --timeout=60s
    
    echo "Testing write to custom path..."
    kubectl exec test-custom-path-pod -- sh -c "echo 'Custom path test' > /data/test.txt"
    kubectl exec test-custom-path-pod -- cat /data/test.txt
    
    echo -e "${GREEN}✅ Custom path test successful${NC}"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter custom path (default: $CUSTOM_PATH): " input_path
            CUSTOM_PATH=${input_path:-$CUSTOM_PATH}
            modify_local_path_provisioner
            ;;
        2)
            echo ""
            read -p "Enter custom path (default: $CUSTOM_PATH): " input_path
            read -p "Enter storage class name (default: $STORAGE_CLASS_NAME): " input_sc
            CUSTOM_PATH=${input_path:-$CUSTOM_PATH}
            STORAGE_CLASS_NAME=${input_sc:-$STORAGE_CLASS_NAME}
            create_custom_storage_class
            echo ""
            read -p "Test the custom storage class? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                test_custom_path
            fi
            ;;
        3)
            echo ""
            read -p "Enter custom path (default: $CUSTOM_PATH): " input_path
            CUSTOM_PATH=${input_path:-$CUSTOM_PATH}
            create_manual_pvs
            ;;
        4)
            show_current_paths
            ;;
        5)
            cleanup_test_resources
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1-6.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
