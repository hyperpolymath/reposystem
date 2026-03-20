# .git-private-farm
image:https://img.shields.io/badge/License-MPL_2.0-blue.svg[MPL-2.0-or-later,link="https://opensource.org/licenses/MPL-2.0"]



Private orchestration hub for rapid multi-forge propagation.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    .git-private-farm (GitHub Private)            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  farm-manifest.json     - All repos and their forge URLs   │  │
│  │  dispatch-keys/         - SSH keys for each forge          │  │
│  │  .github/workflows/     - Rapid propagation workflows      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │ repository_dispatch / workflow_dispatch │
              └──────────────────┼──────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
   ┌──────────┐           ┌──────────┐           ┌──────────┐
   │  GitLab  │           │SourceHut │           │ Codeberg │
   │   job    │           │   job    │           │   job    │
   └──────────┘           └──────────┘           └──────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                         All run in parallel
                       (~5-10 seconds total)
```

## Rapid Propagation Modes

### 1. Instant Push (All Forges)
Triggered on every push to a repo. Propagates to all configured forges.

```bash
# From any repo with the webhook configured
git push origin main  # Automatically triggers propagation
```

### 2. Selective Push (Specific Forges)
Use workflow dispatch to push to specific forges only.

```bash
gh workflow run propagate.yml \
  -f repo=bitfuckit \
  -f forges="gitlab,codeberg" \
  --repo hyperpolymath/.git-private-farm
```

### 3. Batch Push (All Repos)
Propagate all repos to all forges at once.

```bash
gh workflow run batch-propagate.yml \
  --repo hyperpolymath/.git-private-farm
```

## Setup

1. Create the private repo:
   ```bash
   gh repo create .git-private-farm --private
   ```

2. Add secrets for each forge:
   - `GITLAB_SSH_KEY`
   - `SOURCEHUT_SSH_KEY`
   - `CODEBERG_SSH_KEY`
   - `BITBUCKET_SSH_KEY`

3. Configure webhooks on source repos to trigger `repository_dispatch`

## Security

- This repo is PRIVATE - contains SSH keys and forge credentials
- Uses encrypted secrets, never commits raw keys
- Audit log tracks all propagation events
