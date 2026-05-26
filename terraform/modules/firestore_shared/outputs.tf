output "database_id" {
  description = "Firestore database ID (shared)"
  value       = google_firestore_database.shared.name
}

output "database_name" {
  description = "Firestore database full resource name"
  value       = google_firestore_database.shared.id
}
