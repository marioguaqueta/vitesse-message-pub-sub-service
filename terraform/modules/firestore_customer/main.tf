locals {
  db_name = "vtss-${var.env}-${var.customer_id}-db"
}

resource "google_firestore_database" "customer" {
  project                     = var.project_id
  name                        = local.db_name
  location_id                 = var.location_id
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"

  # Always enable delete protection in preprod and prod
  delete_protection_state = "DELETE_PROTECTION_ENABLED"
}

# TTL on conversations: 30 days
resource "google_firestore_field" "conversations_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "conversations"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on recent_events (subcollection): 30 days + cap enforced by Compressor job
resource "google_firestore_field" "recent_events_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "recent_events"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on gsid_map: 90 days
resource "google_firestore_field" "gsid_map_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "gsid_map"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on wamid_map: 90 days
resource "google_firestore_field" "wamid_map_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "wamid_map"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on active_conv: 72h (set by application per tenant config)
resource "google_firestore_field" "active_conv_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "active_conv"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on contacts: 365 days
resource "google_firestore_field" "contacts_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "contacts"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on contacts_lists: 365 days
resource "google_firestore_field" "contacts_lists_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "contacts_lists"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on contact_segments: 365 days
resource "google_firestore_field" "contact_segments_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "contact_segments"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on broadcast_list: 365 days
resource "google_firestore_field" "broadcast_list_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "broadcast_list"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on messages_conversations: 60 days
resource "google_firestore_field" "messages_conversations_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "messages_conversations"
  field      = "ttl_timestamp"
  ttl_config {}
}

# TTL on conversations_audit_history: 120 days
resource "google_firestore_field" "audit_history_ttl" {
  project    = var.project_id
  database   = google_firestore_database.customer.name
  collection = "conversations_audit_history"
  field      = "ttl_timestamp"
  ttl_config {}
}
