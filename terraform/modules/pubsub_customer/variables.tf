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

variable "project_number" {
  type        = string
  description = "GCP project number (for Pub/Sub service account)"
}

variable "message_retention_duration" {
  type        = string
  description = "Default message retention for topics"
  default     = "604800s" # 7 days
}

variable "ack_deadline_outbound" {
  type        = number
  default     = 60
}

variable "ack_deadline_inbound" {
  type        = number
  default     = 30
}

variable "ack_deadline_media" {
  type        = number
  default     = 120
}

variable "ack_deadline_maintenance" {
  type        = number
  default     = 120
}

variable "max_delivery_attempts" {
  type        = number
  default     = 5
}

variable "labels" {
  type        = map(string)
  description = "Common labels to apply to all resources"
  default     = {}
}
