#!/usr/bin/env bash
# scripts/sync-secrets.sh
# Run once after terraform apply to push outputs → GitHub Secrets
# Requirements: gh CLI, aws CLI, jq, terraform
# Usage: ./scripts/sync-secrets.sh
# Example: ./scripts/sync-secrets.sh

set -euo pipefail

REPO="OniSamuelOpeyemi/3tiernode"
REGION="us-east-1"
TF_DIR="$(dirname "$0")/../terraform/environments/prod"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── Preflight checks ──────────────────────────────────────────────────────────
echo -e "${YELLOW}Checking required tools...${NC}"

for tool in gh aws jq terraform; do
  if ! command -v $tool &>/dev/null; then
    echo -e "${RED}Missing: $tool — please install it first${NC}"
    exit 1
  fi
done

# Check gh is authenticated
if ! gh auth status &>/dev/null; then
  echo -e "${RED}GitHub CLI not authenticated. Run: gh auth login${NC}"
  exit 1
fi

echo -e "${GREEN}All tools present.${NC}"

# ── Read Terraform outputs ────────────────────────────────────────────────────
echo -e "${YELLOW}Reading Terraform outputs from $TF_DIR ...${NC}"

cd "$TF_DIR"

# Verify terraform state exists
if ! terraform output &>/dev/null; then
  echo -e "${RED}No Terraform state found. Run terraform apply first.${NC}"
  exit 1
fi

ECR_WEB=$(terraform output -raw ecr_web_repo)
ECR_API=$(terraform output -raw ecr_api_repo)
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
CLOUDFRONT_WEB=$(terraform output -raw cloudfront_web_domain)
CLOUDFRONT_API=$(terraform output -raw cloudfront_api_domain)
DBHOST=$(terraform output -raw db_endpoint)
DB_NAME=$(terraform output -raw db_name)

# These are fixed — derived from your project_name + environment in Terraform
WEB_SERVICE="node3tier-prod-web-svc"
API_SERVICE="node3tier-prod-api-svc"
WEB_TASK_FAMILY="node3tier-prod-web"
API_TASK_FAMILY="node3tier-prod-api"

echo -e "${GREEN}Terraform outputs read successfully.${NC}"


# ── Push to GitHub Secrets ────────────────────────────────────────────────────
echo -e "${YELLOW}Pushing secrets to GitHub repo: $REPO ...${NC}"

gh secret set AWS_REGION            --body "$REGION"          --repo "$REPO"
gh secret set ECR_WEB_REPO          --body "$ECR_WEB"         --repo "$REPO"
gh secret set ECR_API_REPO          --body "$ECR_API"         --repo "$REPO"
gh secret set ECS_CLUSTER           --body "$ECS_CLUSTER"     --repo "$REPO"
gh secret set WEB_SERVICE           --body "$WEB_SERVICE"     --repo "$REPO"
gh secret set API_SERVICE           --body "$API_SERVICE"     --repo "$REPO"
gh secret set WEB_TASK_FAMILY       --body "$WEB_TASK_FAMILY" --repo "$REPO"
gh secret set API_TASK_FAMILY       --body "$API_TASK_FAMILY" --repo "$REPO"
gh secret set CLOUDFRONT_WEB_DOMAIN --body "$CLOUDFRONT_WEB"  --repo "$REPO"
gh secret set CLOUDFRONT_API_DOMAIN --body "$CLOUDFRONT_API"  --repo "$REPO"
gh secret set DBHOST                --body "$DBHOST"          --repo "$REPO"
gh secret set DB                    --body "$DB_NAME"         --repo "$REPO"
gh secret set DBPORT                --body "5432"             --repo "$REPO"

echo ""
echo -e "${GREEN}All secrets synced to GitHub successfully.${NC}"
echo ""
echo "Secrets set:"
echo "   AWS_REGION"
echo "   ECR_WEB_REPO        → $ECR_WEB"
echo "   ECR_API_REPO        → $ECR_API"
echo "   ECS_CLUSTER         → $ECS_CLUSTER"
echo "   WEB_SERVICE         → $WEB_SERVICE"
echo "   API_SERVICE         → $API_SERVICE"
echo "   WEB_TASK_FAMILY     → $WEB_TASK_FAMILY"
echo "   API_TASK_FAMILY     → $API_TASK_FAMILY"
echo "   CLOUDFRONT_WEB_DOMAIN → $CLOUDFRONT_WEB"
echo "   CLOUDFRONT_API_DOMAIN → $CLOUDFRONT_API"
echo "   DBHOST              → [sensitive]"
echo "   DB                  → $DB_NAME"
echo "   DBPORT              → 5432"
echo -e "${YELLOW}Next step: push code to main branch to trigger the pipeline.${NC}"