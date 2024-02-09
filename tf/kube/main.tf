data "google_project" "project" {
}

locals {
  project = trimprefix(data.google_project.project.id, "projects/")
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes per zone"
}

# GKE cluster
data "google_container_engine_versions" "gke_version" {
  location = var.region
  version_prefix = "1.27."
}

resource "google_container_cluster" "main" {
  name     = var.cluster-name
  location = var.region
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode          = "VPC_NATIVE"
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc.name
  subnetwork = var.subnet.name

  node_locations = [
    "${var.region}-b",
    "${var.region}-c",
  ]
  
  # addons_config {
  #   http_load_balancing {
  #     disabled = true
  #   }
  #   horizontal_pod_autoscaling {
  #     disabled = false
  #   }
  # }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${local.project}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }

}

resource "google_service_account" "kubernetes" {
  account_id = "kubernetes"
}

resource "google_container_node_pool" "traffic" {
  name       = "traffic-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  
  version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    service_account = google_service_account.kubernetes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      role = "traffic"
    }

    taint {
      key = "role"
      value = "traffic"
      effect = "NO_SCHEDULE"
    }

    # preemptible  = true
    machine_type = "e2-small"
    tags         = ["gke-node", var.cluster-name]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    disk_size_gb = 50    
  }
}

resource "google_container_node_pool" "default" {
  name       = "default-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  
  version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      role = "default"
    }

    # preemptible  = true
    machine_type = "e2-small"
    tags         = ["gke-node", var.cluster-name]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    disk_size_gb = 50    
  }
}