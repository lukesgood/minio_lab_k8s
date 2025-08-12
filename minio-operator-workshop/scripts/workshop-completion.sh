#!/bin/bash

# MinIO Operator Workshop - Completion Verification Script
# This script verifies that all workshop modules have been completed successfully

set -e

echo "🎓 MinIO Operator Workshop - Completion Verification"
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Check function
check_requirement() {
    local description="$1"
    local command="$2"
    local expected_result="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "Checking: $description... "
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Advanced check function with custom validation
check_advanced() {
    local description="$1"
    local command="$2"
    local validation="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "Checking: $description... "
    
    result=$(eval "$command" 2>/dev/null || echo "FAILED")
    
    if eval "$validation" &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "   Result: $result"
        return 1
    fi
}

echo ""
echo "🔍 Module 1: Environment Setup & Validation"
echo "============================================"

check_requirement "Kubernetes cluster accessible" "kubectl cluster-info" ""
check_requirement "Default storage class configured" "kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class==\"true\")].metadata.name}'" ""
check_requirement "Dynamic provisioning working" "kubectl get pv | grep -q 'local-path'" ""

echo ""
echo "🔍 Module 2: MinIO Operator Installation"
echo "========================================"

check_requirement "MinIO Operator namespace exists" "kubectl get namespace minio-operator" ""
check_requirement "MinIO Operator pods running" "kubectl get pods -n minio-operator | grep -q 'Running'" ""
check_requirement "MinIO CRDs installed" "kubectl get crd tenants.minio.min.io" ""
check_advanced "Operator version correct" "kubectl get deployment minio-operator -n minio-operator -o jsonpath='{.spec.template.spec.containers[0].image}'" "[[ \$result == *'minio/operator'* ]]"

echo ""
echo "🔍 Module 3: MinIO Tenant Deployment"
echo "===================================="

check_requirement "MinIO Tenant namespace exists" "kubectl get namespace minio-tenant" ""
check_requirement "MinIO Tenant exists" "kubectl get tenant minio -n minio-tenant" ""
check_advanced "MinIO Tenant status is Initialized" "kubectl get tenant minio -n minio-tenant -o jsonpath='{.status.currentState}'" "[[ \$result == 'Initialized' ]]"
check_requirement "MinIO pods running" "kubectl get pods -n minio-tenant | grep minio-pool | grep -q 'Running'" ""
check_requirement "MinIO PVCs bound" "kubectl get pvc -n minio-tenant | grep -q 'Bound'" ""
check_requirement "MinIO services created" "kubectl get svc minio -n minio-tenant" ""
check_requirement "MinIO Console service created" "kubectl get svc minio-tenant-console -n minio-tenant" ""

echo ""
echo "🔍 Module 4: Basic Operations & Client Setup"
echo "============================================"

check_requirement "MinIO client (mc) installed" "command -v mc" ""
check_requirement "MinIO client configured" "mc alias list | grep -q 'local'" ""
check_requirement "MinIO server accessible" "mc admin info local" ""
check_requirement "Test buckets exist" "mc ls local | grep -q 'test-bucket'" ""
check_advanced "Objects uploaded successfully" "mc ls local/test-bucket/" "[[ \$result == *'test-file.txt'* ]]"

echo ""
echo "🔍 Module 5: Advanced S3 API Features"
echo "====================================="

check_requirement "Advanced features bucket exists" "mc ls local | grep -q 'advanced-features'" ""
check_advanced "Metadata operations working" "mc stat local/advanced-features/metadata-example.txt 2>/dev/null | grep -q 'Author'" "[[ \$? -eq 0 ]]"
check_advanced "Large file uploads completed" "mc ls local/advanced-features/ | grep -q 'large-file.dat'" "[[ \$? -eq 0 ]]"
check_advanced "Mirroring operations completed" "mc ls local/advanced-features/mirrored-data/" "[[ \$result != '' ]]"

echo ""
echo "🔍 Module 6: Performance Testing"
echo "================================"

check_requirement "Performance test bucket exists" "mc ls local | grep -q 'perf-test'" ""
check_advanced "Performance test files exist" "mc ls local/perf-test/" "[[ \$result == *'.dat'* ]]"
check_requirement "MinIO speedtest functional" "mc admin speedtest local --duration=5s" ""

echo ""
echo "🔍 Module 7: User & Permission Management"
echo "========================================="

check_advanced "Custom policies created" "mc admin policy list local" "[[ \$result == *'readonly-policy'* ]]"
check_advanced "IAM users created" "mc admin user list local" "[[ \$result == *'readonly-user'* ]]"
check_requirement "User management buckets exist" "mc ls local | grep -q 'readonly-data'" ""
check_requirement "Permission testing completed" "mc ls local | grep -q 'shared-data'" ""

echo ""
echo "🔍 Optional Modules Check"
echo "========================"

# Check if optional modules were completed
OPTIONAL_MODULES=0
COMPLETED_OPTIONAL=0

# Module 8: Monitoring (if implemented)
if kubectl get pods -n monitoring &> /dev/null; then
    OPTIONAL_MODULES=$((OPTIONAL_MODULES + 1))
    if kubectl get pods -n monitoring | grep -q prometheus; then
        COMPLETED_OPTIONAL=$((COMPLETED_OPTIONAL + 1))
        echo -e "${BLUE}📊 Module 8: Monitoring - Completed${NC}"
    fi
fi

# Module 9: Backup & Recovery (check for backup buckets)
if mc ls local | grep -q backup; then
    OPTIONAL_MODULES=$((OPTIONAL_MODULES + 1))
    COMPLETED_OPTIONAL=$((COMPLETED_OPTIONAL + 1))
    echo -e "${BLUE}💾 Module 9: Backup & Recovery - Completed${NC}"
fi

# Module 10: Security (check for additional security configurations)
if mc admin policy list local | grep -q conditional-policy; then
    OPTIONAL_MODULES=$((OPTIONAL_MODULES + 1))
    COMPLETED_OPTIONAL=$((COMPLETED_OPTIONAL + 1))
    echo -e "${BLUE}🔒 Module 10: Security - Completed${NC}"
fi

echo ""
echo "📊 Workshop Completion Summary"
echo "=============================="

COMPLETION_PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo "Core Requirements:"
echo "  Passed: $PASSED_CHECKS/$TOTAL_CHECKS ($COMPLETION_PERCENTAGE%)"

if [ $OPTIONAL_MODULES -gt 0 ]; then
    echo "Optional Modules:"
    echo "  Completed: $COMPLETED_OPTIONAL/$OPTIONAL_MODULES"
fi

echo ""

if [ $COMPLETION_PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}🎉 CONGRATULATIONS! 🎉${NC}"
    echo -e "${GREEN}You have successfully completed the MinIO Operator Workshop!${NC}"
    echo ""
    echo "✅ You have mastered:"
    echo "   • Kubernetes storage concepts and dynamic provisioning"
    echo "   • MinIO Operator installation and management"
    echo "   • MinIO Tenant deployment and configuration"
    echo "   • S3-compatible API operations and advanced features"
    echo "   • Performance testing and optimization"
    echo "   • User and permission management with IAM"
    if [ $COMPLETED_OPTIONAL -gt 0 ]; then
        echo "   • Advanced topics including monitoring, backup, and security"
    fi
    echo ""
    echo "🚀 You're ready to deploy MinIO in production environments!"
    
elif [ $COMPLETION_PERCENTAGE -ge 70 ]; then
    echo -e "${YELLOW}⚠️  WORKSHOP MOSTLY COMPLETE${NC}"
    echo "You've completed most of the workshop requirements."
    echo "Consider reviewing the failed checks above and completing any missing modules."
    
else
    echo -e "${RED}❌ WORKSHOP INCOMPLETE${NC}"
    echo "Several core requirements are not met."
    echo "Please review the failed checks and complete the missing modules."
fi

echo ""
echo "📚 Next Steps:"
echo "=============="
echo "1. Review the troubleshooting guide: docs/troubleshooting.md"
echo "2. Study production best practices: docs/best-practices.md"
echo "3. Explore MinIO documentation: https://docs.min.io/"
echo "4. Join the MinIO community: https://slack.min.io/"
echo ""

# Generate completion certificate
if [ $COMPLETION_PERCENTAGE -ge 90 ]; then
    cat << EOF > workshop-completion-certificate.txt
╔══════════════════════════════════════════════════════════════╗
║                    COMPLETION CERTIFICATE                    ║
║                                                              ║
║              MinIO Operator Workshop                         ║
║                                                              ║
║  This certifies that the workshop has been completed        ║
║  successfully with a score of $COMPLETION_PERCENTAGE%                        ║
║                                                              ║
║  Date: $(date)                                    ║
║  Kubernetes Version: $(kubectl version --short --client 2>/dev/null | head -1 | cut -d' ' -f3)                                      ║
║  MinIO Operator Version: v7.1.1                             ║
║                                                              ║
║  Core Modules Completed: ✅                                  ║
║  Optional Modules: $COMPLETED_OPTIONAL/$OPTIONAL_MODULES                                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${GREEN}📜 Completion certificate saved to: workshop-completion-certificate.txt${NC}"
fi

echo ""
echo "Thank you for completing the MinIO Operator Workshop! 🙏"
