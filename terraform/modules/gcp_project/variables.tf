variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "env" {
  type        = string
  description = "Environment name: dev | stg | preprod | prod"
  validation {
    condition     = contains(["dev", "stg", "preprod", "prod"], var.env)
    error_message = "env must be one of: dev, stg, preprod, prod"
  }
}
