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
  project = "shubham-project-468314"
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_instance" "vm_instance" {
  name         = "webserver"
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
      set -euo pipefail

      # Ensure priv-sep dir (usually created by service, but harmless)
      mkdir -p /run/sshd
      chmod 755 /run/sshd

      # Make sure ONLY port 22 is in the default sshd_config
      # (remove any stray 2221-2225 entries if the base image ever had them)
      sed -i -E '/^Port (2221|2222|2223|2224|2225)$/d' /etc/ssh/sshd_config
      if ! grep -qE '^[#\\s]*Port 22$' /etc/ssh/sshd_config; then
        # uncomment or add Port 22
        if grep -qE '^#\\s*Port 22$' /etc/ssh/sshd_config; then
          sed -i -E 's/^#\\s*Port 22$/Port 22/' /etc/ssh/sshd_config
        else
          echo 'Port 22' >> /etc/ssh/sshd_config
        fi
      fi

      # Restart the Ubuntu ssh unit (name is 'ssh', not 'sshd')
      systemctl restart ssh
      systemctl enable ssh
    EOF
  }
}

# Firewall: open 22 and the custom ports (Ansible will run sshd instances)
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
