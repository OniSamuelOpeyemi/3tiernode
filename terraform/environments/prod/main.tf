terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "3teirnodeprod-sammy-bucket" # Replace with your aws_s3_bucket
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "3teirnodeprod-sammy-table" # Replace with your DynamoDB table
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Networking 
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# ECR (container registry)
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# Database (RDS Aurora PostgreSQL)
module "database" {
  source = "../../modules/database"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_subnet_group    = module.vpc.db_subnet_group_name
  allowed_sg_ids     = [module.ecs.api_sg_id]
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  backup_window      = "02:00-03:00"
  maintenance_window = "sun:04:00-sun:05:00"
  backup_retention   = 7
}

# ECS (Web + API tiers)
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  web_image          = "${module.ecr.web_repo_url}:latest"
  api_image          = "${module.ecr.api_repo_url}:latest"
  db_host            = module.database.cluster_endpoint
  db_name            = var.db_name
  db_secret_arn      = module.database.db_secret_arn
  aws_region         = var.aws_region
  web_cpu            = var.web_cpu
  web_memory         = var.web_memory
  api_cpu            = var.api_cpu
  api_memory         = var.api_memory
  web_desired_count  = var.web_desired_count
  api_desired_count  = var.api_desired_count
  web_port           = 3000
  api_port           = 4000
}

# CDN (CloudFront) 
module "cdn" {
  source = "../../modules/cdn"

  project_name = var.project_name
  environment  = var.environment
  web_alb_dns  = module.ecs.web_alb_dns_name
  api_alb_dns  = module.ecs.api_alb_dns_name
}

# Monitoring 
module "monitoring" {
  source = "../../modules/monitoring"

  project_name     = var.project_name
  environment      = var.environment
  web_alb_arn      = module.ecs.web_alb_arn
  api_alb_arn      = module.ecs.api_alb_arn
  ecs_cluster_name = module.ecs.cluster_name
  web_service_name = module.ecs.web_service_name
  api_service_name = module.ecs.api_service_name
  db_cluster_id    = module.database.cluster_id
  alarm_email      = var.alarm_email
}
