output "messaging_bucket_name" {
  description = "Name of the shared messaging bucket"
  value       = google_storage_bucket.messaging.name
}

output "messaging_bucket_url" {
  description = "URL of the shared messaging bucket"
  value       = google_storage_bucket.messaging.url
}

output "multimedia_bucket_name" {
  description = "Name of the shared multimedia bucket"
  value       = google_storage_bucket.multimedia.name
}

output "multimedia_bucket_url" {
  description = "URL of the shared multimedia bucket"
  value       = google_storage_bucket.multimedia.url
}
