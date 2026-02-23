# ──────────────────────────────────────────
# Service Account for the VM
# The VM will use this identity to access Cloud Storage
# ──────────────────────────────────────────

resource "google_service_account" "vm_sa" {
  account_id   = "vm-service-account"
  display_name = "VM Service Account"
}

# Grant the VM's service account access to read/write the bucket
resource "google_storage_bucket_iam_member" "vm_bucket_access" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}

# ──────────────────────────────────────────
# Compute VM Instance
# ──────────────────────────────────────────

resource "google_compute_instance" "vm" {
  name         = "my-vm"
  machine_type = "e2-micro" # Free tier eligible
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20 # GB
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id

    # No access_config block = NO public IP (private only)
    # The VM uses Private Google Access to reach Cloud Storage
  }

  # Attach the service account so the VM can authenticate to GCP
  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script: installs gsutil to interact with Cloud Storage
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y google-cloud-cli
    echo "VM is ready. Test with: gsutil ls gs://${google_storage_bucket.bucket.name}"
  EOF

  tags = ["my-vm"]
}