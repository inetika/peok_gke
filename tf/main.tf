# The region in which you want to build the cluster
# nodes will be available in the -b and -c AZs of that region
variable "region" {
  default = "us-west2"
}

# This will be the name of the cluster as well as the subdomain if
# you're enabling DNS module below.
variable "cluster-name" {
  default = "gke"
}

provider "google" {
  # project = "{{ YOUR PROJECT ID }}"
  region  = var.region
}

module "vpc" {
    source = "./network/vpc"
    region = var.region
}

module "kube_public" {
    source = "./kube"
    region = var.region
    vpc = module.vpc.vpc
    subnet = module.vpc.subnet
    cluster-name = var.cluster-name
}

# If you want to connect an existing domain to your GKE cluster this module can do it for you.
# this will make the GKE's ingress accessible on:
# *.gke.{domain}
# module "dns" {
#     source = "./network/dns"
#     cluster-name = var.cluster-name
#     region = var.region
#     # project where parent Cloud DNS zone is located
#     dns_project_id = "{{ YOUR PROJECT ID }}" 
#     # your domain without the last dot
#     domain = "example.com"
#     # the name of your managed zone
#     managed_zone_name = "myzonename"
# }
#
# output "lb_ip" {
#   value = module.dns.ip
#   description = "GKE Nginx Ingress IP"
# }

# output "dns_name" {
#   value = module.dns.dns_name
#   description = "GKE Domain"
# }

output "kubernetes_cluster_name" {
  value       = module.kube_public.kubernetes_cluster_name
  description = "GKE Cluster Name"
}

output "region" {
  value = var.region
  description = "Cluster region"
}