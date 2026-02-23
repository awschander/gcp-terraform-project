# ──────────────────────────────────────────
# VPC Network
# ──────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false   # We create subnets manually
}

# Subnet for the VM
resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  # Enable Private Google Access so VM can reach GCP services
  # (like Cloud Storage) without a public IP
  private_ip_google_access = true
}

# Firewall rule: allow SSH only (for learning/debugging)
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # In production, restrict this to your IP range
  source_ranges = ["0.0.0.0/0"]
}

# Firewall rule: allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.1.0/24"]
}
