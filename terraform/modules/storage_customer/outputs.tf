output "messaging_bucket_name" {
  description = "Name of the dedicated messaging bucket for this customer"
  value       = google_storage_bucket.messaging.name
}

output "messaging_bucket_url" {
  description = "URL of the dedicated messaging bucket"
  value       = google_storage_bucket.messaging.url
}

output "multimedia_bucket_name" {
  description = "Name of the dedicated multimedia bucket for this customer"
  value       = google_storage_bucket.multimedia.name
}

output "multimedia_bucket_url" {
  description = "URL of the dedicated multimedia bucket"
  value       = google_storage_bucket.multimedia.url
}
