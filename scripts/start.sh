#!/usr/bin/env bash
# start.sh — Restore ECS services to their desired minimum count
# Usage: ./start.sh [web|api|all] [desired_count]
set -euo pipefail

CLUSTER="${ECS_CLUSTER:-node3tier-prod-cluster}"
WEB_SERVICE="${WEB_SERVICE:-node3tier-prod-web-svc}"
API_SERVICE="${API_SERVICE:-node3tier-prod-api-svc}"
REGION="${AWS_REGION:-us-east-1}"
TARGET="${1:-all}"
COUNT="${2:-2}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

start_svc() {
  local svc="$1"
  echo -e "${GREEN}Starting $svc (desired count → $COUNT)...${NC}"
  aws ecs update-service \
    --cluster "$CLUSTER" --service "$svc" \
    --desired-count "$COUNT" --region "$REGION" \
    --query "service.{Service:serviceName,DesiredCount:desiredCount}" \
    --output table

  echo "Waiting for service to stabilise..."
  aws ecs wait services-stable \
    --cluster "$CLUSTER" --services "$svc" --region "$REGION"
  echo -e "${GREEN}$svc is healthy.${NC}"
}

case "$TARGET" in
  web)  start_svc "$WEB_SERVICE" ;;
  api)  start_svc "$API_SERVICE" ;;
  all)
    start_svc "$WEB_SERVICE"
    start_svc "$API_SERVICE"
    ;;
  *)
    echo -e "${RED}Unknown target: $TARGET. Use web | api | all${NC}"
    exit 1
    ;;
esac
