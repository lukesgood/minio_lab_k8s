#!/bin/bash

# Dynamic PVC Setup Script for MinIO Operator Workshop
# Automates the setup of dynamic PVC provisioning

set -e

echo "🚀 Dynamic PVC Setup Assistant"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo "Select dynamic provisioning setup:"
    echo "1) Local Path Provisioner (single node)"
    echo "2) NFS Dynamic Provisioner (multi-node)"
    echo "3) Cloud Provider (AWS/GCP/Azure)"
    echo "4) Test dynamic provisioning"
    echo "5) Monitor provisioning status"
    echo "6) Cleanup test resources"
    echo "7) Exit"
    echo ""
}

setup_local_path() {
    echo -e "${YELLOW}Setting up Local Path Provisioner...${NC}"
    
    read -p "Enter storage path (default: /data/dynamic-storage): " STORAGE_PATH
    STORAGE_PATH=${STORAGE_PATH:-"/data/dynamic-storage"}
    
    read -p "Set as default storage class? (y/N): " -n 1 -r
    echo
    DEFAULT_CLASS="false"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DEFAULT_CLASS="true"
    fi
    
    # Install local-path provisioner if not exists
    if ! kubectl get deployment local-path-provisioner -n local-path-storage >/dev/null 2>&1; then
        echo "Installing local-path provisioner..."
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
        
        echo "Waiting for provisioner to be ready..."
        kubectl wait --for=condition=available deployment/local-path-provisioner -n local-path-storage --timeout=120s
    fi
    
    # Create storage class
    echo "Creating dynamic storage class..."
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dynamic-local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "$DEFAULT_CLASS"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
    
    # Configure provisioner path
    echo "Configuring storage path: $STORAGE_PATH"
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
          "paths": ["$STORAGE_PATH"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0755 -p "\$VOL_DIR"
    chown 1000:1000 "\$VOL_DIR" 2>/dev/null || true
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
EOF
    
    # Restart provisioner
    echo "Restarting provisioner to apply configuration..."
    kubectl rollout restart deployment/local-path-provisioner -n local-path-storage
    kubectl rollout status deployment/local-path-provisioner -n local-path-storage
    
    echo -e "${GREEN}✅ Local Path Provisioner setup completed${NC}"
    echo "Storage Class: dynamic-local-storage"
    echo "Storage Path: $STORAGE_PATH"
}

setup_nfs() {
    echo -e "${YELLOW}Setting up NFS Dynamic Provisioner...${NC}"
    
    read -p "Enter NFS server IP: " NFS_SERVER
    read -p "Enter NFS export path: " NFS_PATH
    read -p "Enter storage class name (default: nfs-dynamic): " SC_NAME
    SC_NAME=${SC_NAME:-"nfs-dynamic"}
    
    if [ -z "$NFS_SERVER" ] || [ -z "$NFS_PATH" ]; then
        echo -e "${RED}NFS server and path are required${NC}"
        return 1
    fi
    
    # Check if Helm is available
    if command -v helm >/dev/null 2>&1; then
        echo "Installing NFS provisioner via Helm..."
        helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ 2>/dev/null || true
        helm repo update
        
        helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
          --set nfs.server=$NFS_SERVER \
          --set nfs.path=$NFS_PATH \
          --set storageClass.name=$SC_NAME \
          --set storageClass.defaultClass=false
    else
        echo "Installing NFS provisioner manually..."
        # Create RBAC
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
      - name: nfs-client-provisioner
        image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
        volumeMounts:
        - name: nfs-client-root
          mountPath: /persistentvolumes
        env:
        - name: PROVISIONER_NAME
          value: k8s-sigs.io/nfs-subdir-external-provisioner
        - name: NFS_SERVER
          value: $NFS_SERVER
        - name: NFS_PATH
          value: $NFS_PATH
      volumes:
      - name: nfs-client-root
        nfs:
          server: $NFS_SERVER
          path: $NFS_PATH
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $SC_NAME
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF
    fi
    
    echo -e "${GREEN}✅ NFS Dynamic Provisioner setup completed${NC}"
    echo "Storage Class: $SC_NAME"
    echo "NFS Server: $NFS_SERVER"
    echo "NFS Path: $NFS_PATH"
}

setup_cloud() {
    echo -e "${YELLOW}Setting up Cloud Provider Dynamic Provisioning...${NC}"
    
    echo "Select cloud provider:"
    echo "1) AWS EBS"
    echo "2) Google Cloud Persistent Disk"
    echo "3) Azure Disk"
    read -p "Enter choice (1-3): " cloud_choice
    
    case $cloud_choice in
        1)
            echo "Creating AWS EBS storage class..."
            cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-ebs-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
EOF
            echo -e "${GREEN}✅ AWS EBS storage class created${NC}"
            ;;
        2)
            echo "Creating GCP Persistent Disk storage class..."
            cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-pd-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: pd.csi.storage.gke.io
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: pd-ssd
  replication-type: regional-pd
