# Platform Registration Guide

This guide explains how to register RSR-Certified as an app/integration on each supported platform.

## GitHub

### Option 1: GitHub App (Recommended)

GitHub Apps provide the best integration with fine-grained permissions.

#### Step 1: Create the App

1. Go to **Settings > Developer settings > GitHub Apps**
2. Click **New GitHub App**
3. Fill in the details:

| Field | Value |
|-------|-------|
| App name | `RSR-Certified` (or your custom name) |
| Homepage URL | `https://your-domain.com` |
| Webhook URL | `https://your-domain.com/webhook/github` |
| Webhook secret | Generate a strong random string |

#### Step 2: Configure Permissions

**Repository permissions:**
- Contents: `Read`
- Metadata: `Read`
- Pull requests: `Read & Write`
- Checks: `Read & Write`
- Commit statuses: `Read & Write`
- Issues: `Read & Write` (optional)

**Subscribe to events:**
- [x] Push
- [x] Pull request
- [x] Check run
- [x] Check suite
- [x] Create
- [x] Release

#### Step 3: Generate Credentials

1. Note your **App ID** (shown at top of app page)
2. Scroll to **Private keys** and click **Generate a private key**
3. Download the `.pem` file - keep this secure!

#### Step 4: Install the App

1. Go to your app's public page
2. Click **Install App**
3. Choose repositories (all or select specific ones)

#### Step 5: Configure Your Server

```bash
export GITHUB_APP_ID=123456
export GITHUB_PRIVATE_KEY="$(cat your-app.private-key.pem)"
export GITHUB_WEBHOOK_SECRET=your-webhook-secret
```

### Option 2: Personal Access Token (Simpler)

For personal projects or testing:

1. Go to **Settings > Developer settings > Personal access tokens > Tokens (classic)**
2. Generate new token with scopes:
   - `repo` (full repository access)
   - `read:org` (if using org repos)
3. Use as `GITHUB_TOKEN` environment variable

---

## GitLab

### Step 1: Create Project Access Token

For project-level integration:

1. Go to **Project > Settings > Access Tokens**
2. Create token with:
   - Name: `RSR-Certified`
   - Scopes: `api`, `read_repository`
3. Save the token securely

### Step 2: Configure Webhooks

1. Go to **Project > Settings > Webhooks**
2. Add webhook:

| Field | Value |
|-------|-------|
| URL | `https://your-domain.com/webhook/gitlab` |
| Secret token | Generate a strong random string |

3. Select triggers:
   - [x] Push events
   - [x] Merge request events
   - [x] Pipeline events

### Step 3: Configure Your Server

```bash
export GITLAB_TOKEN=your-access-token
export GITLAB_WEBHOOK_SECRET=your-webhook-secret
# For self-hosted GitLab:
export GITLAB_URL=https://gitlab.yourcompany.com
```

### Group-Level Integration

For organization-wide deployment:

1. Go to **Group > Settings > Access Tokens**
2. Create token with `api` and `read_repository` scopes
3. Configure group-level webhooks in **Group > Settings > Webhooks**

---

## Bitbucket

### Step 1: Create App Password

1. Go to **Personal settings > App passwords**
2. Create password with permissions:
   - Repositories: Read
   - Pull requests: Read, Write
   - Webhooks: Read, Write

### Step 2: Configure Repository Webhooks

1. Go to **Repository > Settings > Webhooks**
2. Add webhook:

| Field | Value |
|-------|-------|
| Title | `RSR-Certified` |
| URL | `https://your-domain.com/webhook/bitbucket` |

3. Select triggers:
   - [x] Repository: Push
   - [x] Pull Request: Created, Updated, Merged

### Step 3: Configure Your Server

```bash
export BITBUCKET_USERNAME=your-username
export BITBUCKET_TOKEN=your-app-password
```

### Bitbucket Cloud vs Server

For Bitbucket Server/Data Center:

```bash
export BITBUCKET_URL=https://bitbucket.yourcompany.com
```

---

## Gitea / Forgejo

### Step 1: Create Access Token

1. Go to **Settings > Applications**
2. Generate new token with permissions:
   - `repo` (or `read:repository`)
   - `write:issue` (optional)

### Step 2: Configure Webhooks

1. Go to **Repository > Settings > Webhooks**
2. Add Gitea webhook:

| Field | Value |
|-------|-------|
| Target URL | `https://your-domain.com/webhook/gitea` |
| HTTP Method | POST |
| Content Type | application/json |
| Secret | Generate a strong random string |

3. Select events:
   - [x] Push
   - [x] Pull Request

### Step 3: Configure Your Server

```bash
export GITEA_TOKEN=your-access-token
export GITEA_WEBHOOK_SECRET=your-webhook-secret
export GITEA_URL=https://gitea.yourcompany.com
```

---

## Azure DevOps

*Coming soon*

### Overview

Azure DevOps integration uses:
- Personal Access Tokens for API access
- Service Hooks for webhooks

### Step 1: Create PAT

1. Go to **User Settings > Personal access tokens**
2. Create token with:
   - Code: Read
   - Pull Request Threads: Read & Write
   - Build: Read & Execute

### Step 2: Configure Service Hooks

1. Go to **Project Settings > Service hooks**
2. Create subscription for:
   - Code pushed
   - Pull request created
   - Pull request updated

---

## AWS CodeCommit

*Coming soon*

Uses SNS notifications for events and IAM for API access.

---

## Common Issues

### Webhook Not Receiving Events

1. **Check URL accessibility**
   ```bash
   curl -X POST https://your-domain.com/webhook/github -d '{}' -H "Content-Type: application/json"
   ```

2. **Verify SSL certificate**
   - Must be valid, not self-signed (unless configured)
   - Check with: `openssl s_client -connect your-domain.com:443`

3. **Check firewall rules**
   - GitHub IPs: https://api.github.com/meta
   - GitLab IPs: Depends on instance
   - Bitbucket IPs: https://ip-ranges.atlassian.com/

### Signature Verification Failed

1. **Check webhook secret matches**
   - Server config must match platform config exactly
   - No trailing whitespace

2. **Check header names**
   - GitHub: `X-Hub-Signature-256`
   - GitLab: `X-Gitlab-Token`
   - Gitea: `X-Gitea-Signature`

### Rate Limiting

All platforms have rate limits:

| Platform | Rate Limit |
|----------|------------|
| GitHub | 5000/hour (authenticated) |
| GitLab | 600/minute |
| Bitbucket | 1000/hour |
| Gitea | Configurable |

If rate limited:
1. Check for redundant API calls
2. Implement caching (Redis recommended)
3. Consider using conditional requests (ETags)

---

## Multi-Platform Deployment

To serve multiple platforms from one deployment:

```yaml
# docker-compose.yml
services:
  rsr-certified:
    environment:
      - RSR_PLATFORMS=github,gitlab,bitbucket,gitea
      - GITHUB_APP_ID=...
      - GITHUB_PRIVATE_KEY=...
      - GITHUB_WEBHOOK_SECRET=...
      - GITLAB_TOKEN=...
      - GITLAB_WEBHOOK_SECRET=...
      - BITBUCKET_TOKEN=...
      - GITEA_TOKEN=...
      - GITEA_URL=https://gitea.yourcompany.com
```

Each platform's webhooks go to different endpoints:
- GitHub: `/webhook/github`
- GitLab: `/webhook/gitlab`
- Bitbucket: `/webhook/bitbucket`
- Gitea: `/webhook/gitea`
