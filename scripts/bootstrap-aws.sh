#!/bin/bash
set -euo pipefail

# ============================================================
# Bootstrap Script: One-time AWS + GitHub setup for Amplify CI/CD
#
# Usage: ./scripts/bootstrap-aws.sh <owner/repo>
# Example: ./scripts/bootstrap-aws.sh AWS-Community/kiro-project
#
# Run this in AWS CloudShell or any environment with:
#   - AWS CLI configured (aws sts get-caller-identity works)
#   - Access to GitHub (for gh CLI — installed automatically if missing)
#
# Prerequisites:
#   - You must have a GitHub Personal Access Token (classic) with
#     scopes: repo (full control of private repositories)
#   - Set it as: export GH_TOKEN="ghp_your_token_here"
#     OR the script will prompt you to authenticate interactively.
# ============================================================

# --- Parse argument ---
if [ $# -lt 1 ]; then
  echo "Usage: $0 <owner/repo>"
  echo ""
  echo "Example:"
  echo "  $0 AWS-Community/kiro-project"
  echo "  AWS_REGION=us-east-1 $0 AWS-Community/other-project"
  echo ""
  echo "Prerequisites:"
  echo "  - AWS CLI configured (run: aws sts get-caller-identity)"
  echo "  - GitHub token set (run: export GH_TOKEN=ghp_...)"
  echo "    OR be ready to authenticate gh CLI interactively"
  exit 1
fi

REPO_FULL="$1"
REPO_OWNER="${REPO_FULL%%/*}"
REPO_NAME="${REPO_FULL##*/}"

# Derive app name from owner + repo name (lowercase, hyphens only)
APP_NAME=$(echo "${REPO_OWNER}-${REPO_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[_.]/-/g')

AWS_REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="GitHubActions-AmplifyDeploy-${REPO_OWNER}-${REPO_NAME}"

echo "🚀 Amplify CI/CD Bootstrap"
echo "=========================="
echo ""
echo "  Repo:     ${REPO_OWNER}/${REPO_NAME}"
echo "  App Name: ${APP_NAME}"
echo "  Region:   ${AWS_REGION}"
echo "  Role:     ${ROLE_NAME}"
echo ""

# --- Verify AWS access ---
echo "📌 Step 0a: Verifying AWS access..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
  echo "❌ AWS CLI not configured. Run 'aws configure' or set AWS environment variables."
  exit 1
}
echo "   ✅ AWS Account: $ACCOUNT_ID"
echo ""

# --- Install gh CLI if missing ---
echo "📌 Step 0b: Checking GitHub CLI..."
if ! command -v gh &>/dev/null; then
  echo "   gh CLI not found — installing..."
  if command -v dnf &>/dev/null; then
    # Amazon Linux / CloudShell
    sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true
    sudo dnf install -y gh 2>/dev/null || {
      # Fallback: direct binary download
      GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
      curl -sL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" | tar xz
      sudo mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh
      rm -rf gh_${GH_VERSION}_linux_amd64
    }
  elif command -v apt-get &>/dev/null; then
    # Debian/Ubuntu
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update && sudo apt-get install -y gh
  else
    # Direct binary download (universal fallback)
    GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
    curl -sL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" | tar xz
    sudo mv gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh
    rm -rf gh_${GH_VERSION}_linux_amd64
  fi
  echo "   ✅ gh CLI installed: $(gh --version | head -1)"
else
  echo "   ✅ gh CLI found: $(gh --version | head -1)"
fi
echo ""

# --- Verify GitHub auth ---
echo "📌 Step 0c: Verifying GitHub authentication..."
if [ -z "${GH_TOKEN:-}" ]; then
  if gh auth status &>/dev/null; then
    echo "   ✅ Already authenticated via gh CLI"
  else
    echo ""
    echo "   GitHub authentication required."
    echo "   You need a Personal Access Token with 'repo' scope."
    echo "   (Create one at: https://github.com/settings/tokens/new)"
    echo ""
    read -rsp "   Paste your GitHub token here (input is hidden): " GH_TOKEN_INPUT
    echo ""
    if [ -z "$GH_TOKEN_INPUT" ]; then
      echo "   ❌ No token provided. Exiting."
      exit 1
    fi
    export GH_TOKEN="$GH_TOKEN_INPUT"
  fi
fi

# Verify the token works (simple API call)
GH_USER=$(GH_TOKEN="${GH_TOKEN:-}" gh api user --jq '.login' 2>/dev/null) || {
  echo "   ❌ GitHub authentication failed. Check your token has 'repo' scope."
  exit 1
}
echo "   ✅ Authenticated as: $GH_USER"
echo ""

# --- Step 1: OIDC Provider ---
echo "📌 Step 1: Creating GitHub OIDC Provider..."
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
  2>/dev/null || echo "   (already exists — OK)"
echo ""

# --- Step 2: IAM Role ---
echo "📌 Step 2: Creating IAM Role: $ROLE_NAME"
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Federated\": \"arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com\"
      },
      \"Action\": \"sts:AssumeRoleWithWebIdentity\",
      \"Condition\": {
        \"StringEquals\": {
          \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
        },
        \"StringLike\": {
          \"token.actions.githubusercontent.com:sub\": \"repo:${REPO_OWNER}/${REPO_NAME}:*\"
        }
      }
    }]
  }" 2>/dev/null || echo "   (already exists — OK)"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess \
  2>/dev/null || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "   ✅ Role ARN: $ROLE_ARN"
