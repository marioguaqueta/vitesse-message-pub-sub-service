# ── DEV Environment Configuration ──────────────────────────────────────────
# Fill in your actual GCP values before running terraform apply

project_id     = "vtss-dev"          # Replace with your actual project ID
project_number = "123456789012"      # Replace with: gcloud projects describe vtss-dev --format='value(projectNumber)'

region             = "us-central1"
storage_region     = "US"
firestore_location = "nam5"

# Prefix must be globally unique — add your org suffix (e.g. "vtss-mycompany")
bucket_prefix = "vtss"

labels = {
  team = "backend"
  cost_center = "engineering"
}
