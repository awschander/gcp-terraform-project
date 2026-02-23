terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Store Terraform state in a GCS bucket (create this bucket manually once)
  backend "gcs" {
    bucket = "project-with-cka-tfstate-bucket-name" # <-- change this
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}