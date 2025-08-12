#!/bin/bash

# Change PV Path Script for MinIO Operator Workshop
# Quick setup for custom storage paths

set -e

echo "🔧 Change Persistent Volume Path Configuration"
echo "=============================================="

CUSTOM_PATH=${1:-"/data/minio-storage"}
STORAGE_CLASS_NAME=${2:-"minio-local-storage"}

show_menu() {
    echo ""
    echo "Select PV path change method:"
    echo "1) Create custom storage class with specific path"
    echo "2) Create manual PVs with custom paths"
    echo "3) Show current PV paths"
    echo "4) Exit"
    echo ""
}

create_custom_storage_class() {
    echo "Creating custom storage class: $STORAGE_CLASS_NAME"
    echo "Path: $CUSTOM_PATH"
    
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS_NAME
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF

    echo "✅ Custom storage class created: $STORAGE_CLASS_NAME"
}

create_manual_pvs() {
    echo "Creating manual PVs with custom paths..."
    
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    for i in {1..4}; do
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-${i}
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
    
    echo "✅ Created 4 manual PVs with custom paths"
}

show_current_paths() {
    echo "Current PV Configuration:"
    echo ""
    
    echo "Storage Classes:"
    kubectl get storageclass
    
    echo ""
    echo "Persistent Volumes:"
    kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.hostPath.path,STATUS:.status.phase 2>/dev/null || \
    kubectl get pv
}

# Main menu
while true; do
    show_menu
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            create_custom_storage_class
            ;;
        2)
            create_manual_pvs
            ;;
        3)
            show_current_paths
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1-4."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
