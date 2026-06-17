# Deployment Guide

> **Two deployment options exist.** See the README for which to choose.
> - Amplify Hosting AutoBuild: `scripts/bootstrap-amplify-hosting.sh`
> - GitHub Actions: `scripts/bootstrap-github-actions.sh`
>
> **Do NOT use both simultaneously** — they will conflict (double deploys).

## Quick Start (Recommended Order)

For a new project:

1. Create your repo on GitHub (clone this template or push your code)
2. Run the bootstrap script once:
   - **Option A (Amplify AutoBuild):** `./scripts/bootstrap-amplify-hosting.sh YOUR-ORG/your-repo`
   - **Option B (GitHub Actions):** `./scripts/bootstrap-github-actions.sh YOUR-ORG/your-repo`
3. Option B activates the workflow file (moves it from `.github/workflow-templates/` to `.github/workflows/`)
4. Commit and push — deployment starts automatically ✅

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
./scripts/bootstrap-github-actions.sh AWS-Community/your-repo
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
curl -O https://raw.githubusercontent.com/Mat-KH/amplify-gen2-starter/main/scripts/bootstrap-github-actions.sh
chmod +x bootstrap-github-actions.sh

# Set your GitHub token
export GH_TOKEN=ghp_your_token_here

# Run it
./bootstrap-github-actions.sh AWS-Community/your-repo

# Or with a custom region:
AWS_REGION=eu-central-1 ./bootstrap-github-actions.sh AWS-Community/your-repo
```

This does everything in one command:
1. ✅ Installs `gh` CLI (if missing)
2. ✅ Verifies AWS + GitHub authentication
3. ✅ Creates GitHub OIDC provider in AWS
4. ✅ Creates IAM role with correct permissions
5. ✅ Bootstraps CDK (if needed)
6. ✅ Creates Amplify app + branch
7. ✅ Sets GitHub repo variables automatically
8. ✅ Activates the workflow file (copies to `.github/workflows/`)

**After this, commit the activated workflow and push — deployment starts automatically.**

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

## Important: Workflow Activation (GitHub Actions only)

The workflow file lives in `.github/workflow-templates/deploy.yml` and is **dormant** by default — GitHub ignores it there. When you run `./scripts/bootstrap-github-actions.sh`, the script:

1. Creates OIDC provider + IAM role + Amplify app + sets GitHub repo variables
2. Copies the workflow to `.github/workflows/deploy.yml` (activating it)

You then commit and push the newly activated file. This ensures credentials are always in place before the workflow runs.

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
| **AccessDeniedException** | Run `./scripts/bootstrap-github-actions.sh` again — it's idempotent |
| **OIDC trust error** | Check the `sub` condition matches your repo and branch |
| **Build fails on amplify_outputs.json** | `pipeline-deploy` generates this — ensure it runs before `npm run build` |
| **Workflow fails on first push** | Ensure you ran `bootstrap-github-actions.sh` first — it activates the workflow and sets up credentials |
| **Cannot find package 'tsx'** | Add `tsx` to devDependencies — required by `@aws-amplify/backend-cli` at runtime |
| **BootstrapNotDetectedError** | Run `npx cdk bootstrap aws://ACCOUNT_ID/REGION` |
| **Rollup failed to resolve @aws-amplify/data-schema-types** | Move to `dependencies` (not devDependencies) |
| **TS2688: Cannot find type definition file** | Add explicit `"types": ["react", "react-dom"]` to tsconfig.json |
| **Node.js runner deprecated** | Use `NODE_VERSION: 24` in deploy.yml (GitHub deprecated Node 20 runners) |
| **Operations denied in other regions** | The IAM role is scoped to the region configured during bootstrap. If you need to change regions, re-run the bootstrap script with the new `AWS_REGION`. |
