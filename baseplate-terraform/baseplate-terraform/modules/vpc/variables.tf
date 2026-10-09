variable "vpc_cidr" {
  description = "VPC CIDR Block"
}

variable "public_subnet_1_cidr" {
  description = "Public Subnet 1 CIDR Block"
}

variable "public_subnet_2_cidr" {
  description = "Public Subnet 2 CIDR Block"
}

variable "private_subnet_1_cidr" {
  description = "Private Subnet 1 CIDR Block"
}

variable "private_subnet_2_cidr" {
  description = "Private Subnet 2 CIDR Block"
}

variable "region" {
  description = "AWS Region"
}

variable "project_name" {
  description = "Project Name"
}

variable "environment" {
  description = "Environment"
}

/**
variable "vpc_id" {
  description = "The VPC ID where resources will be deployed"
}
variable "autoscale_desired_capacity" {
  description = "The desired capacity of the Auto Scaling group"
}

variable "autoscale_max_size" {
  description = "The maximum size of the Auto Scaling group"
}

variable "autoscale_min_size" {
  description = "The minimum size of the Auto Scaling group"
}

variable "public_subnet_1_id" {
  description = "The first public subnet ID"
}

variable "public_subnet_2_id" {
  description = "The second public subnet ID"
}
**/