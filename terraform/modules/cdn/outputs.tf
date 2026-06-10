output "web_distribution_domain" { value = aws_cloudfront_distribution.web.domain_name }
output "api_distribution_domain" { value = aws_cloudfront_distribution.api.domain_name }
output "web_distribution_id"     { value = aws_cloudfront_distribution.web.id }
output "api_distribution_id"     { value = aws_cloudfront_distribution.api.id }
