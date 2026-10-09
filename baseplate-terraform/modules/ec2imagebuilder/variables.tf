variable "environment" {
    description = "The environment name"
    type        = string
}

variable "project_name" {
    description = "The name of the project"
    type        = string
}

variable "autoscale_desired_capacity" {
    description = "The desired capacity for the autoscaling group"
    type        = number
}

variable "autoscale_max_size" {
    description = "The maximum size for the autoscaling group"
    type        = number
}

variable "autoscale_min_size" {
    description = "The minimum size for the autoscaling group"
    type        = number
}

variable "instance_type" {
    description = "The ID of the AMI to use for the EC2 instances"
    type        = string
}
variable "image_id" {
    description = "The ID of the AMI to use for the EC2 instances"
    type        = string
}

variable "region" {}
variable image_version {}
variable php_version {}
variable upload_max_filesize {}
variable post_max_size {}
variable node_version {}
variable ec2_launch_template {}
variable account_id {}