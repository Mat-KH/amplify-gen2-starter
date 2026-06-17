# Deployment Guide

## Quick Start (Recommended Order)

For a new project, follow this order to avoid the chicken-and-egg problem:

1. Create your repo on GitHub (can have code, but the workflow won't succeed until bootstrap runs)
2. Run the bootstrap script once: `./scripts/bootstrap-aws.sh AWS-Community/your-repo`
3. Push code including `.github/workflows/deploy.yml`
4. Every subsequent push to `main` (or any configured branch) auto-deploys ✅

## Prerequisites

### 1. AWS CLI access

You need an environment where `aws sts get-caller-identity` works. Options:
- **AWS CloudShell** (recommended — zero setup, already authenticated)
- Local terminal with `aws configure` done
- GitHub Codespace with AWS env vars set

### 2. GitHub Personal Access Token

The bootstrap script needs to set repository variables on GitHub. For this it uses the `gh` CLI which requires authentication.

**Create a token:**
1. Go to https://github.com/settings/tokens/new
2. Select scopes:
   - `repo` (full control of private repositories)
   - `admin:org` (only if your repo is in an organization)
3. Generate and copy the token

**Use the token in CloudShell:**
```bash
export GH_TOKEN=ghp_your_token_here
./scripts/bootstrap-aws.sh AWS-Community/your-repo
```

The script will:
- Auto-install `gh` CLI if it's not present (works in CloudShell, Ubuntu, Amazon Linux)
- Authenticate using `GH_TOKEN` automatically
- Or prompt you with instructions if neither is available

### 3. CDK Bootstrap (handled automatically)

The script checks if CDK is bootstrapped in your target region and runs `cdk bootstrap` if needed. No manual action required.

## One-Time Setup (Bootstrap)

Run from anywhere with AWS access (CloudShell recommended):

```bash
# Download the script (or clone the repo)
curl -O https://raw.githubusercontent.com/Mat-KH/amplify-gen2-starter/main/scripts/bootstrap-aws.sh
chmod +x bootstrap-aws.sh

# Set your GitHub token
export GH_TOKEN=ghp_your_token_here

# Run it
./bootstrap-aws.sh AWS-Community/your-repo

# Or with a custom region:
AWS_REGION=eu-central-1 ./bootstrap-aws.sh AWS-Community/your-repo
```

This does everything in one command:
1. ✅ Installs `gh` CLI (if missing)
2. ✅ Verifies AWS + GitHub authentication
3. ✅ Creates GitHub OIDC provider in AWS
4. ✅ Creates IAM role with correct permissions
5. ✅ Bootstraps CDK (if needed)
6. ✅ Creates Amplify app + branch
7. ✅ Sets GitHub repo variables automatically

**After this, push your code and it deploys. No manual console clicks needed.**

## What Gets Cached

The workflow caches three things for speed:

| Cache | Key | Saves |
|-------|-----|-------|
| npm packages | `package-lock.json` hash | ~30s install time |
| node_modules | `package-lock.json` hash | Skips `npm ci` entirely |
| Amplify backend | `amplify/` directory hash | Faster CDK synthesis |

Typical deployment: **~2-3 minutes** (vs ~5 minutes uncached).

## Local Development

```bash
npx ampx sandbox   # Deploys backend + generates amplify_outputs.json
npm run dev         # Starts Vite dev server
```

## Important: OIDC + IAM Setup Order

The OIDC provider and IAM role **MUST** exist before the workflow file is pushed to the repo. If you push the workflow first, the GitHub Actions run will fail because the credentials step can't assume the role.

Order of operations:
1. Run `./scripts/bootstrap-aws.sh` (creates OIDC + role + Amplify app + repo vars)
2. THEN push the workflow file

## Multi-Branch Environments

### How it works

1. Push any branch matching the configured patterns → GitHub Actions triggers
2. Workflow creates an Amplify branch entry (if it doesn't exist yet)
3. `ampx pipeline-deploy --branch <branch-name>` creates isolated backend resources
4. Frontend is built and deployed to a branch-specific URL
5. When the branch is deleted from GitHub → cleanup job removes the Amplify branch

### Branch URLs

After deployment, each branch is available at:
```
https://<branch-name>.<app-id>.amplifyapp.com
```

Note: Slashes in branch names (e.g., `feature/my-thing`) are converted to hyphens in the URL.

### Cleanup

When you delete a branch on GitHub (e.g., after merging a PR), the `cleanup` job automatically:
1. Deletes the Amplify branch (which removes the CloudFormation stack)
2. This tears down all associated resources (DynamoDB tables, AppSync API, etc.)

⚠️ **`main` is excluded from cleanup** — it only triggers on `feature/**`, `dev`, and `staging` deletions.

### Cost implications

Each branch environment creates its own AWS resources. For DynamoDB (on-demand mode), you only pay for actual usage, so idle feature branches cost nearly nothing. But be aware that many concurrent branches = many CloudFormation stacks.

## Troubleshooting

| Error | Fix |
|-------|-----|
| **AccessDeniedException** | Run `./scripts/bootstrap-aws.sh` again — it's idempotent |
| **OIDC trust error** | Check the `sub` condition matches your repo and branch |
| **Build fails on amplify_outputs.json** | `pipeline-deploy` generates this — ensure it runs before `npm run build` |
| **Workflow fails on first push** | You pushed the workflow BEFORE running bootstrap. Run bootstrap, then re-trigger |
| **Cannot find package 'tsx'** | Add `tsx` to devDependencies — required by `@aws-amplify/backend-cli` at runtime |
| **BootstrapNotDetectedError** | Run `npx cdk bootstrap aws://ACCOUNT_ID/REGION` |
| **Rollup failed to resolve @aws-amplify/data-schema-types** | Move to `dependencies` (not devDependencies) |
| **TS2688: Cannot find type definition file** | Add explicit `"types": ["react", "react-dom"]` to tsconfig.json |
| **Node.js runner deprecated** | Use `NODE_VERSION: 24` in deploy.yml (GitHub deprecated Node 20 runners) |
