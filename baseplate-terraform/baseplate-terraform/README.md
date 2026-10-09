# Terraform Project

This project uses Terraform to manage AWS infrastructure. The following instructions will guide you through setting up and managing the infrastructure for both staging and production environments.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- AWS CLI installed and configured
- jq installed for JSON processing
- Bash shell

## Project Structure

- `.legacy_cf_templates`: Contains legacy CloudFormation templates.
- `.terraform`: Terraform environment and modules.
- `dev.tfvars`: Development environment variables.
- `main.tf`: Main Terraform configuration file.
- `Makefile`: Contains commands to manage Terraform workspaces and environments.
- `modules`: Contains Terraform modules.
- `output.tf`: Outputs configuration.
- `prod.tfvars`: Production environment variables.
- `terraform.tfstate`: Terraform state file.
- `terraform.tfstate.backup`: Backup of the Terraform state file.
- `terraform.tfvars.sample`: Sample Terraform variables file.
- `variables.tf`: Variables configuration.

## Setup

### 1. Create Terraform Workspaces

To create Terraform workspaces for staging and production:

```sh
make workspaces
```

### 2. Create Environment Files

To create environment files for staging and production:

```sh
make env_files
```

If the environment files already exist, you will be prompted to delete and recreate them.

### 3. Clean Environment Files

To clean up the environment files:

```sh
make clean
```

## Managing Infrastructure

### 1. Plan

To run a Terraform plan for a specific environment (staging/production):

```sh
make plan
```

You will be prompted to enter the environment.

### 2. Apply

To apply the Terraform plan for a specific environment (staging/production):

```sh
make apply
```

You will be prompted to enter the environment.

### 3. Destroy

To destroy the infrastructure for a specific environment (staging/production):

```sh
make destroy
```

You will be prompted to enter the environment.

## AWS SSO Login

To log in using AWS SSO:

```sh
make sso_login
```

## Assume Role

To assume a role in a specific AWS account:

```sh
make assume_role
```

You will be prompted to enter the AWS Account ID and Role Name. The temporary credentials will be saved in . Run `source temp_creds.sh` to set the AWS credentials in your current shell.

## Terraform Configuration

The main Terraform configuration is in . It includes modules for VPC, EC2, RDS, CodePipeline, Redis, ElastiCache, and CloudWatch Alarms. The variables for these modules are defined in .

## Environment Variables

The environment variables for staging and production are stored in `staging.tfvars` and `production.tfvars`, respectively. These files are created from the sample file .

## SSM Parameters

The Terraform configuration also includes resources to store the environment variables in AWS SSM Parameter Store:

- Staging: `/terraform/staging/tfvars`
- Production: `/terraform/production/tfvars`

These parameters are defined in .

## Contact

For any issues or questions, please contact the DevOps team at devops@appetiser.com.au.