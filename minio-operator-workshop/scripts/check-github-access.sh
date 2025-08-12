#!/bin/bash

# GitHub Accessibility Check Script
# This script verifies GitHub connectivity and authentication setup

set -e

echo "🔍 GitHub Accessibility Check"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check functions
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "✅ $1 is available"
        return 0
    else
        echo -e "❌ $1 is not installed"
        return 1
    fi
}

check_network() {
    if curl -s --connect-timeout 5 https://github.com > /dev/null; then
        echo -e "✅ GitHub is accessible"
        return 0
    else
        echo -e "❌ Cannot reach GitHub"
        return 1
    fi
}

check_git_config() {
    local git_user=$(git config --global user.name 2>/dev/null || echo "")
    local git_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -n "$git_user" ] && [ -n "$git_email" ]; then
        echo -e "✅ Git is configured"
        echo "   User: $git_user"
        echo "   Email: $git_email"
        return 0
    else
        echo -e "❌ Git is not configured"
        echo "   Run: git config --global user.name 'Your Name'"
        echo "   Run: git config --global user.email 'your.email@example.com'"
        return 1
    fi
}

check_github_auth() {
    echo "Checking GitHub authentication..."
    
    # Check if GitHub CLI is available and authenticated
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            echo -e "✅ GitHub CLI is authenticated"
            gh auth status
            return 0
        else
            echo -e "⚠️  GitHub CLI is available but not authenticated"
            echo "   Run: gh auth login"
        fi
    else
        echo -e "ℹ️  GitHub CLI not installed (optional)"
    fi
    
    # Check SSH key authentication
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "✅ SSH key authentication working"
        return 0
    else
        echo -e "⚠️  SSH key authentication not set up"
        echo "   You can use HTTPS authentication instead"
    fi
    
    # Test HTTPS authentication (will prompt for credentials if needed)
    echo ""
    echo "Testing HTTPS authentication..."
    echo "Note: This may prompt for GitHub username/password or token"
    
    return 1
}

# Main checks
echo ""
echo "1. Checking required tools..."
TOOLS_OK=true
check_command "git" || TOOLS_OK=false
check_command "curl" || TOOLS_OK=false

echo ""
echo "2. Checking network connectivity..."
NETWORK_OK=true
check_network || NETWORK_OK=false

echo ""
echo "3. Checking Git configuration..."
GIT_CONFIG_OK=true
check_git_config || GIT_CONFIG_OK=false

echo ""
echo "4. Checking GitHub authentication..."
AUTH_OK=true
check_github_auth || AUTH_OK=false

echo ""
echo "5. Testing repository creation capability..."

# Test if user can create repositories (requires authentication)
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    echo "Testing repository creation with GitHub CLI..."
    if gh repo list --limit 1 &> /dev/null; then
        echo -e "✅ Can access GitHub repositories"
    else
        echo -e "❌ Cannot access GitHub repositories"
        AUTH_OK=false
    fi
else
    echo -e "ℹ️  Cannot test repository creation without GitHub CLI authentication"
    echo "   You'll need to create the repository manually on GitHub.com"
fi

# Summary
echo ""
echo "📋 GitHub Accessibility Summary"
echo "==============================="

if [ "$TOOLS_OK" = true ] && [ "$NETWORK_OK" = true ] && [ "$GIT_CONFIG_OK" = true ]; then
    echo -e "${GREEN}✅ Basic requirements met!${NC}"
    echo ""
    echo "You can upload to GitHub using:"
    
    if [ "$AUTH_OK" = true ]; then
        echo -e "${GREEN}🚀 Automated upload (recommended):${NC}"
        echo "   ./scripts/upload-to-github.sh"
    else
        echo -e "${YELLOW}📋 Manual upload process:${NC}"
        echo "   1. Create repository on GitHub.com"
        echo "   2. Use HTTPS authentication with personal access token"
        echo "   3. Follow the manual upload steps in GITHUB_UPLOAD.md"
    fi
    
else
    echo -e "${RED}❌ Some requirements are not met.${NC}"
    echo ""
    echo "Issues to resolve:"
    [ "$TOOLS_OK" = false ] && echo "- Install missing tools (git, curl)"
    [ "$NETWORK_OK" = false ] && echo "- Check internet connection and firewall settings"
    [ "$GIT_CONFIG_OK" = false ] && echo "- Configure Git with your name and email"
fi

echo ""
echo "📖 Authentication Options"
echo "========================="
echo ""
echo "Option 1: GitHub CLI (Recommended)"
echo "  Install: https://cli.github.com/"
echo "  Setup: gh auth login"
echo "  Benefits: Easy repository creation and management"
echo ""
echo "Option 2: SSH Keys"
echo "  Generate: ssh-keygen -t ed25519 -C 'your.email@example.com'"
echo "  Add to GitHub: https://github.com/settings/keys"
echo "  Benefits: Secure, no password prompts"
echo ""
echo "Option 3: Personal Access Token (HTTPS)"
echo "  Create: https://github.com/settings/tokens"
echo "  Use as password when prompted"
echo "  Benefits: Works everywhere, easy to revoke"
echo ""

# Provide next steps
echo "🎯 Next Steps"
echo "============="
echo ""

if [ "$TOOLS_OK" = true ] && [ "$NETWORK_OK" = true ] && [ "$GIT_CONFIG_OK" = true ]; then
    if [ "$AUTH_OK" = true ]; then
        echo "1. You're ready to upload! Run:"
        echo "   ./scripts/upload-to-github.sh"
    else
        echo "1. Set up GitHub authentication (choose one option above)"
        echo "2. Run this check again: ./scripts/check-github-access.sh"
        echo "3. Upload your workshop: ./scripts/upload-to-github.sh"
    fi
else
    echo "1. Resolve the issues listed above"
    echo "2. Run this check again: ./scripts/check-github-access.sh"
    echo "3. Once all checks pass, upload your workshop"
fi

echo ""
echo "📚 Additional Resources"
echo "======================="
echo "- GitHub Docs: https://docs.github.com/"
echo "- Git Tutorial: https://git-scm.com/docs/gittutorial"
echo "- GitHub CLI: https://cli.github.com/manual/"
echo "- SSH Keys Guide: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"

# Exit with appropriate code
if [ "$TOOLS_OK" = true ] && [ "$NETWORK_OK" = true ] && [ "$GIT_CONFIG_OK" = true ]; then
    exit 0
else
    exit 1
fi
