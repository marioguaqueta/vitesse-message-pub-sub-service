locals {
  messaging_bucket  = "${var.bucket_prefix}-${var.env}-${var.customer_id}-msg"
  multimedia_bucket = "${var.bucket_prefix}-${var.env}-${var.customer_id}-mlt"

  common_labels = merge(var.labels, {
    env         = var.env
    platform    = "vitesse"
    managed     = "terraform"
    isolation   = "dedicated"
    customer_id = var.customer_id
  })
}

# ─── MESSAGING STORAGE ────────────────────────────────────────────────────────

resource "google_storage_bucket" "messaging" {
  name                        = local.messaging_bucket
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.common_labels

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age            = 45
      matches_prefix = ["active/done/"]
    }
    action { type = "Delete" }
  }

  lifecycle_rule {
    condition {
      age            = 7
      matches_prefix = ["active/in_process/"]
    }
    action { type = "Delete" }
  }

  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["active/error/"]
    }
    action { type = "Delete" }
  }

  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["archived/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 365
      matches_prefix = ["archived/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["data/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age            = 730
      matches_prefix = ["data/"]
    }
    action { type = "Delete" }
  }
}

# ─── MULTIMEDIA STORAGE ───────────────────────────────────────────────────────

resource "google_storage_bucket" "multimedia" {
  name                        = local.multimedia_bucket
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.common_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["conversational_files/", "catalog_files/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action { type = "Delete" }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Length", "ETag"]
    max_age_seconds = 3600
  }
}
