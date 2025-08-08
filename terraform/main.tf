variable "ssh_user" {
  type = string
}

variable "ssh_pub_key" {
  type = string
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project     = "shubham-project-468314"
  region      = "us-central1"
  zone        = "us-central1-a"
}

resource "google_compute_instance" "vm_instance" {
  name         = "small-see"
  machine_type = "e2-small"
  zone         = "us-central1-a"
  tags         = ["ssh-access"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_pub_key}"

    startup-script = <<-EOF
      #!/bin/bash
      set -e

      # Ensure sshd privilege separation dir exists
      mkdir -p /run/sshd
      chmod 755 /run/sshd

      # Add extra ports if not already present
      PORTS="22 2221 2222 2223 2224 2225"
      for PORT in $PORTS; do
        grep -q "^Port $PORT" /etc/ssh/sshd_config || echo "Port $PORT" >> /etc/ssh/sshd_config
      done

      # Restart ssh service
      systemctl restart sshd
    EOF
  }
}

resource "google_compute_firewall" "allow_custom_ssh" {
  name    = "allow-custom-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "2221", "2222", "2223", "2224", "2225"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
}

output "vm_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
