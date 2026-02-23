output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_name" {
  value = google_compute_subnetwork.subnet.name
}

output "vm_name" {
  value = google_compute_instance.vm.name
}

output "vm_internal_ip" {
  description = "VM has no public IP — accessible only within VPC"
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "bucket_name" {
  value = google_storage_bucket.bucket.name
}

output "psc_endpoint_ip" {
  description = "Private IP used to reach Cloud Storage from within the VPC"
  value       = google_compute_global_address.psc_endpoint_ip.address
}
