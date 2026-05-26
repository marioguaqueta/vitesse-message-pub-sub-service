output "database_id" {
  description = "Firestore database ID for this customer"
  value       = google_firestore_database.customer.name
}

output "database_name" {
  description = "Firestore database full resource name"
  value       = google_firestore_database.customer.id
}
