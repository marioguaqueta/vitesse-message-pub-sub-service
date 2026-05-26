variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "env" {
  type        = string
  description = "Environment name: dev | stg"
}

variable "location_id" {
  type        = string
  description = "Firestore database location (e.g. nam5, eur3, us-central)"
  default     = "nam5"
}
