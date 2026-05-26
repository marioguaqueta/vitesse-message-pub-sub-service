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
  description = "Customer identifier"
}

variable "location_id" {
  type        = string
  description = "Firestore database location (e.g. nam5, eur3, us-central)"
  default     = "nam5"
}
