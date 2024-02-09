output "ip" {
  value = google_compute_address.main.address
}

output "dns_name" {
  value = google_dns_managed_zone.main.dns_name
}