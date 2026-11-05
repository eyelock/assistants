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

output "next_steps" {
  description = "Next steps after applying backend configuration"
  value       = <<-EOT

    Backend Configuration Applied Successfully!

    Infrastructure Created:
    - S3 Bucket: ${aws_s3_bucket.terraform_state.bucket}

    Next Steps:
    1. Add the backend block (backend.tf), then migrate to remote state:
       make migrate-state

    2. Verify remote backend works:
       make init
       make plan

  EOT
}
