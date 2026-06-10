#!/usr/bin/env bash
# stop.sh — Gracefully stop all ECS tasks (scale to zero)
# Usage: ./stop.sh [web|api|all]   (default: all)
set -euo pipefail

CLUSTER="${ECS_CLUSTER:-node3tier-prod-cluster}"
WEB_SERVICE="${WEB_SERVICE:-node3tier-prod-web-svc}"
API_SERVICE="${API_SERVICE:-node3tier-prod-api-svc}"
REGION="${AWS_REGION:-us-east-1}"
TARGET="${1:-all}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

stop_svc() {
  local svc="$1"
  echo -e "${YELLOW}Stopping $svc (scaling to 0)...${NC}"
  aws ecs update-service \
    --cluster "$CLUSTER" --service "$svc" \
    --desired-count 0 --region "$REGION" \
    --query "service.{Service:serviceName,DesiredCount:desiredCount}" \
    --output table
  echo -e "${GREEN}$svc stopped.${NC}"
}

case "$TARGET" in
  web)  stop_svc "$WEB_SERVICE" ;;
  api)  stop_svc "$API_SERVICE" ;;
  all)
    stop_svc "$WEB_SERVICE"
    stop_svc "$API_SERVICE"
    ;;
  *)
    echo -e "${RED}Unknown target: $TARGET. Use web | api | all${NC}"
    exit 1
    ;;
esac
