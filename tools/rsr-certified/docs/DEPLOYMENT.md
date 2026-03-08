# Deploying RSR-Certified

This guide covers deploying RSR-Certified to serve as your compliance checking infrastructure.

## Quick Start

### Option 1: Docker/Podman (Recommended)

```bash
# Pull the image
podman pull ghcr.io/hyperpolymath/rsr-certified:latest

# Run with basic config
podman run -d \
  --name rsr-certified \
  -p 8080:8080 \
  -e GITHUB_WEBHOOK_SECRET=your-secret-here \
  -e GITHUB_APP_ID=your-app-id \
  -e GITHUB_PRIVATE_KEY="$(cat private-key.pem)" \
  ghcr.io/hyperpolymath/rsr-certified:latest
```

### Option 2: Docker Compose

```bash
cd container/
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

### Option 3: Build from Source

```bash
cargo build --release
./target/release/rsr serve --port 8080
```

## Platform Setup

### GitHub App

1. **Create the App**
   - Go to GitHub Settings > Developer settings > GitHub Apps > New GitHub App
   - Or use manifest flow: `https://github.com/settings/apps/new?manifest=<base64-encoded-manifest>`

2. **Configure the App**
   ```
   App name: RSR-Certified (or your custom name)
   Homepage URL: https://your-domain.com
   Webhook URL: https://your-domain.com/webhook/github
   Webhook secret: <generate a strong secret>
   ```

3. **Set Permissions**
   - Repository contents: Read
   - Pull requests: Read & Write
   - Checks: Read & Write
   - Commit statuses: Read & Write
   - Metadata: Read

4. **Subscribe to Events**
   - Push
   - Pull request
   - Check run
   - Check suite

5. **Generate Private Key**
   - Download the .pem file
   - Store securely (never commit to git!)

6. **Install on Repositories**
   - Go to your app's page
   - Click "Install App"
   - Select repositories

### GitLab Integration

1. **Create Access Token**
   - Go to Settings > Access Tokens
   - Create token with `api` and `read_repository` scopes

2. **Configure Webhooks**
   - Go to Settings > Webhooks
   - URL: `https://your-domain.com/webhook/gitlab`
   - Secret Token: Generate and save
   - Triggers: Push events, Merge request events

3. **Set Environment Variables**
   ```bash
   GITLAB_TOKEN=your-access-token
   GITLAB_WEBHOOK_SECRET=your-webhook-secret
   ```

### Bitbucket Integration

1. **Create App Password**
   - Go to Personal settings > App passwords
   - Create with repository read permission

2. **Configure Webhooks**
   - Repository settings > Webhooks
   - URL: `https://your-domain.com/webhook/bitbucket`
   - Triggers: Push, Pull Request

3. **Set Environment Variables**
   ```bash
   BITBUCKET_TOKEN=your-app-password
   ```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `RSR_LOG_LEVEL` | Log verbosity (trace/debug/info/warn/error) | No (default: info) |
| `RSR_PLATFORMS` | Comma-separated list of enabled platforms | No (default: github,gitlab,bitbucket) |
| `RSR_REDIS_URL` | Redis URL for job queue | No (optional caching) |
| `GITHUB_APP_ID` | GitHub App ID | For GitHub |
| `GITHUB_PRIVATE_KEY` | GitHub App private key (PEM contents) | For GitHub |
| `GITHUB_WEBHOOK_SECRET` | Webhook signature secret | For GitHub |
| `GITLAB_TOKEN` | GitLab access token | For GitLab |
| `GITLAB_WEBHOOK_SECRET` | Webhook secret | For GitLab |
| `BITBUCKET_TOKEN` | Bitbucket app password | For Bitbucket |

## Production Deployment

### Kubernetes

```bash
# Create secrets
kubectl create secret generic rsr-secrets \
  --from-literal=github-webhook-secret=YOUR_SECRET \
  --from-file=github-private-key=./private-key.pem

# Apply manifests
kubectl apply -f container/k8s/
```

### Cloud Platforms

#### AWS (ECS/Fargate)

```bash
# Create task definition
aws ecs register-task-definition --cli-input-json file://aws-task-def.json

# Create service
aws ecs create-service \
  --cluster your-cluster \
  --service-name rsr-certified \
  --task-definition rsr-certified:1
```

#### Google Cloud Run

```bash
gcloud run deploy rsr-certified \
  --image ghcr.io/hyperpolymath/rsr-certified:latest \
  --platform managed \
  --port 8080 \
  --set-env-vars="GITHUB_WEBHOOK_SECRET=..." \
  --set-secrets="GITHUB_PRIVATE_KEY=github-key:latest"
```

#### Azure Container Instances

```bash
az container create \
  --resource-group your-rg \
  --name rsr-certified \
  --image ghcr.io/hyperpolymath/rsr-certified:latest \
  --ports 8080 \
  --environment-variables GITHUB_WEBHOOK_SECRET=...
```

## Reverse Proxy Setup

### Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name rsr.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/rsr.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rsr.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy

```caddyfile
rsr.yourdomain.com {
    reverse_proxy localhost:8080
}
```

## Health Checks

The service exposes:
- `GET /health` - Returns 200 if healthy
- `GET /metrics` - Prometheus metrics

## Monitoring

### Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: 'rsr-certified'
    static_configs:
      - targets: ['rsr-certified:8080']
    metrics_path: /metrics
```

## Troubleshooting

### Webhook not receiving events

1. Check webhook URL is publicly accessible
2. Verify SSL certificate is valid
3. Check webhook secret matches
4. Review logs: `podman logs rsr-certified`

### Check runs not appearing

1. Verify GitHub App has `checks:write` permission
2. Ensure app is installed on the repository
3. Check for rate limiting

### Badge not loading

1. Verify the badge endpoint is accessible
2. Check for caching issues (badges cache for 5 minutes)
3. Ensure repository is public or token has access
