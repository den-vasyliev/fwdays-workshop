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

variable "credentials" {
  description = "The path to the service account key file"
  sensitive = true
}

provider "google" {
  project = "${var.project_id}"
  region  = "${var.region}"
  zone    = "${var.location}"
  credentials = "${var.credentials}"
}

resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}"
  location = "${var.location}"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.location}.svc.id.goog"
  }
}

resource "google_container_node_pool" "default_pool" {
  name       = "default-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "gpu_pool" {
  name       = "gpu-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "n1-standard-4"  # Adjust based on your GPU requirements

    guest_accelerator {
      type  = "nvidia-tesla-t4"  # Adjust based on your GPU requirements
      count = 1
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Install GPU drivers
    metadata = {
      install-nvidia-driver = "true"
    }
  }
}

resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}
