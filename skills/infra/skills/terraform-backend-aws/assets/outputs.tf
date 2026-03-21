# =============================================================================
# Terraform Backend - Outputs
# =============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "next_steps" {
  description = "Next steps after applying backend configuration"
  value       = <<-EOT

    Backend Configuration Applied Successfully!

    Infrastructure Created:
    - S3 Bucket: ${aws_s3_bucket.terraform_state.bucket}
    - DynamoDB Table: ${aws_dynamodb_table.terraform_locks.name}

    Next Steps:
    1. Migrate to remote state:
       make migrate-state

    2. Verify remote backend works:
       make init
       make plan

  EOT
}
