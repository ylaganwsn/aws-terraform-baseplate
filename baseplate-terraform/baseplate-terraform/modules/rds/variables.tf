variable "environment" {
  description = "The environment (e.g., dev, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet1" {
  description = "The ID of the first private subnet"
  type        = string
}

variable "private_subnet2" {
  description = "The ID of the second private subnet"
  type        = string
}

variable "ec2_instance_launch_template_sg" {
  description = "The ID of the EC2 instance launch template security group"
  type        = string
}

variable "rds_instance" {
  description = "The instance type for the RDS instance"
  type        = string
}

variable "master_username" {
  description = "The master username for the RDS instance"
  type        = string
}

variable "parameter_group" {
  description = "The name of the RDS parameter group"
  type        = string
}