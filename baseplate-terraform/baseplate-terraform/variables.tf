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

variable "image_version" {
  description = "Image Version"
  default     = "1.0.0"
}

variable "autoscale_desired_capacity" {
  description = "Autoscale Desired Capacity"
  default     = 0
}

variable "autoscale_max_size" {
  description = "Autoscale Max Size"
  default     = 0
}

variable "autoscale_min_size" {
  description = "Autoscale Min Size"
  default     = 0
}

variable "image_id" {
  description = "Image ID"
  default     = "ami-097e2dc60290db13c"
}

variable "php_version" {
  description = "PHP Version"
  default     = "8.2"
}

variable "upload_max_filesize" {
  description = "Upload Max Filesize"
  default     = "100M"
}

variable "post_max_size" {
  description = "Post Max Size"
  default     = "100M"
}

variable "instance_type" {
  description = "Instance Type"
  default     = "t4g.small"
}

variable "master_username" {
  description = "Master Username"
  default     = "admin"
}

variable "rds_instance" {
  description = "RDS Instance"
  default     = "db.t3.micro"
}

variable "parameter_group" {
  description = "Parameter Group"
  default     = "default"
}

variable "s3_object_key_zip" {
  description = "S3 Object Key Zip"
  default     = "start-pipeline.zip"
}

variable "source_branch" {
  description = "Source Branch"
  default     = "develop"
}

variable "api_repository_url" {
  description = "API Repository URL"
  default     = "your_api_repository_url"
}

variable "cms_repository_url" {
  description = "CMS Repository URL"
  default     = "your_cms_repository_url"
}

variable "web_repository_url" {
  description = "Web Repository URL"
  default     = "your_web_repository_url"
}

variable "base_url" {
  description = "Base URL"
  default     = "your_base_url"
}

variable "vue_app_api_url" {
  description = "Vue App API URL"
  default     = "your_vue_app_api_url"
}

variable "node_version" {
  default = 22
}

variable "cms_url" {
  default = "https://cms.appetiserdev.tech"
}