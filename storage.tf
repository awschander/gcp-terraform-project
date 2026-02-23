# ──────────────────────────────────────────
# Cloud Storage Bucket
# ──────────────────────────────────────────

resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true # Allows terraform destroy to delete non-empty bucket

  # Block all public access
  public_access_prevention = "enforced"

  uniform_bucket_level_access = true
}

# ──────────────────────────────────────────
# Private Service Connect Endpoint
# This lets the VM reach Cloud Storage using
# a private IP inside your VPC (no internet)
# ──────────────────────────────────────────

# Reserve a private IP for the endpoint
resource "google_compute_global_address" "psc_endpoint_ip" {
  name         = "psc-storage"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  address_type = "INTERNAL"
  network      = google_compute_network.vpc.id
  address      = "10.0.2.2" # A free IP outside your subnet range
}

# Create the Private Service Connect endpoint pointing to Cloud Storage
resource "google_compute_global_forwarding_rule" "psc_storage" {
  name                  = "storage-psc-endpoint"
  target                = "all-apis" # Covers all Google APIs including Storage
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_global_address.psc_endpoint_ip.id
  load_balancing_scheme = "" # Must be empty for PSC
}

# ──────────────────────────────────────────
# DNS override so the VM resolves
# storage.googleapis.com → private IP
# ──────────────────────────────────────────

resource "google_dns_managed_zone" "storage_private_zone" {
  name        = "storage-private-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS for Cloud Storage via PSC"
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
  rrdatas      = [google_compute_global_address.psc_endpoint_ip.address]
}

# Wildcard to catch other *.googleapis.com calls from the VM
resource "google_dns_record_set" "wildcard_a_record" {
  name         = "*.googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.storage_private_zone.name
  rrdatas      = [google_compute_global_address.psc_endpoint_ip.address]
}
