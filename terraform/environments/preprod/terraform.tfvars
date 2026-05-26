# ── PREPROD Environment Configuration ──────────────────────────────────────
# Each customer gets fully isolated resources (buckets, Firestore DB, Pub/Sub topics)

project_id     = "vtss-preprod"
project_number = "123456789012"  # Replace with actual preprod project number

region             = "us-central1"
storage_region     = "US"
firestore_location = "nam5"

bucket_prefix = "vtss"

# Add customer IDs here to provision dedicated resources for each.
# Format: lowercase alphanumeric with hyphens/underscores only.
# Example: customers = ["acme", "globocorp", "cliente_003"]
customers = [
  "demo_client",
]

labels = {
  team        = "backend"
  cost_center = "engineering"
}
