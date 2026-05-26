terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  required_apis = [
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "firebase.googleapis.com",
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Workload service accounts shared across all customers per env
resource "google_service_account" "crf_parser" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-parser"
  display_name = "Vitesse ${upper(var.env)} — CRF Parser"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "crf_receptor" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-receptor"
  display_name = "Vitesse ${upper(var.env)} — CRF Receptor"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "crf_sender" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-sender"
  display_name = "Vitesse ${upper(var.env)} — CRF Sender"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "crf_processor" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-processor"
  display_name = "Vitesse ${upper(var.env)} — CRF Processor"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "crf_media" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-media"
  display_name = "Vitesse ${upper(var.env)} — CRF Media Handler"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "crf_projector" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-crf-projector"
  display_name = "Vitesse ${upper(var.env)} — CRF Projector"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = "vtss-${var.env}-scheduler"
  display_name = "Vitesse ${upper(var.env)} — Cloud Scheduler"
  depends_on   = [google_project_service.apis]
}

# Scheduler SA needs permission to publish to Pub/Sub
resource "google_project_iam_member" "scheduler_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# CRF Parser: publish to Pub/Sub, write to Storage, read Firestore
resource "google_project_iam_member" "parser_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.crf_parser.email}"
}

resource "google_project_iam_member" "parser_storage_creator" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.crf_parser.email}"
}

resource "google_project_iam_member" "parser_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.crf_parser.email}"
}

# CRF Receptor: publish to Pub/Sub, write to Storage
resource "google_project_iam_member" "receptor_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.crf_receptor.email}"
}

resource "google_project_iam_member" "receptor_storage_creator" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.crf_receptor.email}"
}

# CRF Sender: subscribe to Pub/Sub, admin on Storage (move objects todo→done/error)
resource "google_project_iam_member" "sender_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.crf_sender.email}"
}

resource "google_project_iam_member" "sender_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.crf_sender.email}"
}

# CRF Processor: subscribe + publish (for projection-updates), Storage admin, Firestore user
resource "google_project_iam_member" "processor_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.crf_processor.email}"
}

resource "google_project_iam_member" "processor_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.crf_processor.email}"
}

resource "google_project_iam_member" "processor_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.crf_processor.email}"
}

resource "google_project_iam_member" "processor_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.crf_processor.email}"
}

# CRF Media Handler: subscribe to Pub/Sub, admin on Storage
resource "google_project_iam_member" "media_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.crf_media.email}"
}

resource "google_project_iam_member" "media_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.crf_media.email}"
}

# CRF Projector: subscribe to Pub/Sub, Firestore user
resource "google_project_iam_member" "projector_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.crf_projector.email}"
}

resource "google_project_iam_member" "projector_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.crf_projector.email}"
}
