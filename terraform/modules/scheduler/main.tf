locals {
  prefix = "vtss-${var.env}"
}

# ─── DAILY AGGREGATOR JOB ────────────────────────────────────────────────────
# Reads /active/done + /active/error and produces summary resumes per campaign/app

resource "google_cloud_scheduler_job" "daily_aggregator" {
  project     = var.project_id
  region      = var.region
  name        = "${local.prefix}-job-daily-aggregator"
  description = "Vitesse ${upper(var.env)}: daily aggregation of messaging events"
  schedule    = "0 1 * * *"
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = var.maintenance_topic_id

    data = base64encode(jsonencode({
      command_type = "aggregate"
      target_date  = "YESTERDAY"
      scope        = length(var.customer_ids) > 0 ? "customer" : "all"
      customer_ids = var.customer_ids
    }))

    attributes = {
      event_type   = "maintenance_command"
      command_type = "aggregate"
    }
  }
}

# ─── DAILY COMPRESSOR D-30 ───────────────────────────────────────────────────
# Moves /active/done/{D-30} objects to /archived/ as jsonl.gz

resource "google_cloud_scheduler_job" "daily_compressor" {
  project     = var.project_id
  region      = var.region
  name        = "${local.prefix}-job-daily-compressor"
  description = "Vitesse ${upper(var.env)}: compress operational events older than 30 days"
  schedule    = "0 2 * * *"
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = var.maintenance_topic_id

    data = base64encode(jsonencode({
      command_type   = "compress"
      target_date    = "D-30"
      scope          = length(var.customer_ids) > 0 ? "customer" : "all"
      customer_ids   = var.customer_ids
    }))

    attributes = {
      event_type   = "maintenance_command"
      command_type = "compress"
    }
  }
}

# ─── HOURLY CLEANUP ──────────────────────────────────────────────────────────
# Removes stale in_process objects and verifies health of active queue

resource "google_cloud_scheduler_job" "hourly_cleanup" {
  project     = var.project_id
  region      = var.region
  name        = "${local.prefix}-job-hourly-cleanup"
  description = "Vitesse ${upper(var.env)}: cleanup stale in_process objects"
  schedule    = "0 * * * *"
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = var.maintenance_topic_id

    data = base64encode(jsonencode({
      command_type = "cleanup"
      scope        = length(var.customer_ids) > 0 ? "customer" : "all"
      customer_ids = var.customer_ids
    }))

    attributes = {
      event_type   = "maintenance_command"
      command_type = "cleanup"
    }
  }
}

# ─── WEEKLY PURGE RECENT_EVENTS ──────────────────────────────────────────────
# Companion of Compressor: truncates Firestore recent_events > D-30 or > 100 events

resource "google_cloud_scheduler_job" "weekly_purge_recent_events" {
  project     = var.project_id
  region      = var.region
  name        = "${local.prefix}-job-weekly-purge-recent-events"
  description = "Vitesse ${upper(var.env)}: purge Firestore recent_events beyond TTL or cap"
  schedule    = "0 3 * * 0"
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = var.maintenance_topic_id

    data = base64encode(jsonencode({
      command_type = "purge_recent_events"
      max_events   = 100
      max_days     = 30
      scope        = length(var.customer_ids) > 0 ? "customer" : "all"
      customer_ids = var.customer_ids
    }))

    attributes = {
      event_type   = "maintenance_command"
      command_type = "purge_recent_events"
    }
  }
}

# Grant scheduler SA the invoker role on the Cloud Scheduler service
resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project_id
  role    = "roles/cloudscheduler.jobRunner"
  member  = "serviceAccount:${var.scheduler_sa_email}"
}
