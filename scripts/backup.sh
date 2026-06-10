#!/usr/bin/env bash
# backup.sh — Trigger an Aurora manual snapshot + export to S3
# Aurora automated backups run daily per the Terraform config (retention = 7 days).
# This script creates an on-demand snapshot for longer-term archival.
# Usage: ./backup.sh [snapshot_suffix]   (default: manual-YYYYMMDD-HHMMSS)
set -euo pipefail

CLUSTER_ID="${DB_CLUSTER_ID:-node3tier-prod-aurora-cluster}"
REGION="${AWS_REGION:-us-east-1}"
BACKUP_BUCKET="${BACKUP_BUCKET:-}"   # Optional: set to export to S3 via RDS Export
SUFFIX="${1:-manual-$(date +%Y%m%d-%H%M%S)}"
SNAPSHOT_ID="${CLUSTER_ID}-${SUFFIX}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}[$(date -u +%FT%TZ)] Creating Aurora snapshot: $SNAPSHOT_ID${NC}"

# 1. Create snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier   "$CLUSTER_ID" \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$REGION" \
  --tags Key=CreatedBy,Value=backup-script Key=Date,Value="$(date +%Y-%m-%d)"

echo "Waiting for snapshot to become available..."
aws rds wait db-cluster-snapshot-available \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$REGION"

echo -e "${GREEN}Snapshot $SNAPSHOT_ID is available.${NC}"

# 2. Optionally export snapshot to S3 (long-term archival)
if [ -n "$BACKUP_BUCKET" ]; then
  EXPORT_TASK_ID="${CLUSTER_ID}-export-${SUFFIX}"
  IAM_ROLE_ARN="${BACKUP_IAM_ROLE_ARN:-}"

  if [ -z "$IAM_ROLE_ARN" ]; then
    echo -e "${YELLOW}[WARN] BACKUP_IAM_ROLE_ARN not set — skipping S3 export.${NC}"
  else
    SNAPSHOT_ARN=$(aws rds describe-db-cluster-snapshots \
      --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
      --region "$REGION" \
      --query "DBClusterSnapshots[0].DBClusterSnapshotArn" \
      --output text)

    echo "Exporting snapshot to s3://$BACKUP_BUCKET/$EXPORT_TASK_ID ..."
    aws rds start-export-task \
      --export-task-identifier "$EXPORT_TASK_ID" \
      --source-arn             "$SNAPSHOT_ARN" \
      --s3-bucket-name         "$BACKUP_BUCKET" \
      --s3-prefix              "aurora-exports/" \
      --iam-role-arn           "$IAM_ROLE_ARN" \
      --kms-key-id             "alias/aws/rds" \
      --region                 "$REGION"
    echo -e "${GREEN}Export task $EXPORT_TASK_ID started.${NC}"
  fi
fi

# 3. List existing snapshots and delete those older than 30 days
echo "Pruning snapshots older than 30 days..."
CUTOFF=$(date -d "-30 days" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -v-30d +%Y-%m-%dT%H:%M:%S)

aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier "$CLUSTER_ID" \
  --snapshot-type manual \
  --region "$REGION" \
  --query "DBClusterSnapshots[?SnapshotCreateTime<='$CUTOFF'].DBClusterSnapshotIdentifier" \
  --output text | tr '\t' '\n' | while read -r old_snap; do
    [ -z "$old_snap" ] && continue
    echo -e "${YELLOW}Deleting old snapshot: $old_snap${NC}"
    aws rds delete-db-cluster-snapshot \
      --db-cluster-snapshot-identifier "$old_snap" \
      --region "$REGION"
  done

echo -e "${GREEN}[$(date -u +%FT%TZ)] Backup complete.${NC}"
