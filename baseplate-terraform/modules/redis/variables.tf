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
