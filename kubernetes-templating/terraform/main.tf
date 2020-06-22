terraform {
  required_version = ">= 0.11.7"
}

provider "google" {
  credentials = file("~/infra-368d41e653d5.json")
  project     = var.project
  region      = var.region
}

resource "google_container_cluster" "primary" {
  name                     = "my-cluster"
  min_master_version       = 1.16
  location                 = var.zone
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "g1-small"
    disk_size_gb = 20

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

/*resource "google_container_node_pool" "secondary_preemptible_nodes" {
  name       = "my-node-pool2"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"
    disk_size_gb = 20

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}*/

resource "google_compute_firewall" "k8s_nodeports" {
  name        = "k8s-nodeports"
  description = "My k8s rule"
  network     = "default"

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = var.source_ranges
}
