# GitHub Secrets Setup Guide

Add these secrets to your repository:
**Settings → Secrets and Variables → Actions → New repository secret**

## Required Secrets

| Secret Name | Description | Neon Branch |
|---|---|---|
| `NEON_DATABASE_URL` | Production DB connection string | `main` (br-sweet-wave-ajjqjpcx) |
| `NEON_DEV_DATABASE_URL` | Development DB connection string | `dev` (br-red-queen-ajflu29s) |
| `NEON_STAGING_DATABASE_URL` | Staging DB connection string | `staging` (br-red-morning-ajqsce8g) |
| `NEON_API_KEY` | Neon API key for PR preview branches | From neon.tech/app/settings/api-keys |

## Connection Strings

### Production (main branch)
```
postgresql://neondb_owner:<password>@ep-fragrant-bonus-aj8ovok4-pooler.c-3.us-east-2.aws.neon.tech/neondb?sslmode=require
```

### Dev branch
```
postgresql://neondb_owner:<password>@ep-twilight-pine-ajy5sfox-pooler.c-3.us-east-2.aws.neon.tech/neondb?sslmode=require
```

### Staging branch
```
postgresql://neondb_owner:<password>@ep-winter-field-ajln8tbx-pooler.c-3.us-east-2.aws.neon.tech/neondb?sslmode=require
```

## Get Your Neon API Key
1. Go to https://console.neon.tech
2. Click your profile → **Account Settings**
3. Go to **API Keys** tab
4. Click **Generate new API key**
5. Copy and add as `NEON_API_KEY` secret

## Optional Secrets

| Secret Name | Description |
|---|---|
| `GOOGLE_MAPS_API_KEY` | For map module |
| `FIREBASE_KEY` | For push notifications |
| `CODECOV_TOKEN` | For coverage reporting |