echo ""

# --- Step 3: CDK Bootstrap ---
echo "📌 Step 3: Bootstrapping CDK (if needed)..."
if aws cloudformation describe-stacks --stack-name CDKToolkit --region "$AWS_REGION" &>/dev/null; then
  echo "   (already bootstrapped — OK)"
else
  echo "   Running cdk bootstrap..."
  npx cdk bootstrap "aws://${ACCOUNT_ID}/${AWS_REGION}"
fi
echo ""

# --- Step 4: Amplify App ---
echo "📌 Step 4: Creating Amplify App: $APP_NAME"
APP_ID=$(aws amplify create-app \
  --name "$APP_NAME" \
  --platform WEB \
  --region "$AWS_REGION" \
  --query 'app.appId' --output text)

aws amplify create-branch \
  --app-id "$APP_ID" \
  --branch-name main \
  --region "$AWS_REGION" 2>/dev/null || echo "   (branch already exists — OK)"

echo "   ✅ App ID: $APP_ID"
echo ""

# --- Step 4b: Region-scoped inline policies ---
echo "📌 Step 4b: Applying region-scoped IAM policies..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "AmplifyHostingAccess" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": [
        \"amplify:StartDeployment\",
        \"amplify:GetApp\",
        \"amplify:GetBranch\",
        \"amplify:ListApps\",
        \"amplify:ListBranches\",
        \"amplify:CreateBranch\",
        \"amplify:DeleteBranch\",
        \"amplify:CreateDeployment\",
        \"amplify:StartJob\",
        \"amplify:StopJob\",
        \"amplify:GetJob\",
        \"amplify:ListJobs\"
      ],
      \"Resource\": \"arn:aws:amplify:${AWS_REGION}:${ACCOUNT_ID}:apps/${APP_ID}/*\"
    }]
  }"

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "DenyOtherRegions" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Deny\",
      \"Action\": [
        \"amplify:*\",
        \"appsync:*\",
        \"dynamodb:*\"
      ],
      \"Resource\": \"*\",
      \"Condition\": {
        \"StringNotEquals\": {
          \"aws:RequestedRegion\": \"${AWS_REGION}\"
        }
      }
    }]
  }"

echo "   ✅ Policies scoped to region: $AWS_REGION"
echo ""

# --- Step 5: Set GitHub Repo Variables ---
echo "📌 Step 5: Setting GitHub repo variables..."
gh variable set AWS_DEPLOY_ROLE_ARN --body "$ROLE_ARN" --repo "${REPO_OWNER}/${REPO_NAME}"
gh variable set AWS_REGION --body "$AWS_REGION" --repo "${REPO_OWNER}/${REPO_NAME}"
gh variable set AMPLIFY_APP_ID --body "$APP_ID" --repo "${REPO_OWNER}/${REPO_NAME}"
echo "   ✅ Variables set on ${REPO_OWNER}/${REPO_NAME}"
echo ""

# --- Done ---
echo "=============================="
echo "✅ Bootstrap complete!"
echo ""
echo "   Repo:     ${REPO_OWNER}/${REPO_NAME}"
echo "   App Name: ${APP_NAME}"
echo "   APP_ID:   ${APP_ID}"
echo "   ROLE_ARN: ${ROLE_ARN}"
echo "   REGION:   ${AWS_REGION}"
echo ""
echo "Next steps:"
echo "  1. Push your code (including .github/workflows/deploy.yml) to main"
echo "  2. The workflow will deploy automatically ✅"
echo ""
echo "Branch preview URLs:"
echo "  https://main.${APP_ID}.amplifyapp.com"
echo "  https://<branch-name>.${APP_ID}.amplifyapp.com"
echo "=============================="
