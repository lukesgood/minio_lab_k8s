# Module 7: User & Permission Management

## 🎯 Learning Objectives

By the end of this module, you will:
- Understand MinIO's Identity and Access Management (IAM) system
- Create and manage users with different permission levels
- Implement policy-based access control (PBAC)
- Configure bucket-specific permissions
- Test and validate access controls

## 📚 Key Concepts

### MinIO IAM System
MinIO implements AWS IAM-compatible identity and access management, providing fine-grained control over who can access what resources and perform which operations.

### Policy-Based Access Control (PBAC)
Policies define what actions users can perform on specific resources. MinIO supports both built-in policies and custom policies.

### Principle of Least Privilege
Users should have only the minimum permissions necessary to perform their required tasks.

## 📋 Step-by-Step Instructions

### Step 1: Explore Current IAM Configuration

```bash
# Check current users (should only show admin)
mc admin user list local

# Check available policies
mc admin policy list local

# Check current user info
mc admin user info local admin
```

**Expected Output:**
```
enabled    admin
```

### Step 2: Create Test Buckets for Permission Testing

```bash
# Create buckets for different access levels
mc mb local/public-data
mc mb local/private-data
mc mb local/shared-data
mc mb local/readonly-data

# Add some test content
echo "Public information" > public-file.txt
echo "Private information" > private-file.txt
echo "Shared information" > shared-file.txt
echo "Read-only information" > readonly-file.txt

mc cp public-file.txt local/public-data/
mc cp private-file.txt local/private-data/
mc cp shared-file.txt local/shared-data/
mc cp readonly-file.txt local/readonly-data/

# List all buckets
mc ls local
```

### Step 3: Create Custom Policies

```bash
# Create a read-only policy
cat << EOF > readonly-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::readonly-data",
        "arn:aws:s3:::readonly-data/*"
      ]
    }
  ]
}
EOF

# Create a read-write policy for specific bucket
cat << EOF > readwrite-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::shared-data",
        "arn:aws:s3:::shared-data/*"
      ]
    }
  ]
}
EOF

# Create a public read policy
cat << EOF > public-read-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::public-data",
        "arn:aws:s3:::public-data/*"
      ]
    }
  ]
}
EOF

# Add policies to MinIO
mc admin policy create local readonly-policy readonly-policy.json
mc admin policy create local readwrite-policy readwrite-policy.json
mc admin policy create local public-read-policy public-read-policy.json

# Verify policies were created
mc admin policy list local
```

### Step 4: Create Users with Different Access Levels

```bash
# Create a read-only user
mc admin user add local readonly-user readonly123

# Create a read-write user
mc admin user add local readwrite-user readwrite123

# Create a public read user
mc admin user add local public-user public123

# List all users
mc admin user list local
```

### Step 5: Assign Policies to Users

```bash
# Assign policies to users
mc admin policy attach local readonly-policy --user readonly-user
mc admin policy attach local readwrite-policy --user readwrite-user
mc admin policy attach local public-read-policy --user public-user

# Verify policy assignments
mc admin user info local readonly-user
mc admin user info local readwrite-user
mc admin user info local public-user
```

### Step 6: Test Read-Only User Permissions

```bash
# Configure mc alias for read-only user
mc alias set readonly http://localhost:9000 readonly-user readonly123

# Test read operations (should work)
echo "Testing read-only user permissions..."
mc ls readonly/readonly-data/
mc cat readonly/readonly-data/readonly-file.txt

# Test write operations (should fail)
echo "Testing write operations (should fail)..."
echo "New content" > test-write.txt
mc cp test-write.txt readonly/readonly-data/new-file.txt 2>&1 || echo "✅ Write correctly denied"

# Test access to other buckets (should fail)
mc ls readonly/private-data/ 2>&1 || echo "✅ Access to private-data correctly denied"
mc ls readonly/shared-data/ 2>&1 || echo "✅ Access to shared-data correctly denied"

rm -f test-write.txt
```

