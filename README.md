# CI/CD Pipeline with GitHub Actions, Terraform, and AWS (OIDC)

This repository contains a production-grade CI/CD pipeline that deploys Terraform-managed infrastructure to AWS using GitHub Actions and secure OpenID Connect (OIDC) federation (no long-lived AWS keys).

- Integration: GitHub Actions
- Cloud provider: AWS
- IaC: Terraform
- Terraform version: 1.14.7
- Default branch: `main`

The pipeline:
- Validates Terraform configuration
- Generates and publishes a Terraform plan
- Applies changes to AWS on pushes to `main`

## Repository Structure

- `.github/workflows/deploy.yml` – GitHub Actions CI/CD pipeline
- `infra/main.tf` – Terraform configuration (AWS provider, sample S3 bucket)

## Prerequisites

1. **AWS Account** with permissions to create:
   - IAM role for GitHub OIDC
   - S3 buckets

2. **GitHub repository** with:
   - Default branch set to `main`

3. **Local tools** (optional, for local Terraform use):
   - Terraform `1.14.7`
   - AWS CLI v2

## 1. Configure AWS OIDC for GitHub Actions

The pipeline uses GitHub OIDC to assume an IAM role in your AWS account. No static AWS keys are stored in GitHub.

### 1.1 Create an IAM OIDC Role for GitHub

1. Sign in to the AWS Management Console.
2. Go to **IAM → Identity providers**.
3. Click **Add provider**:
   - Provider type: **OpenID Connect**
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

4. Go to **IAM → Roles → Create role**:
   - **Trusted entity type**: `Web identity`
   - **Identity provider**: `token.actions.githubusercontent.com`
   - **Audience**: `sts.amazonaws.com`

5. Under **Conditions**, add a condition limiting access to your repo and branch, for example (JSON view):

   ```json
   {
     "StringEquals": {
       "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
     },
     "StringLike": {
       "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
     }
   }
   ```

6. Attach an IAM policy granting the minimum permissions required for your Terraform resources. For the sample S3 bucket, a starting point (tighten as needed):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:*"
         ],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "sts:GetCallerIdentity"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

7. Name the role, for example: `github-oidc-terraform-role`.
8. Save the role and copy its ARN, e.g.:

   `arn:aws:iam::123456789012:role/github-oidc-terraform-role`

## 2. Configure GitHub Secrets

In your GitHub repository:

1. Go to **Settings → Secrets and variables → Actions → New repository secret**.
2. Create the following secret:

   - **Name**: `AWS_ROLE_TO_ASSUME`
   - **Value**: the IAM role ARN from the previous step, e.g.
     `arn:aws:iam::123456789012:role/github-oidc-terraform-role`

No AWS access keys are needed.

## 3. Terraform Configuration Details

`infra/main.tf` contains:

- Terraform block with pinned version:
  - `required_version = "= 1.14.7"`
- AWS provider configuration using `var.aws_region` (default `us-east-1`).
- Example resources:
  - `aws_s3_bucket.app_bucket` – an S3 bucket named using project, environment, account ID, and region.
  - `aws_s3_bucket_public_access_block.app_bucket_block` – blocks public access.
- Variables:
  - `aws_region` – deployment region (default `us-east-1`).
  - `project_name` – project identifier.
  - `environment` – environment name (default `prod`).
- Outputs:
  - `bucket_name` – the created S3 bucket name.

You can customize variables or add additional resources as needed.

## 4. GitHub Actions Pipeline Overview

The workflow file is at `.github/workflows/deploy.yml` and is triggered on:

- `push` to `main`
- `pull_request` targeting `main`

### Jobs

1. **validate**
   - Checks out the code.
   - Configures AWS credentials via OIDC.
   - Installs Terraform `1.14.7`.
   - Runs `terraform init` and `terraform validate` in `infra/`.

2. **plan** (depends on `validate`)
   - Repeats checkout and AWS/Terraform setup.
   - Runs `terraform init`.
   - Runs `terraform plan -out=tfplan.binary`.
   - Generates a human-readable plan `tfplan.txt`.
   - Uploads `tfplan.txt` as a build artifact.
   - If the event is a pull request, posts the plan as a PR comment.

3. **apply** (depends on `plan`)
   - Runs only for `push` events on `main`.
   - Repeats checkout and AWS/Terraform setup.
   - Runs `terraform init`.
   - Runs a fresh `terraform plan -out=tfplan.binary` (ensures plan matches current state).
   - Runs `terraform apply -auto-approve tfplan.binary`.

All Terraform operations run in the `infra/` directory, and Terraform version is pinned to `1.14.7` in both the workflow and Terraform configuration.

## 5. Initial Setup and First Deployment

1. **Clone the repository** (or create it and add these files).
2. Ensure `infra/main.tf` is present and customized as needed.
3. Commit and push to `main`:

   ```bash
   git add .
   git commit -m "Initial CI/CD and Terraform setup"
   git push origin main
   ```

4. Go to **GitHub → Actions** and watch the workflow runs:
   - On push to `main`, `validate`, `plan`, and `apply` will run.
   - On pull requests targeting `main`, `validate` and `plan` will run; `apply` will not run.

5. After a successful `apply`, confirm resources in AWS (e.g., S3 bucket in the specified region).

## 6. Local Development (Optional)

If you want to run Terraform locally:

1. Install Terraform `1.14.7`.
2. Configure AWS credentials locally (e.g., with `aws configure` or `AWS_PROFILE`).
3. From the `infra/` directory:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

Ensure your local AWS identity has permissions similar to the GitHub OIDC role.

## 7. Customization

- **Region**: Change `var.aws_region` default in `infra/main.tf` or override via `-var` flags or `terraform.tfvars`.
- **Resources**: Add or modify Terraform resources in `infra/main.tf` (or split into multiple `.tf` files).
- **Permissions**: Narrow IAM role permissions to the specific services and actions your Terraform config requires.
- **Environments**: Use the `environment` variable or separate workspaces / state backends for `dev`, `staging`, `prod`.

## 8. Security Notes

- No hardcoded AWS keys are used; access is via GitHub OIDC and an IAM role.
- Restrict the IAM role to specific repositories and branches via the `sub` condition.
- Limit IAM permissions to the minimum required for your Terraform resources.
- Review Terraform plans (artifacts or PR comments) before merging changes into `main`.