# ── PROD Environment Configuration ─────────────────────────────────────────
# IMPORTANT: Every change to this file creates or destroys dedicated customer resources.
# Always run `terraform plan` and review carefully before applying.

project_id     = "vtss-prod"
project_number = "123456789012"  # Replace with actual prod project number

region             = "us-central1"
storage_region     = "US"
firestore_location = "nam5"

bucket_prefix = "vtss"

# Production customers — each gets fully isolated infrastructure:
#   - 2 GCS buckets (messaging + multimedia)
#   - 1 Firestore Named Database
#   - 6 Pub/Sub topics + 6 DLQ topics + 12 subscriptions
#   - 2 IAM service accounts (backend + frontend)
#   - 4 Cloud Scheduler jobs
#
# To onboard a new customer: add their ID to this list and run terraform apply.
# To offboard: remove from the list (buckets will NOT be deleted due to lifecycle rules —
# remove manually after data retention period).
customers = [
  "acme",
  "globocorp",
]

labels = {
  team        = "backend"
  cost_center = "engineering"
}
