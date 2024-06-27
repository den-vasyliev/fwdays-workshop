terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

variable "project_id" {
  description = "The project ID to deploy resources to"
}

variable "location" {
  description = "The location to deploy resources to"
  default     = "us-central1-a"

}

variable "region" {
  description = "The region to deploy resources to"
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  default     = "my-gke-cluster"

}

variable "machine_type" {
  description = "The machine type to use for the default node pool"
  default     = "e2-medium"
}

variable "zone" {
  description = "The zone to deploy resources to"
  default     = "us-central1-a"

}

variable "credentials" {
  description = "Credentials for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "default_credentials_file_path" {
  description = "Path to the default credentials file"
  type        = string
  default     = "~/.config/gcloud/application_default_credentials.json"
}

locals {
  credentials = var.credentials != "" ? var.credentials : file(var.default_credentials_file_path)
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials
}

resource "google_container_cluster" "primary" {
  name           = var.cluster_name
  location       = var.region
  node_locations = [var.zone]

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "cpu_pool" {
  name       = "cpu-pool"
  location   = var.location
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = var.machine_type
    disk_size_gb = "30"
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

}
resource "google_container_node_pool" "gpu_pool" {
  name       = google_container_cluster.primary.name
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 0

  autoscaling {
    total_min_node_count = "0"
    total_max_node_count = "1"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
    ]

    labels = {
      env = var.project_id
    }

    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    image_type   = "cos_containerd"
    machine_type = var.machine_type
    tags         = ["gke-node", "${var.project_id}-gke"]

    disk_size_gb = "30"
    disk_type    = "pd-standard"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
