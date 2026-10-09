variable "project_name" {}
variable "environment" {}
variable "api_repository_url" {}
variable "source_branch" {}
variable "web_repository_url" {}
variable "ec2_as_group_name" {}
variable "s3_object_key_zip" {
  description = "The S3 object key for the ZIP file"
  type        = string
}
variable "node_version" {}