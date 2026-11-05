---
name: terraform-backend-aws
description: Create an S3 Terraform backend on AWS with S3-native state locking (use_lockfile, no DynamoDB) - guided setup with bootstrap, apply, and state migration workflow, plus moving an existing DynamoDB-locked backend to use_lockfile. Use when setting up remote Terraform state on AWS, or moving local terraform.tfstate to a remote S3 backend.
---

# Terraform Backend on AWS

You walk the user through creating a Terraform remote backend on AWS. This creates one S3 bucket (versioned, encrypted, public access blocked) that holds both the state and its lock file — S3-native locking with `use_lockfile = true`, Terraform 1.10+, no DynamoDB table — then migrates from local to remote state.

## Before you start

Ask the user for:

1. **AWS profile name** — which AWS CLI profile to use (e.g., `my-project-admin`)
2. **Project name** — used as a prefix for resource naming (e.g., `myproject`)
3. **AWS region** — where to create the backend resources (e.g., `eu-west-1`)
4. **S3 bucket name** — globally unique name for state storage (e.g., `myproject-terraform-state`)
5. **State key path** — the S3 key prefix for the state file (e.g., `myproject/terraform/backend/terraform.tfstate`)
6. **Working directory** — where to create the Terraform files

Verify credentials and the Terraform version (`use_lockfile` needs 1.10 or later) before proceeding:

```bash
export AWS_PROFILE=<profile>
aws sts get-caller-identity
terraform version
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
make bootstrap-apply    # terraform apply (creates the S3 bucket with local state)
```

The bootstrap-init disables the remote backend entirely. The bootstrap-apply creates the S3 bucket, its versioning, encryption and public access block while storing state locally in `terraform.tfstate`.

## Step 3: Migrate to remote state

Once the bucket exists, add the backend block. It stays out of the bootstrap because Terraform cannot plan against a backend that does not exist yet. Create `backend.tf` next to `main.tf`:

```hcl
terraform {
  backend "s3" {
    # bucket, region and key come from -backend-config (see the Makefile)
    encrypt      = true
    use_lockfile = true # lock file next to the state in S3; no DynamoDB table
  }
}
```

Then migrate the local state into it:

```bash
make migrate-state
```

This runs `terraform init -migrate-state` with the backend config extracted from tfvars. It asks to continue, then Terraform asks to copy the existing state to the new backend — answer yes to both. Where nobody can answer a prompt (an agent's shell, CI), run `make migrate-state CONFIRM=yes`, which skips the question and passes `-force-copy`.

After migration:
- State is stored in S3 with versioning (rollback capability)
- State locking via a lock file stored next to the state object prevents concurrent modifications (the caller needs `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on it)
- Local `terraform.tfstate` can be deleted
- From now on, use `make init` (not `make bootstrap-init`)

## Step 4: Verify

```bash
make init          # Should connect to remote backend
make plan          # Should show no changes
make output        # Should display bucket info
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

## Migrating an existing DynamoDB-locked backend

If a backend already locks with `dynamodb_table`, move it to S3-native locking without a window where nothing locks:

1. **Add `use_lockfile = true`** to the existing `backend "s3"` block, keeping `dynamodb_table`. With both set, Terraform takes both locks.
2. **Re-init** every configuration that uses the backend: `terraform init -reconfigure`. The bucket and key are unchanged, so no state moves.
3. **Remove `dynamodb_table`** from the backend block once every configuration and pipeline that touches the state is on the new block, and re-init again.
4. **Delete the DynamoDB table** only once nothing uses it — other state keys or projects may share the same lock table. If Terraform manages the table, remove its resource and apply; otherwise delete it by hand.

`dynamodb_table` is deprecated in current Terraform releases, so do this migration rather than keep both.

## Key design decisions

- **S3 versioning enabled** — every state change is versioned for rollback
- **AES256 encryption** — state is encrypted at rest
- **Public access blocked** — state files often hold secrets and must never be public
- **S3-native locking (`use_lockfile`)** — one bucket holds state and lock; no DynamoDB table to create, pay for or clean up
- **Makefile extracts backend config from tfvars** — single source of truth, no duplication between backend block and variable values
