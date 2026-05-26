output "messaging_bucket" {
  description = "Shared messaging bucket name"
  value       = module.storage.messaging_bucket_name
}

output "multimedia_bucket" {
  description = "Shared multimedia bucket name"
  value       = module.storage.multimedia_bucket_name
}

output "firestore_database_id" {
  description = "Shared Firestore database ID"
  value       = module.firestore.database_id
}

output "pubsub_topics" {
  description = "All Pub/Sub topic IDs"
  value       = module.pubsub.topic_ids
}

output "workload_service_accounts" {
  description = "Workload service account emails"
  value       = module.project.workload_sa_emails
}
