#!/bin/bash
set -euo pipefail

# ============================================================
# Bootstrap Script: Amplify Hosting with AutoBuild
#
# This is the SIMPLER alternative to bootstrap-github-actions.sh.
# Use this if you want Amplify to build/deploy automatically
# on every push — WITHOUT needing GitHub Actions.
#
# Usage: ./scripts/bootstrap-amplify-hosting.sh <owner/repo>
# Example: ./scripts/bootstrap-amplify-hosting.sh AWS-Community/kiro-project
#
# ⚠️  Choose ONE:
#   - This script (Amplify Hosting AutoBuild) — simpler, no OIDC needed
#   - bootstrap-github-actions.sh (GitHub Actions) — more control, custom steps
#   DO NOT use both!
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
  echo "  - GitHub token with 'repo' scope (for webhook installation)"
  exit 1
fi

REPO_FULL="$1"
REPO_OWNER="${REPO_FULL%%/*}"
REPO_NAME="${REPO_FULL##*/}"

# Derive app name from owner + repo name (lowercase, hyphens only)
APP_NAME=$(echo "${REPO_OWNER}-${REPO_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[_.]/-/g')

AWS_REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="AmplifyServiceRole-${REPO_OWNER}-${REPO_NAME}"

echo "🚀 Amplify Hosting AutoBuild Bootstrap"
echo "======================================="
echo ""
echo "  Repo:     ${REPO_OWNER}/${REPO_NAME}"
echo "  App Name: ${APP_NAME}"
echo "  Region:   ${AWS_REGION}"
echo ""

# --- Verify AWS access ---
echo "📌 Step 1: Verifying AWS access..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
  echo "❌ AWS CLI not configured. Run 'aws configure' or set AWS environment variables."
  exit 1
}
echo "   ✅ AWS Account: $ACCOUNT_ID"
echo ""

# --- Get GitHub token ---
echo "📌 Step 2: GitHub token (for webhook)..."
if [ -z "${GH_TOKEN:-}" ]; then
  echo "   Amplify needs a GitHub token to install a webhook on your repo."
  echo "   (Create one at: https://github.com/settings/tokens/new with 'repo' scope)"
  echo ""
  read -rsp "   Paste your GitHub token here (input is hidden): " GH_TOKEN
  echo ""
  if [ -z "$GH_TOKEN" ]; then
    echo "   ❌ No token provided. Exiting."
    exit 1
  fi
fi
echo "   ✅ Token provided"
echo ""

# --- CDK Bootstrap ---
echo "📌 Step 3: Bootstrapping CDK (if needed)..."
if aws cloudformation describe-stacks --stack-name CDKToolkit --region "$AWS_REGION" &>/dev/null; then
  echo "   (already bootstrapped — OK)"
else
  echo "   Running cdk bootstrap..."
  npx cdk bootstrap "aws://${ACCOUNT_ID}/${AWS_REGION}"
fi
echo ""

# --- Create Amplify Service Role ---
echo "📌 Step 4: Creating Amplify service role..."
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "amplify.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "   (already exists — OK)"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess \
  2>/dev/null || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "   ✅ Service Role: $ROLE_ARN"
echo ""

# --- Create Amplify App with AutoBuild ---
echo "📌 Step 5: Creating Amplify App with AutoBuild..."
APP_ID=$(aws amplify create-app \
  --name "$APP_NAME" \
  --repository "https://github.com/${REPO_OWNER}/${REPO_NAME}" \
  --access-token "$GH_TOKEN" \
  --iam-service-role-arn "$ROLE_ARN" \
  --enable-branch-auto-build \
  --enable-branch-auto-deletion \
  --platform WEB \
  --region "$AWS_REGION" \
  --query 'app.appId' --output text)

echo "   ✅ App ID: $APP_ID"
echo ""

# --- Create main branch with AutoBuild ---
echo "📌 Step 6: Configuring main branch..."
aws amplify create-branch \
  --app-id "$APP_ID" \
  --branch-name main \
  --enable-auto-build \
  --stage PRODUCTION \
  --region "$AWS_REGION" 2>/dev/null || echo "   (already exists — OK)"
echo "   ✅ main branch configured with AutoBuild"
echo ""

# --- Trigger first build ---
echo "📌 Step 7: Triggering first deployment..."
aws amplify start-job \
  --app-id "$APP_ID" \
  --branch-name main \
  --job-type RELEASE \
  --region "$AWS_REGION" \
  --query 'jobSummary.status' --output text
echo ""

# --- Done ---
echo "=============================="
echo "✅ Amplify Hosting AutoBuild is live!"
echo ""
echo "   App Name: ${APP_NAME}"
echo "   APP_ID:   ${APP_ID}"
echo "   Region:   ${AWS_REGION}"
echo ""
echo "   Console:  https://${AWS_REGION}.console.aws.amazon.com/amplify/apps/${APP_ID}"
echo "   Live URL: https://main.${APP_ID}.amplifyapp.com"
echo ""
echo "How it works:"
echo "  - Every push to 'main' auto-builds and deploys"
echo "  - Feature branches get preview URLs automatically"
echo "  - Deleted branches are cleaned up automatically"
echo ""
echo "No GitHub Actions needed! Amplify handles everything."
echo "=============================="
