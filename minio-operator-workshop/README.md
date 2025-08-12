# MinIO Operator Workshop

## 🎯 Workshop Overview

This comprehensive workshop teaches you how to deploy and operate MinIO object storage in Kubernetes using the MinIO Operator. You'll learn production-ready practices and troubleshooting techniques through hands-on exercises.

## 📚 Learning Objectives

- Deploy MinIO Operator using Kubernetes-native approaches
- Manage S3-compatible object storage with MinIO
- Implement user and permission management systems
- Develop operational troubleshooting skills for production environments

## 🏗️ Workshop Structure

### Prerequisites
- Kubernetes cluster (1.20+)
- kubectl configured and working
- Basic understanding of Kubernetes concepts
- 4GB RAM, 2 CPU cores minimum

### Workshop Modules

#### 🚀 Foundation (Required)
- **Module 1**: [Environment Setup & Validation](modules/01-environment-setup/)
- **Module 2**: [MinIO Operator Installation](modules/02-operator-installation/)
- **Module 3**: [MinIO Tenant Deployment](modules/03-tenant-deployment/)
- **Module 4**: [Basic Operations & Client Setup](modules/04-basic-operations/)

#### 🔧 Intermediate (Recommended)
- **Module 5**: [Advanced S3 API Features](modules/05-advanced-s3/)
- **Module 6**: [Performance Testing & Optimization](modules/06-performance-testing/)
- **Module 7**: [User & Permission Management](modules/07-user-management/)

#### 🎓 Advanced (Optional)
- **Module 8**: [Monitoring & Observability](modules/08-monitoring/) - ✅ Complete
- **Module 9**: [Backup & Disaster Recovery](modules/09-backup-recovery/) - ✅ Complete
- **Module 10**: [Security Hardening](modules/10-security/) - ✅ Complete
- **Module 11**: [Production Operations](modules/11-production-ops/) - ✅ Complete

## ⏱️ Time Estimates

- **Foundation Modules**: 90-120 minutes
- **Intermediate Modules**: 60-90 minutes  
- **Advanced Modules**: 120-180 minutes
- **Total Workshop**: 4-6 hours (complete)

## 🚀 Quick Start

```bash
# 1. Clone the workshop
git clone <repository-url>
cd minio-operator-workshop

# 2. Verify prerequisites
./scripts/check-prerequisites.sh

# 3. Start with Module 1
cd modules/01-environment-setup
cat README.md
```

## 📋 Workshop Completion Checklist

- [ ] Environment validated and ready
- [ ] MinIO Operator successfully installed
- [ ] MinIO Tenant deployed and accessible
- [ ] Basic S3 operations working
- [ ] Performance benchmarks completed
- [ ] User management configured
- [ ] Monitoring setup (optional)
- [ ] Backup strategy implemented (optional)

## 🔧 Version Information

- **MinIO Operator**: v7.1.1
- **MinIO Server**: RELEASE.2025-04-08T15-41-24Z
- **Kubernetes**: 1.20+ (tested on v1.28.15)
- **CRD API**: minio.min.io/v2

## 📖 Additional Resources

- [Official MinIO Documentation](https://docs.min.io/)
- [MinIO Operator GitHub](https://github.com/minio/operator)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Best Practices](docs/best-practices.md)

## 🤝 Support

If you encounter issues during the workshop:
1. Check the [troubleshooting guide](docs/troubleshooting.md)
2. Review module-specific FAQ sections
3. Open an issue in the repository

---

**Ready to start?** Begin with [Module 1: Environment Setup](modules/01-environment-setup/)
