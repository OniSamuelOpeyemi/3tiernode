resource "aws_ecr_repository" "web" {
  name                 = "${var.project_name}-${var.environment}-web"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  encryption_configuration { encryption_type = "AES256" }

  tags = { Name = "${var.project_name}-${var.environment}-web" }
}

resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  encryption_configuration { encryption_type = "AES256" }

  tags = { Name = "${var.project_name}-${var.environment}-api" }
}

# Lifecycle: keep last 10 images to save cost
resource "aws_ecr_lifecycle_policy" "web" {
  repository = aws_ecr_repository.web.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection     = { tagStatus = "any"; countType = "imageCountMoreThan"; countNumber = 10 }
      action        = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection     = { tagStatus = "any"; countType = "imageCountMoreThan"; countNumber = 10 }
      action        = { type = "expire" }
    }]
  })
}
