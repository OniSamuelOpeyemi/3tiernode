locals {
  prefix = "${var.project_name}-${var.environment}"
}

# DB Password stored in Secrets Manager
# resource "random_password" "db" {
#  length           = 24
#  special          = true
#  override_special = "!#$%&*()-_=+[]{}<>:?"
# }

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.prefix}-db-credentials"
  description             = "Aurora DB credentials for ${local.prefix}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}


# Security Group
resource "aws_security_group" "db" {
  name        = "${local.prefix}-db-sg"
  description = "Allow PostgreSQL access only from API ECS tasks"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefix}-db-sg" }
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${local.prefix}-aurora-cluster"
  engine                  = "aurora-postgresql"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = var.db_subnet_group
  vpc_security_group_ids  = [aws_security_group.db.id]

  backup_retention_period  = var.backup_retention
  preferred_backup_window  = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  storage_encrypted        = true
  deletion_protection      = false
  skip_final_snapshot      = false
  final_snapshot_identifier = "${local.prefix}-final-snapshot"
  copy_tags_to_snapshot    = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = { Name = "${local.prefix}-aurora-cluster" }
}

# Aurora Instances (Multi-AZ) 
resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${local.prefix}-aurora-writer"
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.t4g.medium"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  publicly_accessible  = false
  monitoring_interval  = 60
  monitoring_role_arn  = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${local.prefix}-aurora-writer", Role = "writer" }
}

resource "aws_rds_cluster_instance" "reader" {
  identifier           = "${local.prefix}-aurora-reader"
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.t4g.medium"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  publicly_accessible  = false
  monitoring_interval  = 60
  monitoring_role_arn  = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${local.prefix}-aurora-reader", Role = "reader" }
}

# Enhanced Monitoring Role 
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.prefix}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group for Aurora PostgreSQL
resource "aws_cloudwatch_log_group" "aurora_postgresql" {
  name              = "/aws/rds/cluster/${local.prefix}-aurora-cluster/postgresql"
  retention_in_days = 30
}
