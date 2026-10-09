### Terraform Environment Assistant
### This tool will help you create Terraform workspaces,
### environment files, and login to jumpgate and into a AWS Account.
### Managed by the cool guys at devops@appetiser.com.au

# use bash shell because bash is king
SHELL := /bin/bash

# variables
TFVARS_SAMPLE=terraform.tfvars.sample
STAGING_TFVARS=staging.tfvars
PRODUCTION_TFVARS=production.tfvars
#S3_BUCKET := $(shell terraform output -raw project_name)-tfstate-bucket
#AWS_REGION := $(shell terraform output -raw region | xargs)
#WORKSPACE := $(shell terraform workspace show)
#STATE_PATH := terraform.tfstate

# init terraform
#init:
#	terraform init \
#	  -backend-config="region=$(AWS_REGION)" \
#	  -backend-config="bucket=$(S3_BUCKET)"

# create terraform workspaces
workspaces:
	terraform workspace new production || true; \
	terraform workspace new staging || true

# create environment files
env_files: check_env_files $(STAGING_TFVARS) $(PRODUCTION_TFVARS)

check_env_files:
	@if [ -f $(STAGING_TFVARS) ] || [ -f $(PRODUCTION_TFVARS) ]; then \
		read -p "Environment files exist. Do you want to delete and recreate them? (y/n): " choice; \
		if [ "$$choice" = "y" ]; then \
			rm -f $(STAGING_TFVARS) $(PRODUCTION_TFVARS); \
		else \
			exit 1; \
		fi \
	fi

$(STAGING_TFVARS): $(TFVARS_SAMPLE)
	cp $(TFVARS_SAMPLE) $(STAGING_TFVARS)

$(PRODUCTION_TFVARS): $(TFVARS_SAMPLE)
	cp $(TFVARS_SAMPLE) $(PRODUCTION_TFVARS)
	sed -i 's/staging/production/g' $(PRODUCTION_TFVARS)

# clean environment files
clean:
	rm -f $(STAGING_TFVARS) $(PRODUCTION_TFVARS)

# run terraform plan
plan: 
	@read -p "Enter environment (staging/production): " env; \
	if [ "$$env" = "staging" ]; then \
		terraform workspace select staging; \
		terraform plan -var-file=$(STAGING_TFVARS); \
	elif [ "$$env" = "production" ]; then \
		terraform workspace select production; \
		terraform plan -var-file=$(PRODUCTION_TFVARS); \
	else \
		echo "Invalid environment"; \
		exit 1; \
	fi

# apply terraform plan
apply: 
	@read -p "Enter environment (staging/production): " env; \
	if [ "$$env" = "staging" ]; then \
		terraform workspace select staging; \
		terraform apply -var-file=$(STAGING_TFVARS); \
	elif [ "$$env" = "production" ]; then \
		terraform workspace select production; \
		terraform apply -var-file=$(PRODUCTION_TFVARS); \
	else \
		echo "Invalid environment"; \
		exit 1; \
	fi

destroy: 
	@read -p "Enter environment (staging/production): " env; \
	if [ "$$env" = "staging" ]; then \
		terraform workspace select staging; \
		terraform apply -var-file=$(STAGING_TFVARS) -destroy; \
	elif [ "$$env" = "production" ]; then \
		terraform workspace select production; \
		terraform apply -var-file=$(PRODUCTION_TFVARS) -destroy; \
	else \
		echo "Invalid environment"; \
		exit 1; \
	fi

sso_login:
	aws sso login --profile EngineeringTeam-158641811009

assume_role:
	@read -p "Enter AWS Account ID: " ACCOUNT_ID; \
	read -p "Enter Role Name: " ROLE_NAME; \
	ROLE_ARN="arn:aws:iam::$$ACCOUNT_ID:role/$$ROLE_NAME"; \
	SESSION_NAME="juicer"; \
	CREDENTIALS=$$(aws sts assume-role --role-arn $$ROLE_ARN --role-session-name $$SESSION_NAME --profile EngineeringTeam-158641811009 --output json); \
	if [ -z "$$CREDENTIALS" ]; then \
		echo "Error assuming role."; \
		exit 1; \
	fi; \
	echo "export AWS_ACCESS_KEY_ID=$$(echo $$CREDENTIALS | jq -r '.Credentials.AccessKeyId')" > temp_creds.sh; \
	echo "export AWS_SECRET_ACCESS_KEY=$$(echo $$CREDENTIALS | jq -r '.Credentials.SecretAccessKey')" >> temp_creds.sh; \
	echo "export AWS_SESSION_TOKEN=$$(echo $$CREDENTIALS | jq -r '.Credentials.SessionToken')" >> temp_creds.sh; \
	echo "Run 'source temp_creds.sh' to set the AWS credentials in your current shell."

download-envs:
	@aws ssm get-parameter --name /terraform/staging/tfvars --with-decryption --query "Parameter.Value" --output text > staging.tfvars
	aws ssm get-parameter --name /terraform/production/tfvars --with-decryption --query "Parameter.Value" --output text > production.tfvars

.PHONY: init workspaces env_files check_env_files clean plan apply destroy sso_login assume_role download-envs
