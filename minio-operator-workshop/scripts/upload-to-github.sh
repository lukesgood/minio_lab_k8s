#!/bin/bash

# MinIO Operator Workshop - GitHub Upload Script
# This script automates the process of uploading the workshop to GitHub

set -e

echo "🚀 MinIO Operator Workshop - GitHub Upload"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get GitHub username and repository name
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter repository name (default: minio-operator-workshop): " REPO_NAME
REPO_NAME=${REPO_NAME:-minio-operator-workshop}

echo ""
echo -e "${BLUE}Repository will be created at: https://github.com/$GITHUB_USERNAME/$REPO_NAME${NC}"
echo ""

# Confirm before proceeding
read -p "Continue with upload? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Upload cancelled."
    exit 1
fi

echo ""
echo "📋 Pre-upload preparation..."

# Navigate to workshop directory
cd "$(dirname "$0")/.."

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    echo "Creating .gitignore..."
    cat << 'EOF' > .gitignore
# Temporary files
*.tmp
*.log
*~

# Test files
test-*.txt
test-*.dat
downloaded-*
backup-test-data/
local-data/
local-docs/
batch-test/
batch-download/

# Kubernetes generated files
*.yaml.bak
*-backup-*.yaml

# Workshop generated files
backup-manifest-*.txt
performance-baseline.txt
workshop-completion-certificate.txt

# Certificate files (workshop generates these)
*.key
*.crt
*.csr
*.conf

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Git files
.git/
EOF
    echo "✅ .gitignore created"
fi

# Create LICENSE if it doesn't exist
if [ ! -f LICENSE ]; then
    echo "Creating MIT LICENSE..."
    cat << 'EOF' > LICENSE
MIT License

Copyright (c) 2025 MinIO Operator Workshop

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    echo "✅ LICENSE created"
fi

# Create CONTRIBUTING.md if it doesn't exist
if [ ! -f CONTRIBUTING.md ]; then
    echo "Creating CONTRIBUTING.md..."
    cat << 'EOF' > CONTRIBUTING.md
# Contributing to MinIO Operator Workshop

Thank you for your interest in contributing to the MinIO Operator Workshop!

## How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or request features
- Provide detailed information about your environment
- Include steps to reproduce the issue

### Submitting Changes
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and test thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Module Improvements
- Test all commands and procedures
- Update validation checklists
- Maintain consistency with existing style
- Add troubleshooting sections for new issues

## Questions?

Feel free to open an issue for questions about contributing.
EOF
    echo "✅ CONTRIBUTING.md created"
fi

# Check for sensitive information
echo ""
echo "🔍 Checking for sensitive information..."
if grep -r -i "password\|secret\|key" . --exclude-dir=.git --exclude="*.md" --exclude="LICENSE" --exclude=".gitignore" | grep -v "password123\|SecurePassword123\|backup123456" | grep -v "example\|placeholder\|template"; then
    echo -e "${RED}⚠️  Potential sensitive information found above.${NC}"
    echo "Please review and remove any real passwords, keys, or secrets."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Upload cancelled for security review."
        exit 1
    fi
else
    echo "✅ No sensitive information detected"
fi

# Initialize git repository if not already initialized
if [ ! -d .git ]; then
    echo ""
    echo "📦 Initializing git repository..."
    git init
    echo "✅ Git repository initialized"
fi

# Add all files
echo ""
echo "📁 Adding files to git..."
git add .

# Create commit
echo ""
echo "💾 Creating commit..."
git commit -m "Initial commit: Complete MinIO Operator Workshop

- 11 comprehensive modules (Foundation + Intermediate + Advanced)
- Production-ready deployment guides with MinIO Operator v7.1.1
- Automated scripts for prerequisites, completion, and cleanup
- Comprehensive troubleshooting and best practices documentation
- Real-time learning with hands-on validation
- Covers deployment, security, monitoring, backup, and SRE practices

Modules:
Foundation (Required):
- Environment Setup & Validation
- MinIO Operator Installation  
- MinIO Tenant Deployment
- Basic Operations & Client Setup

Intermediate (Recommended):
- Advanced S3 API Features
- Performance Testing & Optimization
- User & Permission Management

Advanced (Optional):
- Monitoring & Observability
- Backup & Disaster Recovery
- Security Hardening
- Production Operations

Features:
- Real-time dynamic provisioning observation
- Kubernetes-native object storage mastery
- S3-compatible API expertise
- Enterprise security and compliance
- Production operations and SRE practices"

echo "✅ Commit created"

# Add remote origin
echo ""
echo "🔗 Adding GitHub remote..."
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/$GITHUB_USERNAME/$REPO_NAME.git
echo "✅ Remote added: https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

# Set main branch
git branch -M main

echo ""
echo -e "${YELLOW}📤 Ready to push to GitHub!${NC}"
echo ""
echo "Next steps:"
echo "1. Create the repository on GitHub:"
echo "   - Go to https://github.com/new"
echo "   - Repository name: $REPO_NAME"
echo "   - Description: Comprehensive MinIO Operator Workshop - Learn Kubernetes-native object storage"
echo "   - Make it Public (recommended)"
echo "   - Don't initialize with README (we have files already)"
echo ""
echo "2. After creating the repository, run:"
echo "   git push -u origin main"
echo ""

# Offer to open GitHub in browser
read -p "Open GitHub repository creation page in browser? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v xdg-open > /dev/null; then
        xdg-open "https://github.com/new"
    elif command -v open > /dev/null; then
        open "https://github.com/new"
    else
        echo "Please manually open: https://github.com/new"
    fi
fi

# Offer to push automatically
echo ""
read -p "Push to GitHub now? (repository must be created first) (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Pushing to GitHub..."
    
    if git push -u origin main; then
        echo ""
        echo -e "${GREEN}🎉 Successfully uploaded to GitHub!${NC}"
        echo ""
        echo "Your workshop is now available at:"
        echo "https://github.com/$GITHUB_USERNAME/$REPO_NAME"
        echo ""
        echo "Recommended next steps:"
        echo "1. Add repository description and topics"
        echo "2. Create a release (v1.0.0)"
        echo "3. Enable GitHub Pages for documentation"
        echo "4. Share with the community!"
        echo ""
        echo "Repository topics to add:"
        echo "minio, kubernetes, operator, object-storage, s3-compatible, workshop, tutorial, devops, sre, cloud-native"
    else
        echo ""
        echo -e "${RED}❌ Push failed. Please check:${NC}"
        echo "1. Repository exists on GitHub"
        echo "2. You have push permissions"
        echo "3. GitHub authentication is configured"
        echo ""
        echo "Manual push command:"
        echo "git push -u origin main"
    fi
else
    echo ""
    echo "📋 Manual push instructions:"
    echo "1. Create repository on GitHub: https://github.com/new"
    echo "2. Run: git push -u origin main"
    echo "3. Your repository will be at: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
fi

echo ""
echo "📊 Repository statistics:"
echo "- Modules: 11 (7 core + 4 advanced)"
echo "- Scripts: $(find scripts/ -name "*.sh" | wc -l) utility scripts"
echo "- Documentation: $(find docs/ -name "*.md" | wc -l) guides"
echo "- Total files: $(find . -type f | grep -v .git | wc -l)"
echo ""
echo -e "${GREEN}🎓 Your MinIO Operator Workshop is ready to help others learn!${NC}"
