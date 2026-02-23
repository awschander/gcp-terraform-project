variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "bucket_name" {
  description = "Cloud Storage bucket name (must be globally unique)"
  type        = string
  default     = "cka-app-bucket-2026"
}
