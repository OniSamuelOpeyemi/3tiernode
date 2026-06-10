#!/usr/bin/env bash
# rollback.sh — Roll back a service to a previous task definition revision
# Usage:
#   ./rollback.sh web            — roll back to the previous (N-1) revision
#   ./rollback.sh api 42         — roll back api to a specific revision
#   ./rollback.sh all            — roll back both web and api to previous revision
set -euo pipefail

CLUSTER="${ECS_CLUSTER:-node3tier-prod-cluster}"
WEB_SERVICE="${WEB_SERVICE:-node3tier-prod-web-svc}"
API_SERVICE="${API_SERVICE:-node3tier-prod-api-svc}"
WEB_FAMILY="${WEB_TASK_FAMILY:-node3tier-prod-web}"
API_FAMILY="${API_TASK_FAMILY:-node3tier-prod-api}"
REGION="${AWS_REGION:-us-east-1}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

rollback_service() {
  local svc="$1"
  local family="$2"
  local target_rev="${3:-}"

  # Get list of active task definition revisions
  revisions=$(aws ecs list-task-definitions \
    --family-prefix "$family" \
    --status ACTIVE \
    --sort DESC \
    --region "$REGION" \
    --query "taskDefinitionArns" \
    --output text | tr '\t' '\n')

  current_rev=$(echo "$revisions" | head -1)

  if [ -z "$target_rev" ]; then
    # Default: previous revision
    rollback_arn=$(echo "$revisions" | sed -n '2p')
    if [ -z "$rollback_arn" ]; then
      echo -e "${RED}No previous revision found for $family.${NC}"
      return 1
    fi
  else
    rollback_arn="${family}:${target_rev}"
  fi

  echo -e "${YELLOW}Rolling back $svc${NC}"
  echo "  Current:  $current_rev"
  echo "  Target:   $rollback_arn"

  read -r -p "Proceed? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }

  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$svc" \
    --task-definition "$rollback_arn" \
    --region "$REGION" \
    --force-new-deployment \
    --query "service.{Service:serviceName,TaskDef:taskDefinition}" \
    --output table

  echo "Waiting for $svc to stabilise..."
  aws ecs wait services-stable \
    --cluster "$CLUSTER" --services "$svc" --region "$REGION"
  echo -e "${GREEN}$svc rolled back successfully.${NC}"
}

TARGET="${1:-}"
SPECIFIC_REV="${2:-}"

[ -z "$TARGET" ] && { echo "Usage: $0 <web|api|all> [revision]"; exit 1; }

case "$TARGET" in
  web)  rollback_service "$WEB_SERVICE" "$WEB_FAMILY" "$SPECIFIC_REV" ;;
  api)  rollback_service "$API_SERVICE" "$API_FAMILY" "$SPECIFIC_REV" ;;
  all)
    rollback_service "$WEB_SERVICE" "$WEB_FAMILY" "$SPECIFIC_REV"
    rollback_service "$API_SERVICE" "$API_FAMILY" "$SPECIFIC_REV"
    ;;
  *)
    echo -e "${RED}Unknown target: $TARGET${NC}"
    exit 1
    ;;
esac
