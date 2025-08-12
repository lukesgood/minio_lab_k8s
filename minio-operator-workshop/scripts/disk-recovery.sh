#!/bin/bash

# MinIO Disk Recovery Script for Multi-Node Deployments
# Handles disk failure and replacement scenarios

set -e

echo "🚨 MinIO Disk Recovery Assistant"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo "Select recovery action:"
    echo "1) Assess disk failure situation"
    echo "2) Replace failed PV after disk replacement"
    echo "3) Initiate MinIO healing process"
    echo "4) Monitor healing progress"
    echo "5) Verify cluster health"
    echo "6) Generate incident report"
    echo "7) Exit"
    echo ""
}

assess_failure() {
    echo -e "${YELLOW}Assessing disk failure situation...${NC}"
    
    echo "1. Checking MinIO cluster health:"
    if mc admin info local >/dev/null 2>&1; then
        echo -e "✅ MinIO cluster is accessible"
        mc admin info local | head -10
    else
        echo -e "❌ MinIO cluster not accessible"
    fi
    
    echo ""
    echo "2. Checking PV status:"
    kubectl get pv | grep -E "(Failed|Pending|Available)" || echo "No failed PVs found"
    
    echo ""
    echo "3. Checking pod status:"
    kubectl get pods -n minio-tenant -o wide
    
    echo ""
    echo "4. Checking recent events:"
    kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | tail -10
    
    echo ""
    echo "5. Checking for offline drives:"
    if mc admin heal local --dry-run >/dev/null 2>&1; then
        mc admin heal local --dry-run | grep -E "(offline|online|healing)"
    else
        echo "Cannot check healing status - cluster may be degraded"
    fi
}

replace_pv() {
    echo -e "${YELLOW}PV Replacement Process${NC}"
    
    read -p "Enter the failed PV name: " FAILED_PV
    read -p "Enter the node name: " NODE_NAME
    read -p "Enter the disk path (e.g., /data/minio/drive-1): " DISK_PATH
    read -p "Enter storage size (e.g., 100Gi): " STORAGE_SIZE
    
    echo ""
    echo "Replacing PV: $FAILED_PV"
    echo "Node: $NODE_NAME"
    echo "Path: $DISK_PATH"
    echo "Size: $STORAGE_SIZE"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    # Delete failed PV
    echo "Deleting failed PV..."
    kubectl delete pv $FAILED_PV --ignore-not-found=true
    
    # Create replacement PV
    echo "Creating replacement PV..."
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${FAILED_PV}-replacement-$(date +%s)
  labels:
    type: local
    app: minio
spec:
  capacity:
    storage: $STORAGE_SIZE
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-local-storage
  hostPath:
    path: $DISK_PATH
    type: Directory
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
EOF
    
    echo -e "${GREEN}✅ Replacement PV created${NC}"
    
    # Restart affected pods
    echo "Restarting affected MinIO pods..."
    kubectl delete pods -l v1.min.io/tenant=minio -n minio-tenant --field-selector spec.nodeName=$NODE_NAME
    
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l v1.min.io/tenant=minio -n minio-tenant --timeout=300s
    
    echo -e "${GREEN}✅ PV replacement completed${NC}"
}

initiate_healing() {
    echo -e "${YELLOW}Initiating MinIO healing process...${NC}"
    
    echo "Starting recursive healing..."
    if mc admin heal local --recursive; then
        echo -e "${GREEN}✅ Healing process started${NC}"
    else
        echo -e "${RED}❌ Failed to start healing process${NC}"
    fi
    
    echo ""
    echo "Healing status:"
    mc admin heal local --dry-run
}

monitor_healing() {
    echo -e "${BLUE}Monitoring healing progress...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        echo "$(date): Checking healing status..."
        
        heal_output=$(mc admin heal local --dry-run 2>/dev/null)
        
        if echo "$heal_output" | grep -q "No healing required"; then
            echo -e "${GREEN}✅ Healing completed successfully!${NC}"
            break
        else
            echo "🔄 Healing in progress..."
            echo "$heal_output" | grep -E "(Healing|Objects|Drives)" | head -5
        fi
        
        sleep 30
        echo "---"
    done
}

verify_health() {
    echo -e "${BLUE}Verifying cluster health...${NC}"
    
    echo "1. Cluster information:"
    mc admin info local
    
    echo ""
    echo "2. Drive status:"
    mc admin heal local --dry-run | grep -E "(online|offline)"
    
    echo ""
    echo "3. Testing read/write operations:"
    test_file="health-test-$(date +%s).txt"
    echo "Health test $(date)" > $test_file
    
    if mc cp $test_file local/test-bucket/; then
        echo -e "✅ Write operation successful"
        
        if mc cat local/test-bucket/$test_file >/dev/null; then
            echo -e "✅ Read operation successful"
            mc rm local/test-bucket/$test_file
        else
            echo -e "❌ Read operation failed"
        fi
    else
        echo -e "❌ Write operation failed"
    fi
    
    rm -f $test_file
    
    echo ""
    echo "4. Performance test:"
    mc admin speedtest local --duration=30s
}

generate_report() {
    echo -e "${BLUE}Generating incident report...${NC}"
    
    report_file="disk-failure-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat << EOF > $report_file
# MinIO Disk Failure Incident Report

**Date**: $(date)
**Generated by**: MinIO Disk Recovery Script

## Cluster Status
\`\`\`
$(mc admin info local 2>/dev/null || echo "Cluster not accessible")
\`\`\`

## PV Status
\`\`\`
$(kubectl get pv)
\`\`\`

## Pod Status
\`\`\`
$(kubectl get pods -n minio-tenant -o wide)
\`\`\`

## Healing Status
\`\`\`
$(mc admin heal local --dry-run 2>/dev/null || echo "Healing status not available")
\`\`\`

## Recent Events
\`\`\`
$(kubectl get events -n minio-tenant --sort-by='.lastTimestamp' | tail -20)
\`\`\`

## Recovery Actions Taken
- [ ] Assessed failure situation
- [ ] Replaced physical disk
- [ ] Created replacement PV
- [ ] Restarted affected pods
- [ ] Initiated healing process
- [ ] Verified cluster health

## Recommendations
- Monitor disk health proactively
- Maintain spare disks for quick replacement
- Test recovery procedures regularly
- Update monitoring and alerting systems

---
Report generated at: $(date)
EOF
    
    echo -e "${GREEN}✅ Report generated: $report_file${NC}"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            assess_failure
            ;;
        2)
            replace_pv
            ;;
        3)
            initiate_healing
            ;;
        4)
            monitor_healing
            ;;
        5)
            verify_health
            ;;
        6)
            generate_report
            ;;
        7)
            echo "Recovery assistant closed."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1-7.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
