data "google_project" "project" {}

resource "google_compute_address" "main" {
  name        = "${var.cluster-name}-ip"
  description = "Static external IP address for the ingress load balancer"
  region      = var.region
}

resource "google_dns_managed_zone" "main" {
  project     = data.google_project.project.project_id
  name        = "gke"
  dns_name    = "${var.cluster-name}.${var.domain}."
  description = "${var.cluster-name} GKE DNS zone"
}

resource "google_dns_record_set" "ns" {
  project      = var.dns_project_id
  name         = "${var.cluster-name}.${var.domain}."
  managed_zone = var.managed_zone_name
  type         = "NS"
  ttl          = 60

  rrdatas = google_dns_managed_zone.main.name_servers
}

resource "google_dns_record_set" "as_wildcard" {
  name         = "*.${google_dns_managed_zone.main.dns_name}"
  managed_zone = google_dns_managed_zone.main.name
  type         = "A"
  ttl          = 60

  rrdatas = [google_compute_address.main.address]
}