output "workload_sa_emails" {
  description = "Map of workload service account names to their email addresses"
  value = {
    crf_parser    = google_service_account.crf_parser.email
    crf_receptor  = google_service_account.crf_receptor.email
    crf_sender    = google_service_account.crf_sender.email
    crf_processor = google_service_account.crf_processor.email
    crf_media     = google_service_account.crf_media.email
    crf_projector = google_service_account.crf_projector.email
    scheduler     = google_service_account.scheduler.email
  }
}
