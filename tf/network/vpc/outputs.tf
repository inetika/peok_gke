output "vpc" {
    description = "VPC network reference"
    value = google_compute_network.main
}

output "subnet" {
    description = "VPC subnet reference"
    value = google_compute_subnetwork.main
}