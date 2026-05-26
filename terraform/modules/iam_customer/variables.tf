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

variable "messaging_bucket_name" {
  type        = string
  description = "Messaging bucket name for this customer"
}

variable "multimedia_bucket_name" {
  type        = string
  description = "Multimedia bucket name for this customer"
}

variable "firestore_database_id" {
  type        = string
  description = "Firestore database ID for this customer"
}

variable "pubsub_topic_ids" {
  type        = map(string)
  description = "Map of topic names to their full resource IDs for this customer"
}

variable "pubsub_subscription_ids" {
  type        = map(string)
  description = "Map of subscription names to their full resource IDs for this customer"
}

variable "workload_sa_emails" {
  type        = map(string)
  description = "Map of workload service account names to their email addresses"
  default     = {}
}
