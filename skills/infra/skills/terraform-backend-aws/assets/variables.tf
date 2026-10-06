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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
