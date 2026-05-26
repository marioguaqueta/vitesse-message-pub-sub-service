output "messaging_buckets" {
  description = "Messaging bucket names per customer"
  value = {
    for cid in var.customers : cid => module.storage_customer[cid].messaging_bucket_name
  }
}

output "multimedia_buckets" {
  description = "Multimedia bucket names per customer"
  value = {
    for cid in var.customers : cid => module.storage_customer[cid].multimedia_bucket_name
  }
}

output "firestore_databases" {
  description = "Firestore database IDs per customer"
  value = {
    for cid in var.customers : cid => module.firestore_customer[cid].database_id
  }
}

output "pubsub_topics_per_customer" {
  description = "Pub/Sub topic IDs per customer"
  value = {
    for cid in var.customers : cid => module.pubsub_customer[cid].topic_ids
  }
}

output "customer_service_accounts" {
  description = "Backend and frontend service account emails per customer"
  value = {
    for cid in var.customers : cid => {
      backend  = module.iam_customer[cid].backend_sa_email
      frontend = module.iam_customer[cid].frontend_sa_email
    }
  }
}

output "workload_service_accounts" {
  description = "Shared workload service account emails"
  value       = module.project.workload_sa_emails
}

output "scheduler_jobs" {
  description = "Cloud Scheduler job names per customer"
  value = {
    for cid in var.customers : cid => module.scheduler[cid].job_names
  }
}