### Step 7: Test Read-Write User Permissions

```bash
# Configure mc alias for read-write user
mc alias set readwrite http://localhost:9000 readwrite-user readwrite123

# Test read operations on allowed bucket
echo "Testing read-write user permissions..."
mc ls readwrite/shared-data/
mc cat readwrite/shared-data/shared-file.txt

# Test write operations on allowed bucket (should work)
echo "New shared content" > shared-new.txt
mc cp shared-new.txt readwrite/shared-data/
mc ls readwrite/shared-data/

# Test delete operations (should work)
mc rm readwrite/shared-data/shared-new.txt
mc ls readwrite/shared-data/

# Test access to other buckets (should fail)
mc ls readwrite/private-data/ 2>&1 || echo "✅ Access to private-data correctly denied"
mc ls readwrite/readonly-data/ 2>&1 || echo "✅ Access to readonly-data correctly denied"

rm -f shared-new.txt
```

### Step 8: Test Public Read User Permissions

```bash
# Configure mc alias for public read user
mc alias set publicread http://localhost:9000 public-user public123

# Test read operations on public bucket
echo "Testing public read user permissions..."
mc ls publicread/public-data/
mc cat publicread/public-data/public-file.txt

# Test write operations (should fail)
echo "Public write test" > public-write.txt
mc cp public-write.txt publicread/public-data/ 2>&1 || echo "✅ Write to public-data correctly denied"

# Test access to other buckets (should fail)
mc ls publicread/private-data/ 2>&1 || echo "✅ Access to private-data correctly denied"
mc ls publicread/shared-data/ 2>&1 || echo "✅ Access to shared-data correctly denied"

rm -f public-write.txt
```

### Step 9: Advanced Policy Testing

```bash
# Create a more complex policy with conditions
cat << EOF > conditional-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::shared-data/user-uploads/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::shared-data"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "user-uploads/*"
          ]
        }
      }
    }
  ]
}
EOF

# Add the conditional policy
mc admin policy create local conditional-policy conditional-policy.json

# Create a user with conditional access
mc admin user add local conditional-user conditional123
mc admin policy attach local conditional-policy --user conditional-user

# Configure alias for conditional user
mc alias set conditional http://localhost:9000 conditional-user conditional123

# Test conditional access
echo "Testing conditional policy..."
mc ls conditional/shared-data/ 2>&1 || echo "✅ Root listing correctly denied"

# Create the allowed directory structure using admin
mc cp shared-file.txt local/shared-data/user-uploads/allowed-file.txt

# Test access to allowed path
mc ls conditional/shared-data/user-uploads/
mc cat conditional/shared-data/user-uploads/allowed-file.txt
```

### Step 10: User Management Operations

```bash
# Disable a user temporarily
mc admin user disable local public-user

# Test that disabled user cannot access
mc ls publicread/public-data/ 2>&1 || echo "✅ Disabled user correctly denied access"

# Re-enable the user
mc admin user enable local public-user

# Test that re-enabled user can access again
mc ls publicread/public-data/ && echo "✅ Re-enabled user can access again"

# Change user password
mc admin user add local readwrite-user newpassword456

# Test with new password
mc alias set readwrite-new http://localhost:9000 readwrite-user newpassword456
mc ls readwrite-new/shared-data/ && echo "✅ New password works"

# Remove policy from user
mc admin policy detach local readwrite-policy --user readwrite-user

# Test that user has no access after policy removal
mc ls readwrite-new/shared-data/ 2>&1 || echo "✅ User correctly has no access after policy removal"

# Re-attach policy
mc admin policy attach local readwrite-policy --user readwrite-user
```

## 🔍 Understanding IAM Concepts

### Policy Structure

