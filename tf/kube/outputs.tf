output "kubernetes_cluster_name" {
  value       = google_container_cluster.main.name
  description = "GKE Cluster Name"
}