terraform {
  required_version = ">= 0.11.7"
}

provider "google" {
  version     = "~> 3.23"
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
  monitoring_service       = "none"
  logging_service          = "none"

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "default-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 3
  autoscaling {
    min_node_count = 3
    max_node_count = 4
  }

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"
    disk_size_gb = 10

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
  name       = "infra-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  node_config {
    preemptible  = true
    machine_type = "n1-standard-2"
    disk_size_gb = 10

    metadata = {
      disable-legacy-endpoints = "true"
    }

    taint {
      key    = "node-role"
      value  = "infra"
      effect = "NO_SCHEDULE"
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
