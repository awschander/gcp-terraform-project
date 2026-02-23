# ──────────────────────────────────────────
# Cloud Storage Bucket
# ──────────────────────────────────────────
resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

# ──────────────────────────────────────────
# Private Google Access DNS
# Routes storage.googleapis.com privately
# (subnet already has private_ip_google_access = true)
# ──────────────────────────────────────────
resource "google_dns_managed_zone" "storage_private_zone" {
  name        = "storage-private-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS for Cloud Storage"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "storage_a_record" {
  name         = "storage.googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.storage_private_zone.name
  rrdatas = [
    "199.36.153.8",
    "199.36.153.9",
    "199.36.153.10",
    "199.36.153.11"
  ]
}

resource "google_dns_record_set" "wildcard_a_record" {
  name         = "*.googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.storage_private_zone.name
  rrdatas = [
    "199.36.153.8",
    "199.36.153.9",
    "199.36.153.10",
    "199.36.153.11"
  ]
}