EOF
            echo -e "${GREEN}✅ GCP Persistent Disk storage class created${NC}"
            ;;
        3)
            echo "Creating Azure Disk storage class..."
            cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-dynamic
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: disk.csi.azure.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  skuName: Premium_LRS
  kind: Managed
EOF
            echo -e "${GREEN}✅ Azure Disk storage class created${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

test_provisioning() {
    echo -e "${BLUE}Testing dynamic provisioning...${NC}"
    
    # List available storage classes
    echo "Available storage classes:"
    kubectl get storageclass
    
    read -p "Enter storage class name to test: " SC_NAME
    if [ -z "$SC_NAME" ]; then
        echo -e "${RED}Storage class name required${NC}"
        return 1
    fi
    
    # Create test PVC
    echo "Creating test PVC..."
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-dynamic-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: $SC_NAME
EOF
    
    echo "PVC created. Status:"
    kubectl get pvc test-dynamic-pvc
    
    # Create test pod
    echo "Creating test pod to trigger provisioning..."
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-dynamic-pod
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
      claimName: test-dynamic-pvc
EOF
    
    echo "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/test-dynamic-pod --timeout=120s
    
    echo "Testing write to dynamic volume..."
    kubectl exec test-dynamic-pod -- sh -c "echo 'Dynamic provisioning test' > /data/test.txt"
    kubectl exec test-dynamic-pod -- cat /data/test.txt
    
    echo ""
    echo "Final status:"
    kubectl get pvc test-dynamic-pvc
    kubectl get pv
    
    echo -e "${GREEN}✅ Dynamic provisioning test completed${NC}"
}

monitor_status() {
    echo -e "${BLUE}Monitoring provisioning status...${NC}"
    
    echo "Storage Classes:"
    kubectl get storageclass -o wide
    
    echo ""
    echo "PVC Status:"
    kubectl get pvc --all-namespaces -o wide
    
    echo ""
    echo "PV Status:"
    kubectl get pv -o wide
    
    echo ""
    echo "Provisioner Pods:"
    kubectl get pods -n local-path-storage 2>/dev/null || echo "Local path provisioner not found"
    kubectl get pods | grep nfs-client-provisioner || echo "NFS provisioner not found"
    
    echo ""
    echo "Recent Events:"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -E "(Provisioning|VolumeBinding)" | tail -10
}

cleanup_test() {
    echo -e "${YELLOW}Cleaning up test resources...${NC}"
    
    kubectl delete pod test-dynamic-pod --ignore-not-found=true
    kubectl delete pvc test-dynamic-pvc --ignore-not-found=true
    
    # Clean up any test PVs that might be left
    kubectl get pv | grep "test-dynamic" | awk '{print $1}' | xargs -r kubectl delete pv
    
    echo -e "${GREEN}✅ Test resources cleaned up${NC}"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            setup_local_path
            ;;
        2)
            setup_nfs
            ;;
        3)
            setup_cloud
            ;;
        4)
            test_provisioning
            ;;
        5)
            monitor_status
            ;;
        6)
            cleanup_test
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1-7.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
