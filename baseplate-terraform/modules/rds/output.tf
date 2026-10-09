output "rds_instance_endpoint" {
  description = "The endpoint address of the RDS instance"
  value       = aws_db_instance.rds_db_instance.endpoint
}

output "rds_instance_id" {
  description = "The ID of the RDS instance"
  value       = aws_db_instance.rds_db_instance.id
}

output "rds_password" {
  value = random_password.rds_password.result
}