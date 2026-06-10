# Node 3-Tier CD Architecture on AWS

A production-grade, fully automated CI/CD architecture for a 3-tier Node.js application running on AWS ECS Fargate with CloudFront CDN, Aurora PostgreSQL, and GitHub Actions.

---

## Architecture Summary

| Tier | Service | Exposure |
|------|---------|----------|
| Web  | ECS Fargate + ALB + CloudFront | Internet-facing |
| API  | ECS Fargate + ALB + CloudFront | Internet-facing |
| DB   | Aurora PostgreSQL (Multi-AZ) | Private subnets only |