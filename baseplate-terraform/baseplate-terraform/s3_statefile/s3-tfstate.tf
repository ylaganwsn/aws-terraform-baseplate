terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Specify the version of the AWS provider if necessary  
    }
  }
}

variable "region" { default = "ap-southeast-2" }
variable "project_name" { default = "thelawyershub" }

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "prod_terraform_state" {
    bucket = "${var.project_name}-production-tfstate-bucket"

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket" "staging_terraform_state" {
    bucket = "${var.project_name}-staging-tfstate-bucket"

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket_versioning" "staging_bucket_versioning" {
  bucket = aws_s3_bucket.staging_terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "prod_bucket_versioning" {
  bucket = aws_s3_bucket.prod_terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_dynamodb_table" "prod_terraform_lock" {
  name         = "production-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_dynamodb_table" "staging_terraform_lock" {
  name         = "staging-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_dynamodb_table" "default_terraform_lock" {
  name         = "default-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
