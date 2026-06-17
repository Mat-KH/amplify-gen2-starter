# Amplify Gen2 Starter Template

A battle-tested starter for React + TypeScript + Vite + AWS Amplify Gen2 apps.

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

# Run bootstrap (installs gh CLI automatically if needed)
./scripts/bootstrap-aws.sh YOUR-ORG/your-repo
```

This creates all AWS resources, bootstraps CDK, and sets GitHub repo variables — all in one command.

### 4. Push and deploy

```bash
git add . && git commit -m "feat: initial app"
git push origin main
```

GitHub Actions will automatically deploy backend + frontend.

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

### Adding more branch patterns

Edit `.github/workflows/deploy.yml` — add patterns to both the `push` and `delete` triggers:

```yaml
on:
  push:
    branches:
      - main
      - 'feature/**'
      - 'dev'
      - 'staging'
      - 'your-new-pattern/**'  # add here
```

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
│   └── bootstrap-aws.sh     # One-time AWS/GitHub setup
├── .github/workflows/
│   └── deploy.yml           # CI/CD pipeline
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
