variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "region" {
  type        = string
  description = "GCP region for Cloud Scheduler"
  default     = "us-central1"
}

variable "scheduler_sa_email" {
  type        = string
  description = "Service account email for Cloud Scheduler"
}

variable "maintenance_topic_id" {
  type        = string
  description = "Full resource ID of the maintenance-commands Pub/Sub topic"
}

variable "customer_ids" {
  type        = list(string)
  description = "List of customer IDs for scoped maintenance jobs (used in preprod/prod)"
  default     = []
}

variable "time_zone" {
  type        = string
  description = "Time zone for cron schedules"
  default     = "America/Bogota"
}
