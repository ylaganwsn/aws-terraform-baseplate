output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_1_id" {
  value = module.vpc.public_subnet_1_id
}

output "public_subnet_2_id" {
  value = module.vpc.public_subnet_2_id
}

output "private_subnet_1_id" {
  value = module.vpc.private_subnet_1_id
}

output "private_subnet_2_id" {
  value = module.vpc.private_subnet_2_id
}

output "autoscaling_group_id" {
  value = module.ec2.autoscaling_group_id
}

output "rds_instance_endpoint" {
  value = module.rds.rds_instance_endpoint
}

output "rds_instance_id" {
  value = module.rds.rds_instance_id
}

output "Ec2InstanceLaunchTemplate_id" {
  value = module.ec2.Ec2InstanceLaunchTemplate_id
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.region
}

output "project_name" {
  value = var.project_name
}