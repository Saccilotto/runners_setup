terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a low-cost VM instance
resource "google_compute_instance" "github_runners_vm" {
  name         = "github-runners-vm"
  machine_type = "e2-medium"  # 2 vCPUs, 4GB memory - adjust based on your needs
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20  # GB
      type  = "pd-standard"  # Standard persistent disk for lower cost
    }
  }

  network_interface {
    network = "default"
    access_config {
      # This creates an ephemeral external IP
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_file)}"
  }

  # Enable OS Login for easier SSH management
  metadata_startup_script = "echo 'Done'"

  tags = ["github-runners", "docker-swarm"]

  scheduling {
    preemptible       = var.preemptible  # Set to true for lower cost, but VM may be terminated
    automatic_restart = !var.preemptible
  }

  # Allow HTTP traffic for potential web services
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Add provisioner to run Ansible after VM creation
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.network_interface[0].access_config[0].nat_ip},' --private-key ${var.ssh_private_key_file} -u ${var.ssh_user} ../ansible/setup.yml"
  }
}

# Create a firewall rule to allow SSH and Docker Swarm communication
resource "google_compute_firewall" "github_runners_firewall" {
  name    = "github-runners-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "2376", "2377", "7946", "4789", "80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["7946", "4789"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["github-runners"]
}

output "vm_ip" {
  value = google_compute_instance.github_runners_vm.network_interface[0].access_config[0].nat_ip
}
