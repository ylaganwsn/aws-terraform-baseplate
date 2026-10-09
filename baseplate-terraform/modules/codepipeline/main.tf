resource "aws_s3_bucket" "deployments_bucket" {
  bucket = "${var.project_name}-${var.environment}-deployments"

  tags = {
    env = "build"
  }
}

locals {
  web_env = var.environment == "staging" ? "env-web-dev" : "env-web-prod"
}

resource "aws_s3_bucket_versioning" "deployments_bucket_versioning" {
  bucket = aws_s3_bucket.deployments_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-${var.environment}-codebuild-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "CanAccessS3DeploymentsBucket"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = "s3:GetObject"
          Resource = "${aws_s3_bucket.deployments_bucket.arn}/*"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  lifecycle {
    ignore_changes = [
      assume_role_policy,
      inline_policy,
      managed_policy_arns,
    ]
  }

}

resource "aws_codebuild_project" "api_codebuild" {
  name          = "${var.project_name}-${var.environment}-api-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 5
  queued_timeout = 60

  source {
    type = "NO_SOURCE"
    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      php: 8.4
      nodejs: 20
    commands:
      - composer self-update 2.7.9
    finally:
      - echo 'Build complete'
  build:
    commands:
      - git clone --single-branch --depth 1 --branch $REPOSITORY_BRANCH $REPOSITORY_URL repo 
      - cd repo
      - aws --region=ap-southeast-2 ssm get-parameter --name /env-${var.environment} --with-decryption --output text --query "Parameter.Value" > .env
      - composer install --ignore-platform-reqs --prefer-dist --optimize-autoloader --no-dev
      - npm install
      - npm run build
    finally:
      - echo 'Build complete'
artifacts:
  name: $(date -u +'%Y-%m-%d-%H-%M-%S')-bundle.zip
  type: zip
  base-directory: repo
  files:
    - '**/*'
  exclude-paths:
    - '.git'
    - '.gitignore'
    - '**/.git'
EOF
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    environment_variable {
      name  = "REPOSITORY_URL"
      value = var.api_repository_url
    }
    environment_variable {
      name  = "REPOSITORY_BRANCH"
      value = var.source_branch
    }
  }

  artifacts {
    type = "S3"
    location = aws_s3_bucket.deployments_bucket.bucket
    path = "api"
    packaging = "ZIP"
    override_artifact_name = true
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    env = "build"
  }
}

resource "aws_codedeploy_app" "api_application" {
  name = "${var.project_name}-api-${var.environment}"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "api_deployment_group" {
  app_name              = aws_codedeploy_app.api_application.name
  deployment_group_name = "${var.project_name}-${var.environment}-dg"
  service_role_arn      = aws_iam_role.codedeploy_iam_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  
  /**
  auto_rollback_configuration {
    enabled = false
  }
  */

    autoscaling_groups = [var.ec2_as_group_name]
}

resource "aws_iam_role" "codedeploy_iam_role" {
  name = "${var.project_name}-${var.environment}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "CodeDeployTrustPolicy"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "CodeDeployLaunchASGInstances"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "iam:PassRole",
            "ec2:CreateTags",
            "ec2:RunInstances"
          ]
          Resource = "*"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  ]
}

resource "aws_codepipeline" "api_codepipeline" {
  name     = "${var.project_name}-api-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.deployments_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        S3Bucket    = aws_s3_bucket.deployments_bucket.bucket
        S3ObjectKey = var.s3_object_key_zip
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.api_codebuild.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.api_application.name
        DeploymentGroupName = aws_codedeploy_deployment_group.api_deployment_group.deployment_group_name
      }
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-${var.environment}-codepipeline-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

resource "aws_codebuild_project" "web_codebuild" {
  name          = "${var.project_name}-${var.environment}-web-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 300
  queued_timeout = 60

  source {
    type = "NO_SOURCE"
    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: ${var.node_version}
    finally:
      - echo 'Build complete'
  build:
    commands:
      - git clone --single-branch --depth 1 --branch $REPOSITORY_BRANCH $REPOSITORY_URL repo
      - cd repo
      - aws --region=ap-southeast-2 ssm get-parameter --name /env-web-${var.environment} --with-decryption --output text --query "Parameter.Value" > .env
      - npm install --legacy-peer-deps
      - npm run build 
    finally:
      - echo 'Build complete'
artifacts:
  name: $(date -u +'%Y-%m-%d-%H-%M-%S')-bundle.zip
  type: zip
  base-directory: repo
  files:
    - '**/*'
  exclude-paths:
    - '.git'
    - '.gitignore'
    - '**/.git'
EOF
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    environment_variable {
      name  = "REPOSITORY_URL"
      value = var.web_repository_url
    }
    environment_variable {
      name  = "REPOSITORY_BRANCH"
      value = var.source_branch
    }
  }

  artifacts {
    type = "S3"
    location = aws_s3_bucket.deployments_bucket.bucket
    path = "web"
    packaging = "ZIP"
    override_artifact_name = true
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    env = "build"
  }
}

resource "aws_codedeploy_app" "web_application" {
  name = "${var.project_name}-web-${var.environment}"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "web_deployment_group" {
  app_name              = aws_codedeploy_app.web_application.name
  deployment_group_name = "${var.project_name}-${var.environment}-dg"
  service_role_arn      = aws_iam_role.codedeploy_iam_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  
  /**
  auto_rollback_configuration {
    enabled = false
  }
  */

  autoscaling_groups = [var.ec2_as_group_name]
}

resource "aws_codepipeline" "web_codepipeline" {
  name     = "${var.project_name}-web-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.deployments_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        S3Bucket    = aws_s3_bucket.deployments_bucket.bucket
        S3ObjectKey = var.s3_object_key_zip
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.web_codebuild.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.web_application.name
        DeploymentGroupName = aws_codedeploy_deployment_group.web_deployment_group.deployment_group_name
      }
    }
  }
}