output "backend_sa_email" {
  description = "Backend service account email for this customer"
  value       = google_service_account.backend.email
}

output "frontend_sa_email" {
  description = "Frontend (read-only) service account email for this customer"
  value       = google_service_account.frontend.email
}

output "backend_sa_name" {
  description = "Backend service account full resource name"
  value       = google_service_account.backend.name
}

output "frontend_sa_name" {
  description = "Frontend service account full resource name"
  value       = google_service_account.frontend.name
}
