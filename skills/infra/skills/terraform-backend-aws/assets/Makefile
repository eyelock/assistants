# =============================================================================
# Terraform Backend Makefile
# =============================================================================
# Manages S3 + DynamoDB backend for Terraform remote state.
#
# Workflow:
#   First time:  make bootstrap-init && make bootstrap-apply && make migrate-state
#   After that:  make init && make plan && make apply
# =============================================================================

# Path to tfvars file — adjust for your project layout
CONFIG_FILE = terraform.tfvars

# S3 state key — adjust for your project
STATE_KEY = terraform/backend/terraform.tfstate

# Extract backend configuration from tfvars
# (Terraform doesn't support variables in backend blocks)
BACKEND_BUCKET = $(shell grep '^\s*bucket\s*=' $(CONFIG_FILE) | cut -d'"' -f2)
BACKEND_REGION = $(shell grep '^\s*region\s*=' $(CONFIG_FILE) | cut -d'"' -f2)
BACKEND_TABLE  = $(shell grep '^\s*dynamodb_table\s*=' $(CONFIG_FILE) | cut -d'"' -f2)

.PHONY: init plan apply destroy output validate fmt bootstrap-init bootstrap-apply migrate-state verify help

# =============================================================================
# Bootstrap Targets (First-Time Setup)
# =============================================================================

# Bootstrap initialization (first-time setup — uses local state only)
bootstrap-init:
	@echo "==============================================================================="
	@echo "Bootstrap Mode: Initializing with LOCAL state"
	@echo "==============================================================================="
	@echo ""
	@echo "This disables remote backend for initial infrastructure creation."
	@echo "After running 'make bootstrap-apply', migrate to remote state with:"
	@echo "  make migrate-state"
	@echo ""
	terraform init -backend=false

# Bootstrap apply (first-time setup with local state)
bootstrap-apply:
	@echo "==============================================================================="
	@echo "Bootstrap Mode: Applying with LOCAL state"
	@echo "==============================================================================="
	@echo ""
	@echo "Current AWS identity:"
	@aws sts get-caller-identity || { \
		echo ""; \
		echo "AWS credentials invalid!"; \
		echo ""; \
		echo "Set your AWS profile:"; \
		echo "  export AWS_PROFILE=<your-admin-profile>"; \
		echo ""; \
		exit 1; \
	}
	@echo ""
	terraform apply -var-file="$(CONFIG_FILE)"
	@echo ""
	@echo "==============================================================================="
	@echo "Bootstrap Complete! Infrastructure Created."
	@echo "==============================================================================="
	@echo ""
	@echo "Next step: Migrate to remote state backend:"
	@echo "  make migrate-state"
	@echo ""

# Migrate state from local to remote backend (run after bootstrap)
migrate-state:
	@echo "==============================================================================="
	@echo "Migrating State: Local -> Remote (S3)"
	@echo "==============================================================================="
	@echo ""
	@echo "Current AWS identity:"
	@aws sts get-caller-identity || { \
		echo ""; \
		echo "AWS credentials invalid!"; \
		echo ""; \
		echo "Set your AWS profile:"; \
		echo "  export AWS_PROFILE=<your-profile>"; \
		echo ""; \
		exit 1; \
	}
	@echo ""
	@echo "This will:"
	@echo "  - Move terraform.tfstate to S3: $(BACKEND_BUCKET)"
	@echo "  - Enable state locking with DynamoDB: $(BACKEND_TABLE)"
	@echo ""
	@read -p "Continue with migration? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo ""; \
		echo "Terraform will ask: 'Do you want to copy existing state to the new backend?'"; \
		echo "Answer: yes"; \
		echo ""; \
		if terraform init -migrate-state \
			-backend-config="bucket=$(BACKEND_BUCKET)" \
			-backend-config="region=$(BACKEND_REGION)" \
			-backend-config="key=$(STATE_KEY)" \
			-backend-config="dynamodb_table=$(BACKEND_TABLE)"; then \
			echo ""; \
			echo "==============================================================================="; \
			echo "State Migration Complete!"; \
			echo "==============================================================================="; \
			echo ""; \
			echo "Your state is now stored remotely:"; \
			echo "  Bucket: $(BACKEND_BUCKET)"; \
			echo "  Key:    $(STATE_KEY)"; \
			echo ""; \
			echo "You can safely delete the local terraform.tfstate file."; \
			echo "From now on, use 'make init' (not 'make bootstrap-init')."; \
			echo ""; \
		else \
			echo ""; \
			echo "==============================================================================="; \
			echo "State Migration Failed!"; \
			echo "==============================================================================="; \
			echo ""; \
			echo "Common issues:"; \
			echo "  1. AWS credentials expired or invalid"; \
			echo "  2. S3 bucket or DynamoDB table doesn't exist"; \
			echo "     Run 'make bootstrap-apply' first"; \
			echo ""; \
			exit 1; \
		fi; \
	else \
		echo "Migration cancelled."; \
	fi

# =============================================================================
# Normal Operations
# =============================================================================

# Initialize Terraform with remote backend
init:
	@echo "Initializing with remote state backend..."
	terraform init \
		-backend-config="bucket=$(BACKEND_BUCKET)" \
		-backend-config="region=$(BACKEND_REGION)" \
		-backend-config="key=$(STATE_KEY)" \
		-backend-config="dynamodb_table=$(BACKEND_TABLE)"

# Validate Terraform configuration
validate:
	terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive

# Plan changes
plan:
	terraform plan -var-file="$(CONFIG_FILE)"

# Apply changes
apply:
	terraform apply -var-file="$(CONFIG_FILE)"

# Destroy all resources (use with caution!)
destroy:
	terraform destroy -var-file="$(CONFIG_FILE)"

# Show outputs
output:
	terraform output

# Verify credentials and backend connectivity
verify:
	@echo "Current AWS identity:"
	@aws sts get-caller-identity
	@echo ""
	@echo "Testing Terraform plan..."
	@terraform plan -var-file="$(CONFIG_FILE)" > /dev/null 2>&1 && \
		echo "Terraform plan succeeded - permissions and backend are working!" || \
		(echo "Terraform plan failed - check permissions and backend config"; exit 1)

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Terraform Backend Management"
	@echo ""
	@echo "Bootstrap (first-time setup):"
	@echo "  bootstrap-init   - Initialize with local state"
	@echo "  bootstrap-apply  - Create S3 + DynamoDB with local state"
	@echo "  migrate-state    - Migrate local state to remote backend"
	@echo ""
	@echo "Normal operations:"
	@echo "  init      - Initialize with remote backend"
	@echo "  validate  - Validate configuration"
	@echo "  fmt       - Format .tf files"
	@echo "  plan      - Preview changes"
	@echo "  apply     - Apply changes"
	@echo "  destroy   - Destroy all resources"
	@echo "  output    - Show current outputs"
	@echo "  verify    - Check credentials and backend"
