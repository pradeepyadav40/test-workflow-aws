terraform {
  required_version = "= 1.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A short name for this project, used for tagging and naming resources"
  type        = string
  default     = "github-actions-terraform-demo"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "prod"
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform-mock"
  }
}

# Example infrastructure: an S3 bucket for artifacts or static hosting
#resource "aws_s3_bucket" "app_bucket" {
 # bucket = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  #tags = merge(local.common_tags, {
   # Name = "${var.project_name}-${var.environment}-bucket"
 # })
#}

#resource "aws_s3_bucket_public_access_block" "app_bucket_block" {
 # bucket = aws_s3_bucket.app_bucket.id

 # block_public_acls       = true
  #block_public_policy     = true
  #ignore_public_acls      = true
  #restrict_public_buckets = true
#}

#data "aws_caller_identity" "current" {}

#data "aws_region" "current" {}

output "mock_output" {
  description = "Name of the created S3 bucket"
  value       = "mock_success"
}
