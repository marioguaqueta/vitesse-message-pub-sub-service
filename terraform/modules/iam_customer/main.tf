locals {
  be_account_id = "vtss-${var.env}-${var.customer_id}-be"
  fe_account_id = "vtss-${var.env}-${var.customer_id}-fe"
}

# ─── SERVICE ACCOUNTS ────────────────────────────────────────────────────────

resource "google_service_account" "backend" {
  project      = var.project_id
  account_id   = local.be_account_id
  display_name = "Vitesse ${upper(var.env)} — Backend [${var.customer_id}]"
  description  = "Backend admin service account for customer ${var.customer_id} in ${var.env}"
}

resource "google_service_account" "frontend" {
  project      = var.project_id
  account_id   = local.fe_account_id
  display_name = "Vitesse ${upper(var.env)} — Frontend [${var.customer_id}]"
  description  = "Frontend read-only service account for customer ${var.customer_id} in ${var.env}"
}

# ─── MESSAGING BUCKET — Backend (full object admin) ──────────────────────────

resource "google_storage_bucket_iam_member" "backend_messaging_admin" {
  bucket = var.messaging_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backend.email}"
}

# ─── MULTIMEDIA BUCKET — Backend (full object admin) ─────────────────────────

resource "google_storage_bucket_iam_member" "backend_multimedia_admin" {
  bucket = var.multimedia_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backend.email}"
}

# ─── FIRESTORE — Backend (read/write) ────────────────────────────────────────

resource "google_project_iam_member" "backend_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# ─── FIRESTORE — Frontend (read-only) ────────────────────────────────────────

resource "google_project_iam_member" "frontend_firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${google_service_account.frontend.email}"
}

# ─── PUB/SUB TOPICS — Backend (publisher) ────────────────────────────────────

resource "google_pubsub_topic_iam_member" "backend_publisher" {
  for_each = var.pubsub_topic_ids

  project = var.project_id
  topic   = each.value
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# ─── PUB/SUB SUBSCRIPTIONS — Backend (subscriber) ────────────────────────────

resource "google_pubsub_subscription_iam_member" "backend_subscriber" {
  for_each = var.pubsub_subscription_ids

  project      = var.project_id
  subscription = each.value
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.backend.email}"
}

# ─── WORKLOAD SA BINDINGS — grant workload SAs access to customer resources ──
# This allows shared CRF functions to read/write to this customer's buckets

resource "google_storage_bucket_iam_member" "workload_messaging_access" {
  for_each = var.workload_sa_emails

  bucket = var.messaging_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}

resource "google_storage_bucket_iam_member" "workload_multimedia_access" {
  for_each = var.workload_sa_emails

  bucket = var.multimedia_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}

resource "google_pubsub_topic_iam_member" "workload_topic_publisher" {
  for_each = var.pubsub_topic_ids

  project = var.project_id
  topic   = each.value
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.workload_sa_emails["crf_processor"]}"
}
