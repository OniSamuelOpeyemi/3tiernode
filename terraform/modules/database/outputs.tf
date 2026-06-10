output "cluster_endpoint"       { value = aws_rds_cluster.main.endpoint; sensitive = true }
output "reader_endpoint"        { value = aws_rds_cluster.main.reader_endpoint; sensitive = true }
output "cluster_id"             { value = aws_rds_cluster.main.id }
output "db_secret_arn"          { value = aws_secretsmanager_secret.db.arn }
output "db_security_group_id"   { value = aws_security_group.db.id }
