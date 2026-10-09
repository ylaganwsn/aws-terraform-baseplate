output "asset_bucket_id" {
  value = aws_s3_bucket.asset_bucket.id
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cloudfront_distribution.domain_name
}