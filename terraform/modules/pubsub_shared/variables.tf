variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "env" {
  type        = string
  description = "Environment name: dev | stg"
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
  description = "Ack deadline in seconds for outbound-commands subscription"
  default     = 60
}

variable "ack_deadline_inbound" {
  type        = number
  description = "Ack deadline in seconds for inbound-events subscription"
  default     = 30
}

variable "ack_deadline_media" {
  type        = number
  description = "Ack deadline in seconds for media-commands subscription"
  default     = 120
}

variable "ack_deadline_maintenance" {
  type        = number
  description = "Ack deadline in seconds for maintenance-commands subscription"
  default     = 120
}

variable "max_delivery_attempts" {
  type        = number
  description = "Max delivery attempts before sending to DLQ"
  default     = 5
}

variable "labels" {
  type        = map(string)
  description = "Common labels to apply to all resources"
  default     = {}
}
