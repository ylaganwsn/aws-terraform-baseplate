# aws-terraform-baseplate

Reusable Terraform baseplate for deploying AWS API/web workloads: VPC, EC2 Auto Scaling Group, RDS, Redis, CodePipeline and CloudWatch, with one codebase driving multiple environments through Terraform workspaces.

## What it provisions

| Layer | Resources |
|---|---|
| Networking | VPC, public/private subnets, route tables, security groups |
| Compute | EC2 Auto Scaling Group behind a load balancer |
| Data | RDS database, ElastiCache Redis |
| Delivery | CodePipeline for build and deploy |
| Observability | CloudWatch logs, metrics and alarms |
| Edge (optional) | CloudFront distribution |
| State | S3 bucket for remote Terraform state |

## Prerequisites

- Terraform >= 1.x
- AWS CLI v2, configured for SSO (`aws configure sso`)
- Make
- Access to the target AWS account, with a role that can create the resources above

## Repository layout

```
.
├── Makefile              # helper targets: env_files, workspaces, plan, apply
├── init.sh               # generates per-environment tfvars files
├── s3_statefile/         # bootstrap stack: S3 bucket for remote state
│   └── s3-tfstate.tf
├── *.tf                  # root configuration
└── <env>.tfvars          # per-environment variables (git-ignored)
```

## Deployment procedure

### 1. Create a repository for the project

Use this baseplate as a template for each new project so every project has its own Terraform repo and state.

```bash
git clone <baseplate-repo-url> <project_name>-terraform
cd <project_name>-terraform
git remote add <project_name> <new-project-terraform-repo-url>
git push --set-upstream <project_name>
```

Then clone the new project repo and open it in your IDE.

### 2. Authenticate to the project's AWS account

```bash
aws sso login
make assume_role          # prompts for Account ID and Role Name
. temp_creds.sh           # loads the temporary credentials into your shell
aws s3 ls                 # verify access
```

> Temporary credentials expire. Re-run these steps if you start getting auth errors.

### 3. Deploy the S3 bucket for Terraform state

1. Edit `s3_statefile/s3-tfstate.tf` and set the project name.
2. Apply it:

```bash
cd s3_statefile/
terraform init
terraform plan
terraform apply
cd ../
```

Terraform state for the project can now be stored in S3.

### 4. Create environment files and workspaces

```bash
make env_files            # runs init.sh to generate <env>.tfvars files
make workspaces           # creates a Terraform workspace per environment
```

Check that the backend settings match the bucket created in step 3.

### 5. Configure the staging environment

Edit `staging.tfvars` and set:

- `project_name`
- Repository URLs
- Deploy tokens or credentials for the pipeline

> **Security:** never commit `*.tfvars` files or tokens. Keep them in `.gitignore`, store secrets in AWS SSM Parameter Store or Secrets Manager, and pass sensitive values through environment variables (`TF_VAR_...`) where possible.

### 6. Plan

```bash
terraform workspace show  # confirm you are in the intended workspace
make plan
```

The plan should complete with no errors. Review it before continuing.

### 7. Apply

```bash
make apply
```

### 8. Post-deployment setup

- Configure CodePipeline (source connection and stages)
- Create the application environment file
- Set up CloudFront (if used)

## Notes

- One workspace per environment (for example `staging`, `production`) keeps state separate.
- Always run `plan` and read it before `apply`.
- Do not commit `.terraform/`, `*.tfstate*` or `*.tfvars`.

## License

MIT
