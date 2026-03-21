# =============================================================================
# Terraform Backend - Variables
# =============================================================================

variable "bucket" {
  description = "The S3 bucket name for storing Terraform state"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

variable "dynamodb_table" {
  description = "The DynamoDB table name for state locking"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
