---
name: terraform-backend-aws
description: Create an S3 + DynamoDB Terraform backend on AWS — guided setup with bootstrap, apply, and state migration workflow.
---

# Terraform Backend on AWS

You walk the user through creating a Terraform remote backend on AWS. This creates an S3 bucket for state storage and a DynamoDB table for state locking, then migrates from local to remote state.

## Before you start

Ask the user for:

1. **AWS profile name** — which AWS CLI profile to use (e.g., `my-project-admin`)
2. **Project name** — used as a prefix for resource naming (e.g., `myproject`)
3. **AWS region** — where to create the backend resources (e.g., `eu-west-1`)
4. **S3 bucket name** — globally unique name for state storage (e.g., `myproject-terraform-state`)
5. **DynamoDB table name** — for state locking (e.g., `myproject-terraform-locks`)
6. **State key path** — the S3 key prefix for the state file (e.g., `myproject/terraform/backend/terraform.tfstate`)
7. **Working directory** — where to create the Terraform files

Verify credentials before proceeding:

```bash
export AWS_PROFILE=<profile>
aws sts get-caller-identity
```

## Step 1: Create the Terraform files

Use the assets in `assets/` as the starting point. Copy them to the working directory and customize:

| Asset | Customize |
|-------|-----------|
| `main.tf` | Replace `{project}` prefix in resource names and tags |
| `variables.tf` | Ready to use as-is |
| `outputs.tf` | Replace `{project}` prefix in descriptions |
| `terraform.tfvars.example` | Fill in with user's values, copy to `terraform.tfvars` |
| `Makefile` | Set `CONFIG_FILE` path and `STATE_KEY`, replace profile names in messages |
| `.gitignore` | Ready to use as-is |

The `terraform.tfvars` file drives everything — the Makefile extracts backend config values from it since Terraform doesn't support variables in backend blocks.

## Step 2: Bootstrap with local state

This is a three-phase process. The backend infrastructure doesn't exist yet, so we start with local state:

```bash
make bootstrap-init     # terraform init -backend=false
make bootstrap-apply    # terraform apply (creates S3 + DynamoDB with local state)
```

The bootstrap-init disables the remote backend entirely. The bootstrap-apply creates the S3 bucket and DynamoDB table while storing state locally in `terraform.tfstate`.

## Step 3: Migrate to remote state

Once the infrastructure exists, migrate the local state into it:

```bash
make migrate-state
```

This runs `terraform init -migrate-state` with the backend config extracted from tfvars. Terraform will ask to copy existing state to the new backend — answer yes.

After migration:
- State is stored in S3 with versioning (rollback capability)
- State locking via DynamoDB prevents concurrent modifications
- Local `terraform.tfstate` can be deleted
- From now on, use `make init` (not `make bootstrap-init`)

## Step 4: Verify

```bash
make init          # Should connect to remote backend
make plan          # Should show no changes
make output        # Should display bucket and table info
```

## Day-to-day operations

After setup, the standard workflow is:

```bash
make init          # Initialize (first time in a new checkout)
make plan          # Preview changes
make apply         # Apply changes
make output        # Show current state
make validate      # Check config syntax
make fmt           # Format .tf files
```

## Key design decisions

- **S3 versioning enabled** — every state change is versioned for rollback
- **AES256 encryption** — state is encrypted at rest
- **DynamoDB PAY_PER_REQUEST** — no ongoing cost for low-usage backends, no capacity planning
- **Makefile extracts backend config from tfvars** — single source of truth, no duplication between backend block and variable values
- **Access keys created manually** — never stored in Terraform state (security best practice)
