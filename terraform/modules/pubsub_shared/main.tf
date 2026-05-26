locals {
  prefix = "vtss-${var.env}"

  # All 6 operational topics with their configuration
  topics = {
    outbound_commands    = { name = "${local.prefix}-outbound-commands",    retention = var.message_retention_duration }
    inbound_events       = { name = "${local.prefix}-inbound-events",       retention = var.message_retention_duration }
    status_events        = { name = "${local.prefix}-status-events",        retention = var.message_retention_duration }
    projection_updates   = { name = "${local.prefix}-projection-updates",   retention = "259200s" }  # 3 days
    maintenance_commands = { name = "${local.prefix}-maintenance-commands", retention = "86400s"  }  # 1 day
    media_commands       = { name = "${local.prefix}-media-commands",       retention = "259200s" }  # 3 days
  }

  dlq_topics = {
    outbound_commands    = "${local.prefix}-dlq-outbound"
    inbound_events       = "${local.prefix}-dlq-inbound"
    status_events        = "${local.prefix}-dlq-status"
    projection_updates   = "${local.prefix}-dlq-projection"
    maintenance_commands = "${local.prefix}-dlq-maintenance"
    media_commands       = "${local.prefix}-dlq-media"
  }

  pubsub_sa = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ─── DLQ TOPICS (must be created before main topics/subscriptions) ────────────

resource "google_pubsub_topic" "dlq" {
  for_each = local.dlq_topics

  project = var.project_id
  name    = each.value

  message_retention_duration = var.message_retention_duration

  labels = merge(var.labels, {
    env      = var.env
    platform = "vitesse"
    type     = "dlq"
    managed  = "terraform"
  })
}

# DLQ subscriptions for manual reprocessing
resource "google_pubsub_subscription" "dlq" {
  for_each = local.dlq_topics

  project = var.project_id
  name    = "${each.value}-sub"
  topic   = google_pubsub_topic.dlq[each.key].name

  ack_deadline_seconds       = 600
  message_retention_duration = var.message_retention_duration
  retain_acked_messages      = true
  enable_message_ordering    = false

  expiration_policy {
    ttl = "" # never expire
  }

  labels = merge(var.labels, {
    env      = var.env
    platform = "vitesse"
    type     = "dlq-sub"
    managed  = "terraform"
  })
}

# ─── MAIN TOPICS ─────────────────────────────────────────────────────────────

resource "google_pubsub_topic" "main" {
  for_each = local.topics

  project = var.project_id
  name    = each.value.name

  message_retention_duration = each.value.retention

  labels = merge(var.labels, {
    env      = var.env
    platform = "vitesse"
    type     = "operational"
    managed  = "terraform"
  })
}

# Grant Pub/Sub service account permission to publish to DLQ topics (required for dead_letter_policy)
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  for_each = local.dlq_topics

  project = var.project_id
  topic   = google_pubsub_topic.dlq[each.key].name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_sa
}

# ─── SUBSCRIPTIONS WITH DLQ ──────────────────────────────────────────────────

resource "google_pubsub_subscription" "crf_sender" {
  project = var.project_id
  name    = "${local.prefix}-sub-crf-sender"
  topic   = google_pubsub_topic.main["outbound_commands"].name

  ack_deadline_seconds       = var.ack_deadline_outbound
  message_retention_duration = local.topics.outbound_commands.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["outbound_commands"].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "crf_sender_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.crf_sender.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}

resource "google_pubsub_subscription" "crf_processor_inbound" {
  project = var.project_id
  name    = "${local.prefix}-sub-crf-processor-inbound"
  topic   = google_pubsub_topic.main["inbound_events"].name

  ack_deadline_seconds       = var.ack_deadline_inbound
  message_retention_duration = local.topics.inbound_events.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["inbound_events"].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "120s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "crf_processor_inbound_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.crf_processor_inbound.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}

resource "google_pubsub_subscription" "crf_processor_status" {
  project = var.project_id
  name    = "${local.prefix}-sub-crf-processor-status"
  topic   = google_pubsub_topic.main["status_events"].name

  ack_deadline_seconds       = var.ack_deadline_inbound
  message_retention_duration = local.topics.status_events.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["status_events"].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "120s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "crf_processor_status_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.crf_processor_status.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}

resource "google_pubsub_subscription" "crf_projector" {
  project = var.project_id
  name    = "${local.prefix}-sub-crf-projector"
  topic   = google_pubsub_topic.main["projection_updates"].name

  ack_deadline_seconds       = var.ack_deadline_inbound
  message_retention_duration = local.topics.projection_updates.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["projection_updates"].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "60s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "crf_projector_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.crf_projector.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}

resource "google_pubsub_subscription" "maintenance_workers" {
  project = var.project_id
  name    = "${local.prefix}-sub-maintenance-workers"
  topic   = google_pubsub_topic.main["maintenance_commands"].name

  ack_deadline_seconds       = var.ack_deadline_maintenance
  message_retention_duration = local.topics.maintenance_commands.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["maintenance_commands"].id
    max_delivery_attempts = 3
  }

  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "maintenance_workers_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.maintenance_workers.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}

resource "google_pubsub_subscription" "crf_media_handler" {
  project = var.project_id
  name    = "${local.prefix}-sub-crf-media-handler"
  topic   = google_pubsub_topic.main["media_commands"].name

  ack_deadline_seconds       = var.ack_deadline_media
  message_retention_duration = local.topics.media_commands.retention

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq["media_commands"].id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  labels = merge(var.labels, { env = var.env, managed = "terraform" })
}

resource "google_pubsub_subscription_iam_member" "crf_media_handler_dlq" {
  project      = var.project_id
  subscription = google_pubsub_subscription.crf_media_handler.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_sa
}
