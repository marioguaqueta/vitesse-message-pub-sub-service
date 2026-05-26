output "topic_ids" {
  description = "Map of topic keys to their full resource IDs"
  value = {
    for k, v in google_pubsub_topic.main : k => v.id
  }
}

output "topic_names" {
  description = "Map of topic keys to their short names"
  value = {
    for k, v in google_pubsub_topic.main : k => v.name
  }
}

output "dlq_topic_ids" {
  description = "Map of DLQ topic keys to their full resource IDs"
  value = {
    for k, v in google_pubsub_topic.dlq : k => v.id
  }
}

output "subscription_ids" {
  description = "Map of subscription names to their full resource IDs"
  value = {
    crf_sender              = google_pubsub_subscription.crf_sender.id
    crf_processor_inbound   = google_pubsub_subscription.crf_processor_inbound.id
    crf_processor_status    = google_pubsub_subscription.crf_processor_status.id
    crf_projector           = google_pubsub_subscription.crf_projector.id
    maintenance_workers     = google_pubsub_subscription.maintenance_workers.id
    crf_media_handler       = google_pubsub_subscription.crf_media_handler.id
  }
}

output "maintenance_topic_id" {
  description = "Full resource ID of the maintenance-commands topic"
  value       = google_pubsub_topic.main["maintenance_commands"].id
}
