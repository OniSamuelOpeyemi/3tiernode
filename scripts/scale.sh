#!/usr/bin/env bash
# scale.sh — Scale ECS services up, down, or to a specific count
# Usage:
#   ./scale.sh <service> <count>        — set exact desired count
#   ./scale.sh <service> up             — scale up by 1
#   ./scale.sh <service> down           — scale down by 1
#   ./scale.sh <service> zero           — scale to 0 (stop all tasks)
# Services: web | api | all
# Examples:
#   ./scale.sh web 4
#   ./scale.sh all up
#   ./scale.sh api zero

set -euo pipefail

CLUSTER="${ECS_CLUSTER:-node3tier-prod-cluster}"
WEB_SERVICE="${WEB_SERVICE:-node3tier-prod-web-svc}"
API_SERVICE="${API_SERVICE:-node3tier-prod-api-svc}"
REGION="${AWS_REGION:-us-east-1}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

usage() {
  echo "Usage: $0 <service: web|api|all> <count|up|down|zero>"
  exit 1
}

[ $# -ne 2 ] && usage

SERVICE="$1"
ACTION="$2"

scale_service() {
  local svc="$1"
  local action="$2"

  current=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$svc" \
    --region "$REGION" \
    --query "services[0].desiredCount" \
    --output text)

  case "$action" in
    up)    new_count=$((current + 1)) ;;
    down)
      if [ "$current" -le 1 ]; then
        echo -e "${YELLOW}[WARN] $svc is already at $current — refusing to scale below 1 (use 'zero' to stop)${NC}"
        return
      fi
      new_count=$((current - 1))
      ;;
    zero)  new_count=0 ;;
    ''|*[!0-9]*)
      echo -e "${RED}Invalid count: $action${NC}"
      usage
      ;;
    *)     new_count="$action" ;;
  esac

  echo -e "${GREEN}Scaling $svc: $current → $new_count${NC}"
  aws ecs update-service \
    --cluster  "$CLUSTER" \
    --service  "$svc" \
    --desired-count "$new_count" \
    --region   "$REGION" \
    --output   table \
    --query    "service.{Service:serviceName,Desired:desiredCount,Running:runningCount}"

  echo "Done. Use 'aws ecs describe-services' to monitor convergence."
}

case "$SERVICE" in
  web)  scale_service "$WEB_SERVICE" "$ACTION" ;;
  api)  scale_service "$API_SERVICE" "$ACTION" ;;
  all)
    scale_service "$WEB_SERVICE" "$ACTION"
    scale_service "$API_SERVICE" "$ACTION"
    ;;
  *)
    echo -e "${RED}Unknown service: $SERVICE${NC}"
    usage
    ;;
esac
