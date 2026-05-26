terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "vtss-dev-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  env = "dev"

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

# ─── STORAGE COMPARTIDO ──────────────────────────────────────────────────────

module "storage" {
  source        = "../../modules/storage_shared"
  project_id    = var.project_id
  env           = local.env
  region        = var.storage_region
  bucket_prefix = var.bucket_prefix
  labels        = local.common_labels

  depends_on = [module.project]
}

# ─── FIRESTORE COMPARTIDA ─────────────────────────────────────────────────────

module "firestore" {
  source      = "../../modules/firestore_shared"
  project_id  = var.project_id
  env         = local.env
  location_id = var.firestore_location

  depends_on = [module.project]
}

# ─── PUB/SUB COMPARTIDO ──────────────────────────────────────────────────────

module "pubsub" {
  source         = "../../modules/pubsub_shared"
  project_id     = var.project_id
  env            = local.env
  project_number = var.project_number
  labels         = local.common_labels

  depends_on = [module.project]
}

# ─── CLOUD SCHEDULER ─────────────────────────────────────────────────────────

module "scheduler" {
  source               = "../../modules/scheduler"
  project_id           = var.project_id
  env                  = local.env
  region               = var.region
  scheduler_sa_email   = module.project.workload_sa_emails["scheduler"]
  maintenance_topic_id = module.pubsub.maintenance_topic_id

  depends_on = [module.pubsub, module.project]
}
