terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "vtss-prod-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  env = "prod"

  common_labels = merge(var.labels, {
    env      = local.env
    platform = "vitesse"
    managed  = "terraform"
  })
}

# ─── APIs Y SERVICE ACCOUNTS WORKLOAD ────────────────────────────────────────

module "project" {
  source     = "../../modules/gcp_project"
  project_id = var.project_id
  region     = var.region
  env        = local.env
}

# ─── STORAGE DEDICADO POR CLIENTE ────────────────────────────────────────────

module "storage_customer" {
  for_each = toset(var.customers)

  source        = "../../modules/storage_customer"
  project_id    = var.project_id
  env           = local.env
  customer_id   = each.key
  region        = var.storage_region
  bucket_prefix = var.bucket_prefix
  labels        = local.common_labels

  depends_on = [module.project]
}

# ─── FIRESTORE DEDICADA POR CLIENTE ──────────────────────────────────────────

module "firestore_customer" {
  for_each = toset(var.customers)

  source      = "../../modules/firestore_customer"
  project_id  = var.project_id
  env         = local.env
  customer_id = each.key
  location_id = var.firestore_location

  depends_on = [module.project]
}

# ─── PUB/SUB DEDICADO POR CLIENTE ────────────────────────────────────────────

module "pubsub_customer" {
  for_each = toset(var.customers)

  source         = "../../modules/pubsub_customer"
  project_id     = var.project_id
  env            = local.env
  customer_id    = each.key
  project_number = var.project_number
  labels         = local.common_labels

  depends_on = [module.project]
}

# ─── IAM POR CLIENTE ─────────────────────────────────────────────────────────

module "iam_customer" {
  for_each = toset(var.customers)

  source                  = "../../modules/iam_customer"
  project_id              = var.project_id
  env                     = local.env
  customer_id             = each.key
  messaging_bucket_name   = module.storage_customer[each.key].messaging_bucket_name
  multimedia_bucket_name  = module.storage_customer[each.key].multimedia_bucket_name
  firestore_database_id   = module.firestore_customer[each.key].database_id
  pubsub_topic_ids        = module.pubsub_customer[each.key].topic_ids
  pubsub_subscription_ids = module.pubsub_customer[each.key].subscription_ids
  workload_sa_emails      = module.project.workload_sa_emails

  depends_on = [
    module.storage_customer,
    module.firestore_customer,
    module.pubsub_customer,
    module.project,
  ]
}

# ─── CLOUD SCHEDULER (per customer maintenance jobs) ─────────────────────────
# In prod each customer can have independent scheduler jobs pointing to their own topic.
# This module creates one set of jobs per customer_id when customer_ids is provided.

module "scheduler" {
  for_each = toset(var.customers)

  source               = "../../modules/scheduler"
  project_id           = var.project_id
  env                  = local.env
  region               = var.region
  scheduler_sa_email   = module.project.workload_sa_emails["scheduler"]
  maintenance_topic_id = module.pubsub_customer[each.key].maintenance_topic_id
  customer_ids         = [each.key]

  depends_on = [module.pubsub_customer, module.project]
}
