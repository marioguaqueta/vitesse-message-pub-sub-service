variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "env" {
  type        = string
  description = "Environment name: dev | stg"
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
