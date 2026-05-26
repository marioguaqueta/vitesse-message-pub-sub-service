output "job_names" {
  description = "Cloud Scheduler job names"
  value = {
    daily_aggregator         = google_cloud_scheduler_job.daily_aggregator.name
    daily_compressor         = google_cloud_scheduler_job.daily_compressor.name
    hourly_cleanup           = google_cloud_scheduler_job.hourly_cleanup.name
    weekly_purge_recent_events = google_cloud_scheduler_job.weekly_purge_recent_events.name
  }
}
