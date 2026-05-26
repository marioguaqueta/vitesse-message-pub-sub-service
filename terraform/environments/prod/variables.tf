variable "project_id" {
  type        = string
  description = "GCP project ID for prod environment"
}

variable "project_number" {
  type        = string
  description = "GCP project number (used for Pub/Sub service account)"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "storage_region" {
  type        = string
  description = "GCS bucket location"
  default     = "US"
}

variable "firestore_location" {
  type        = string
  description = "Firestore database location"
  default     = "nam5"
}

variable "bucket_prefix" {
  type        = string
  description = "Globally unique prefix for bucket names"
  default     = "vtss"
}

variable "customers" {
  type        = list(string)
  description = "List of customer IDs to provision dedicated resources for"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Additional labels to apply to all resources"
  default     = {}
}
