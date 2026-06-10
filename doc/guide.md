
## Prerequisites

- AWS CLI v2 configured (`aws configure`)
- Terraform ≥ 1.6
- Docker
- GitHub repository with Actions enabled

---

## First-Time Setup

### Bootstrap Terraform State

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket my-tfstate-bucket \   
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket my-tfstate-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name my-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `terraform/environments/prod/main.tf` backend block with your bucket/table names.

### Deploy Infrastructure

```bash
cd terraform/environments/prod

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Capture the outputs — you'll need them for GitHub secrets:

```bash
terraform output
```

###  Configure GitHub Secrets

In your repository → Settings → Secrets and variables → Actions, add:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `ECR_WEB_REPO` | `terraform output ecr_web_repo` |
| `ECR_API_REPO` | `terraform output ecr_api_repo` |
| `ECS_CLUSTER` | `terraform output ecs_cluster_name` |
| `WEB_SERVICE` | `node3tier-prod-web-svc` |
| `API_SERVICE` | `node3tier-prod-api-svc` |
| `WEB_TASK_FAMILY` | `node3tier-prod-web` |
| `API_TASK_FAMILY` | `node3tier-prod-api` |
| `CLOUDFRONT_WEB_DOMAIN` | `terraform output cloudfront_web_domain` |
| `CLOUDFRONT_API_DOMAIN` | `terraform output cloudfront_api_domain` |

### Use scripts/sync-secrets.sh
scripts/sync-secrets.sh let you sync your terraform output to Github secret

### Make it executable
``` bash 
chmod +x scripts/sync-secrets.sh
./scripts/sync-secrets.sh

```
### Before running, make sure you have;

``` bash 
# 1. gh CLI installed and authenticated
gh auth login

# 2. jq installed
sudo apt install jq      # Ubuntu/Debian
# or
brew install jq          # Mac

# 3. AWS CLI pointing to the right account
aws sts get-caller-identity

# 4. Terraform apply already completed
cd terraform/environments/prod && terraform output

```

###  Push a commit to `main` to trigger the pipeline

---

## CI/CD Pipeline

```
Push to main
    │
    ├── test          (unit + integration tests, PostgreSQL service container)
    ├── security      (Trivy filesystem scan + npm audit)
    ├── build         (Docker build → ECR, image vulnerability scan)
    └── deploy        (Rolling ECS update → smoke tests)
```

The `deploy` job uses the GitHub **production** environment — configure manual approval gates there if required.

----
# Set up the production environment
This enables the manual approval gate before deploy runs.

Settings
    ↓
Environments (left sidebar)
    ↓
New environment
    ↓
Name it exactly: production
    ↓
Configure environment
    ↓
Check "Required reviewers"
    ↓
Add yourself as reviewer
    ↓
Save protection rules

---

## Operational Scripts

Make scripts executable first:

```bash
chmod +x scripts/*.sh
```

### Start / Stop / Scale

```bash
# Stop all services (maintenance window)
./scripts/stop.sh all

# Start services back up
./scripts/start.sh all 2

# Scale web to 6 tasks
./scripts/scale.sh web 6

# Scale api up by 1
./scripts/scale.sh api up
```

### Rollback

```bash
# Roll back web to previous revision
./scripts/rollback.sh web

# Roll back api to specific revision
./scripts/rollback.sh api 42
```

### Manual Database Backup

```bash
export DB_CLUSTER_ID=node3tier-prod-aurora-cluster
./scripts/backup.sh
```

Aurora automated backups run daily at 02:00–03:00 UTC with 7-day retention per the Terraform config. The backup script creates additional on-demand snapshots and prunes those older than 30 days.

---

## Monitoring

- CloudWatch Dashboard: `node3tier-prod-overview` (ECS CPU/memory, ALB latency, Aurora metrics, error rates)
- Container Insights: enabled on the ECS cluster
- Alarms fire to SNS → email for: ECS CPU > 80%, ALB 5xx > 10/min, Aurora CPU > 80%, DB connections > 100

---

## Key Design Decisions

**ECS Fargate over EKS**: No control plane to manage, native ALB integration, built-in Fargate Spot for cost savings, sufficient for this application's scale requirements.

**Rolling deployments**: `deployment_minimum_healthy_percent = 100` with `deployment_maximum_percent = 200` ensures zero downtime — new tasks must be healthy before old ones are deregistered. ECS Circuit Breaker auto-rolls back on failure.

**CloudFront in front of both ALBs**: Terminates TLS at edge, provides geo-distribution, static asset caching for web tier, and DDoS protection via AWS Shield Standard.

**Aurora Multi-AZ**: Writer + reader instance across AZs, automated daily backups, 7-day retention, encrypted at rest, logs exported to CloudWatch.

**No DB internet access**: RDS security group allows port 5432 only from the API ECS task security group. DB subnets have no internet gateway route.