MinIO policies follow AWS IAM policy syntax:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow|Deny",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::bucket/*"],
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/Department": "Engineering"
        }
      }
    }
  ]
}
```

### Common S3 Actions

| Action | Description |
|--------|-------------|
| `s3:GetObject` | Download objects |
| `s3:PutObject` | Upload objects |
| `s3:DeleteObject` | Delete objects |
| `s3:ListBucket` | List bucket contents |
| `s3:CreateBucket` | Create new buckets |
| `s3:DeleteBucket` | Delete buckets |
| `s3:GetBucketLocation` | Get bucket region |

### Resource ARN Format

- Bucket: `arn:aws:s3:::bucket-name`
- Object: `arn:aws:s3:::bucket-name/object-key`
- Wildcard: `arn:aws:s3:::bucket-name/*`

## ✅ Validation Checklist

Before proceeding to Module 8, ensure:

- [ ] Created custom policies for different access levels
- [ ] Successfully created users with different permissions
- [ ] Verified read-only user cannot write or access unauthorized buckets
- [ ] Confirmed read-write user can modify allowed buckets only
- [ ] Tested user enable/disable functionality
- [ ] Validated policy attachment and detachment
- [ ] Understood policy conditions and resource restrictions

## 🚨 Common Issues & Solutions

### Issue: Policy Creation Fails
```bash
# Check JSON syntax
cat policy.json | jq .

# Verify policy format matches MinIO requirements
mc admin policy create local test-policy policy.json
```

### Issue: User Cannot Access Despite Policy
```bash
# Check user status
mc admin user info local username

# Verify policy is attached
mc admin user info local username | grep -i policy

# Check policy content
mc admin policy info local policy-name
```

### Issue: Access Denied Errors
```bash
# Verify credentials are correct
mc alias list

# Check if user is enabled
mc admin user list local

# Verify resource ARNs in policy match actual bucket names
```

### Issue: Policy Not Taking Effect
```bash
# Policies take effect immediately, but check:
# 1. Policy is correctly attached to user
# 2. Resource ARNs are correct
# 3. Actions match what you're trying to do

# Re-attach policy if needed
mc admin policy detach local policy-name --user username
mc admin policy attach local policy-name --user username
```

## 🔧 Advanced IAM Features (Optional)

### Group Management

```bash
# Create a group (if supported in your MinIO version)
mc admin group add local developers readwrite-user

# Attach policy to group
mc admin policy attach local readwrite-policy --group developers
```

### Service Accounts

```bash
# Create service account for applications
mc admin user svcacct add local readwrite-user

# List service accounts
mc admin user svcacct list local readwrite-user
```

### Temporary Credentials

```bash
# Generate temporary credentials (STS)
mc admin policy create local temp-policy readonly-policy.json
# Note: Full STS implementation may require additional configuration
```

## 📊 Security Best Practices

### User Management
1. **Principle of Least Privilege**: Grant minimum necessary permissions
2. **Regular Audits**: Review user permissions periodically
3. **Strong Passwords**: Enforce password complexity requirements
4. **Account Lifecycle**: Disable unused accounts promptly

### Policy Design
1. **Specific Resources**: Avoid overly broad resource specifications
2. **Explicit Deny**: Use explicit deny for sensitive operations
3. **Conditions**: Use conditions to add additional security layers
4. **Regular Review**: Update policies as requirements change

### Monitoring
1. **Access Logs**: Monitor user access patterns
2. **Failed Attempts**: Track authentication failures
3. **Permission Changes**: Audit policy modifications
4. **Unusual Activity**: Monitor for suspicious behavior

## 📖 Additional Reading

- [MinIO IAM Configuration](https://docs.min.io/minio/baremetal/security/minio-identity-management.html)
- [AWS IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
- [S3 Actions and Resources](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-arn-format.html)

## ➡️ Next Steps

Now that you've mastered user and permission management:

```bash
cd ../08-monitoring
cat README.md
```

---

**🎉 Excellent work!** You've successfully implemented a comprehensive IAM system with MinIO. You understand how to create users, design policies, and implement the principle of least privilege. You've tested various access scenarios and can now secure your MinIO deployment for production use. In the next module, we'll explore monitoring and observability to keep track of your MinIO system's health and performance.
