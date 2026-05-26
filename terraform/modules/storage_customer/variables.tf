variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "env" {
  type        = string
  description = "Environment name: preprod | prod"
}

variable "customer_id" {
  type        = string
  description = "Customer identifier (alphanumeric, used in resource names)"
  validation {
    condition     = can(regex("^[a-z0-9_-]+$", var.customer_id))
    error_message = "customer_id must contain only lowercase letters, numbers, hyphens, and underscores"
  }
}

variable "region" {
  type        = string
  description = "GCP region for bucket location"
  default     = "US"
}

variable "bucket_prefix" {
  type        = string
  description = "Prefix for all bucket names (must be globally unique)"
  default     = "vtss"
}

variable "labels" {
  type        = map(string)
  description = "Common labels to apply to all resources"
  default     = {}
}
