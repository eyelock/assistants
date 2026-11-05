#!/usr/bin/env bash
# The terraform-backend-aws sandbox for an existing backend: app/ is a
# Terraform configuration whose S3 backend still locks with the DynamoDB table
# acme-terraform-locks, plus the aws and terraform stubs
# (terraform-backend-stubs.sh), where that table holds locks for other state
# keys too.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail
git init -q -b main .
echo ".eval/" >>.git/info/exclude
mkdir -p app
cat >app/backend.tf <<'TF'
terraform {
  backend "s3" {
    bucket         = "acme-terraform-state"
    key            = "acme/app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "acme-terraform-locks"
    encrypt        = true
  }
}
TF
cat >app/main.tf <<'TF'
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_sqs_queue" "orders" {
  name = "acme-orders"
}
TF
git add . && git commit -qm "chore: App infrastructure"
touch .eval-bucket-created
bash "$EVAL_FIXTURES/terraform-backend-stubs.sh"
