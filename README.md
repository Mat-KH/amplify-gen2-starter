# Amplify Gen2 Starter Template

A battle-tested starter for React + TypeScript + Vite + AWS Amplify Gen2 apps.

## ⚠️ Choose Your Deployment Method

This template supports **two** deployment approaches. **Pick one, not both.**

| | Amplify Hosting AutoBuild (Pull) | GitHub Actions (Push) |
|---|---|---|
| **Script** | `scripts/bootstrap-amplify-hosting.sh` | `scripts/bootstrap-github-actions.sh` |
| **Principle** | AWS pulls code from GitHub on change | GitHub pushes build artifacts to AWS |
| **Who builds & deploys?** | AWS Amplify (automatic via webhook) | GitHub Actions Runner (active push) |
| **Auth mechanism** | GitHub Token (webhook) | OIDC Federation (no long-lived secrets) |
| **Setup complexity** | Simple (no OIDC, no workflow file) | More involved (OIDC + IAM + workflow YAML) |
| **Flexibility** | Limited (`amplify.yml` build spec) | Full (arbitrary workflow steps) |

<details>
<summary><strong>Additional comparison details</strong></summary>

| | Amplify Hosting AutoBuild | GitHub Actions |
|---|---|---|
| **Branch previews** | Automatic (built-in) | Manual (built into the workflow) |
| **Cleanup on branch delete** | Automatic (built-in) | Via workflow `delete` trigger |
| **Custom build steps** | Limited to `amplify.yml` | Full flexibility (tests, linting, approval gates, etc.) |
| **Cost** | Amplify Build minutes (1000 free/month) | GitHub Actions minutes (2000 free/month) |

</details>

**Recommendation:**
- **Use Amplify Hosting** if you just want push-to-deploy with zero config → `./scripts/bootstrap-amplify-hosting.sh`
- **Use GitHub Actions** if you need custom CI steps (tests, lint, approval gates) → `./scripts/bootstrap-github-actions.sh`

## Quick Start

### 1. Clone this template

```bash
git clone <this-repo> my-new-app
cd my-new-app
rm -rf .git && git init
npm install
```

### 2. Define your data models

Edit `amplify/data/resource.ts` — replace the `Example` model with your own.

### 3. Bootstrap AWS + GitHub (one-time)

Run in AWS CloudShell (or anywhere with AWS CLI access):

```bash
# Set your GitHub token (create at https://github.com/settings/tokens/new with 'repo' scope)
export GH_TOKEN=ghp_your_token_here

# Option A: Amplify Hosting AutoBuild (simpler, no GitHub Actions needed)
./scripts/bootstrap-amplify-hosting.sh YOUR-ORG/your-repo

# Option B: GitHub Actions (more control, custom CI steps)
./scripts/bootstrap-github-actions.sh YOUR-ORG/your-repo
```

The bootstrap script creates all AWS resources and (for Option B) activates the GitHub Actions workflow file.

### 4. Push and deploy

```bash
git add . && git commit -m "feat: initial app"
git push origin main
```

- **Option A:** Amplify builds automatically via webhook (no workflow file needed).
- **Option B:** GitHub Actions runs the workflow and deploys.

## Branch Deployments

Every branch pushed to `main`, `dev`, `staging`, or `feature/*` gets its own isolated environment:

| Branch | URL | Backend |
|--------|-----|---------|
| `main` | `https://main.<app-id>.amplifyapp.com` | Production DynamoDB + AppSync |
| `dev` | `https://dev.<app-id>.amplifyapp.com` | Isolated dev backend |
| `feature/xyz` | `https://feature-xyz.<app-id>.amplifyapp.com` | Isolated feature backend |

Each branch environment has:
- Its own DynamoDB tables
- Its own AppSync API + API key
- Its own URL on Amplify Hosting
- Automatic cleanup when the branch is deleted

## Local Development

```bash
npx ampx sandbox   # Deploys backend + generates amplify_outputs.json
npm run dev         # Starts Vite dev server
```

## Project Structure

```
├── amplify/
│   ├── backend.ts           # Backend entry point
│   └── data/resource.ts     # Data models (edit this!)
├── src/
│   ├── main.tsx             # Amplify.configure() + React entry
│   ├── App.tsx              # Your app (edit this!)
│   └── App.css              # Styles
├── scripts/
│   ├── bootstrap-amplify-hosting.sh  # Option A: Amplify AutoBuild (simpler)
│   └── bootstrap-github-actions.sh              # Option B: GitHub Actions (more control)
├── .github/workflow-templates/
│   └── deploy.yml           # CI/CD pipeline (dormant until bootstrap-github-actions.sh activates it)
├── amplify.yml              # Amplify Hosting build spec
└── package.json
```

## Key Dependencies

| Package | Location | Why |
|---------|----------|-----|
| `aws-amplify` | dependencies | Frontend SDK |
| `@aws-amplify/data-schema-types` | dependencies | Required by data-schema at runtime |
| `@aws-amplify/backend` | devDependencies | Backend definition (build-time only!) |
| `@aws-amplify/backend-cli` | devDependencies | `ampx` CLI (build-time only!) |
| `tsx` | devDependencies | Required by backend-cli for pipeline-deploy |

⚠️ **Never put `@aws-amplify/backend` in `dependencies`** — it causes Vite build failures.

## Amplify Data Schema Tips

```typescript
// FK fields MUST use a.id(), NOT a.string()
parentId: a.id().required(),

// Relationships MUST declare BOTH sides
Parent: a.model({ children: a.hasMany("Child", "parentId") })
Child: a.model({ parent: a.belongsTo("Parent", "parentId") })

// .default() does NOT work on a.enum() fields
// Authorization: publicApiKey() = no login needed
```

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Cannot find module '../amplify_outputs.json'` | Run `npx ampx sandbox --once` |
| `BootstrapNotDetectedError` | Run `npx cdk bootstrap aws://ACCOUNT/REGION` |
| `ERR_MODULE_NOT_FOUND: tsx` | Ensure `tsx` is in devDependencies |
| `Rollup failed to resolve @aws-amplify/data-schema-types` | Ensure it's in dependencies (not devDependencies) |
| `TS2688: Cannot find type definition file` | Add explicit `"types"` array to tsconfig.json |
