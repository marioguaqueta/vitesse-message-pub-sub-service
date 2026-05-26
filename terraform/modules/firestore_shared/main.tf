locals {
  db_name = "vtss-${var.env}-db"
}

resource "google_firestore_database" "shared" {
  project                     = var.project_id
  name                        = local.db_name
  location_id                 = var.location_id
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"

  delete_protection_state = var.env == "prod" || var.env == "preprod" ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
}

# TTL configurations — each collection uses a field named "ttl_timestamp" (unix epoch ms)
# The TTL field must be set by the application on document write.

resource "google_firestore_field" "conversations_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_conversations"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "recent_events_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_recent_events"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "gsid_map_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_gsid_map"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "wamid_map_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_wamid_map"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "active_conv_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_active_conv"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "contacts_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_contacts"
  field      = "ttl_timestamp"
  ttl_config {}
}

resource "google_firestore_field" "broadcast_list_ttl" {
  project    = var.project_id
  database   = google_firestore_database.shared.name
  collection = "(default)_broadcast_list"
  field      = "ttl_timestamp"
  ttl_config {}
}
