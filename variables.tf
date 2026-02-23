variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     =  "project-with-cka"
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
  default = "project-with-cka-tfstate-bucket-name"
}
