#!/bin/bash
# run this script especially with existing projects
# this is to initialize the configurations on your local environment to match what's deployed

AWS_REGION="ap-southeast-2"
PROJECT_NAME="thelawyershub"
WORKSPACE=$(terraform workspace show)
S3_BUCKET="$PROJECT_NAME-production-tfstate-bucket"

terraform init \
    -backend-config="region=$AWS_REGION" \
    -backend-config="bucket=$S3_BUCKET" \
    -backend-config="key=terraform.tfstate" \
    -backend-config="dynamodb_table=$WORKSPACE-terraform-lock-table" \
    $1

