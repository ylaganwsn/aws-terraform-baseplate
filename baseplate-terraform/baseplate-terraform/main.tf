terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Specify the version of the AWS provider if necessary  
    }
  }
  backend "s3" {
    encrypt   = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/vpc"

  environment           = var.environment
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  project_name          = var.project_name
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  region                = var.region
  vpc_cidr              = var.vpc_cidr
}

module "ec2" {
  source = "./modules/ec2"

  environment                     = var.environment
  project_name                    = var.project_name
  public_subnet_1_id              = module.vpc.public_subnet_1_id
  public_subnet_2_id              = module.vpc.public_subnet_2_id
  vpc_id                          = module.vpc.vpc_id
  instance_type                   = var.instance_type
  ec2_auto_scale_desired_capacity = var.autoscale_desired_capacity
  ec2_auto_scale_max_size         = var.autoscale_max_size
  ec2_auto_scale_min_size         = var.autoscale_min_size
  image_id                        = var.image_id
}

module "ec2imagebuilder" {
  source = "./modules/ec2imagebuilder"

  environment                = var.environment
  project_name               = var.project_name
  autoscale_desired_capacity = var.autoscale_desired_capacity
  autoscale_max_size         = var.autoscale_max_size
  autoscale_min_size         = var.autoscale_min_size
  image_id                   = var.image_id
  region                     = var.region
  php_version                = var.php_version
  upload_max_filesize        = var.upload_max_filesize
  post_max_size              = var.post_max_size
  instance_type              = var.instance_type
  image_version              = var.image_version
  node_version               = var.node_version
  ec2_launch_template        = module.ec2.Ec2InstanceLaunchTemplate_id
  account_id                 = data.aws_caller_identity.current.account_id
}

module "rds" {
  source = "./modules/rds"

  vpc_id                          = module.vpc.vpc_id
  environment                     = var.environment
  project_name                    = var.project_name
  private_subnet1                 = module.vpc.private_subnet_1_id
  private_subnet2                 = module.vpc.private_subnet_2_id
  ec2_instance_launch_template_sg = module.ec2.Ec2InstanceLaunchTemplateSG_id
  rds_instance                    = var.rds_instance
  master_username                 = var.master_username
  parameter_group                 = var.parameter_group
}

module "codepipeline" {
  source = "./modules/codepipeline"

  project_name          = var.project_name
  environment           = var.environment
  api_repository_url    = var.api_repository_url
  source_branch         = var.source_branch
  web_repository_url    = var.web_repository_url
  s3_object_key_zip     = var.s3_object_key_zip
  node_version          = var.node_version
  ec2_as_group_name     = module.ec2.autoscaling_group_id
}

module "redis" {
  source = "./modules/redis"

  project_name = var.project_name
  environment = var.environment
  vpc_id = module.vpc.vpc_id
  private_subnet1 = module.vpc.private_subnet_1_id
  private_subnet2 = module.vpc.private_subnet_2_id
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name = var.project_name
  environment = var.environment
  region = var.region
  alb_id = module.ec2.ALB_id
  alb_domain = module.ec2.ALB_DNS
}

module "cwalarms" {
  source = "./modules/cwalarms"

  project_name = var.project_name
  environment = var.environment
  ec2_as_group_name = module.ec2.autoscaling_group_id
}

resource "aws_ssm_parameter" "workspace_tfvars" {
  name        = "/terraform/${terraform.workspace}/tfvars"
  type        = "String"
  value       = file("${terraform.workspace}.tfvars")
  description = "Terraform variables for the ${terraform.workspace} environment"
}

resource "random_id" "laravel_app_key" {
  byte_length = 32
}

resource "random_id" "dev_console_key" {
  byte_length = 32
}

resource "aws_ssm_parameter" "envfile" {
  name        = "env-${var.environment}"
  description = "Environment variables for ${var.project_name} ${var.environment}"
  type        = "SecureString"

  value = <<EOT
APP_NAME=${var.project_name}
APP_ENV=staging
APP_KEY=base64:${random_id.laravel_app_key.b64_std}
APP_DEBUG=true
APP_URL=${var.base_url}
APP_CMS_URL=${var.cms_url}
FILAMENT_USING_SUBDOMAIN=true

TRUSTED_PROXIES="*,${var.vpc_cidr}"
CORS_ALLOWED_ORIGINS="${var.base_url},${var.cms_url},${var.web_url}"
DEV_CONSOLE_USERNAME="dev@appetiser.com.au"
DEV_CONSOLE_PASSWORD="${random_id.dev_console_key.b64_std}"
ENABLE_DEVCONSOLE=true
HORIZON_ENABLED=true

MEDIA_DISK=s3

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=${module.rds.rds_instance_endpoint}
DB_PORT=3306
DB_DATABASE=${var.project_name}_${var.environment}
DB_USERNAME=admin
DB_PASSWORD=${module.rds.rds_password}

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_URL=tls://:${var.project_name}^Appetiser2023@${module.redis.redis_primary_endpoint}:6379

MAIL_MAILER=ses
MAIL_FROM_ADDRESS=
MAIL_FROM_NAME="${var.project_name}"

AWS_DEFAULT_REGION=${var.region}
AWS_BUCKET=${module.elasticache.asset_bucket_id}
AWS_URL=https://${module.elasticache.cloudfront_url}
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

VITE_PUSHER_APP_KEY="$${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="$${PUSHER_HOST}"
VITE_PUSHER_PORT="$${PUSHER_PORT}"
VITE_PUSHER_SCHEME="$${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="$${PUSHER_APP_CLUSTER}"

TELESCOPE_ENABLED=true

SENTRY_LARAVEL_DSN=null
SENTRY_TRACES_SAMPLE_RATE=1.0

PLACES_API_KEY=
PLACES_RESTRICT_COUNTRY=

APP_USE_BYPASS_CODE=true

EOT

  overwrite = false

  lifecycle {
    ignore_changes = [
      value,
      version
    ]
  }
}

resource "aws_ssm_parameter" "envwebfile" {
  name        = "env-web-${var.environment}"
  description = "Environment variables for ${var.project_name} ${var.environment}"
  type        = "SecureString"

  value = <<EOT

NODE_ENV=staging
APP_ENV=staging
BASE_URL=${var.base_url}

  EOT
    overwrite = false

    lifecycle {
      ignore_changes = [
        value,
        version
      ]
    }
}