# 1. Konfigurasi Provider Google Cloud
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "your-gcp-project-id" # Ganti dengan Project ID Anda
  region  = "asia-southeast1"     # Contoh: Singapura
}

variable "zone" {
  default = "asia-southeast1-a"
}

# --- 2. Jaringan VPC dan Subnet ---

resource "google_compute_network" "app_network" {
  name                    = "app-vpc-network"
  auto_create_subnetworks = false # Penting untuk kontrol alamat IP
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.10.1.0/24"
  region        = google_compute_network.app_network.region
  network       = google_compute_network.app_network.id
}

# --- 3. Firewall Rules ---

# Rule: Mengizinkan SSH internal
resource "google_compute_firewall" "internal_ssh" {
  name    = "allow-ssh-internal"
  network = google_compute_network.app_network.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["10.10.1.0/24"] # Hanya dari VPC
}

# Rule: Mengizinkan HTTP dari internet ke HAProxy (tag: haproxy-lb)
resource "google_compute_firewall" "allow_http_public" {
  name    = "allow-http-public"
  network = google_compute_network.app_network.id
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["haproxy-lb"] # Hanya berlaku untuk VM dengan tag ini
}

# Rule: Mengizinkan lalu lintas internal (DB, Web)
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-vpc-traffic"
  network = google_compute_network.app_network.id
  allow {
    protocol = "all"
  }
  source_ranges = ["10.10.1.0/24"]
}

# --- 4. Compute Engine Instances (VM) ---

# Database (2x VM - Private IP Only)
resource "google_compute_instance" "db_node" {
  count        = 2
  name         = count.index == 0 ? "db-primary" : "db-secondary"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["db-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    # PENTING: Tidak ada access_config untuk mencegah IP Publik
  }
  
  metadata_startup_script = <<-EOF
                              #!/bin/bash
                              echo "Installing database on ${self.name}..."
                              # Skrip instalasi DB dan replikasi akan diletakkan di sini.
                              EOF
}

# Web App (3x VM - Private IP Only)
resource "google_compute_instance" "web_app" {
  count        = 3
  name         = "web-app-node-${count.index + 1}"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["web-app"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    # PENTING: Tidak ada access_config untuk mencegah IP Publik
  }
  
  metadata_startup_script = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install -y nginx
                              DB_PRIMARY_IP="${google_compute_instance.db_node[0].network_interface[0].network_ip}"
                              echo "Server web ${count.index + 1} running. DB IP: $DB_PRIMARY_IP" | tee /var/www/html/index.html
                              systemctl start nginx
                              EOF
}

# Load Balancer (1x VM - Public IP)
resource "google_compute_instance" "haproxy_lb" {
  name         = "haproxy-load-balancer"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["haproxy-lb"] # Digunakan untuk Rule Firewall Publik

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    # PENTING: Menambahkan access_config untuk IP Publik
    access_config {
      # Konfigurasi IP Publik default
    }
  }
  
  metadata_startup_script = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install -y haproxy
                              HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
                              
                              # Konfigurasi HAProxy
                              cat > $HAPROXY_CONFIG <<-EOT
                              global
                                  log /dev/log    local0 notice
                                  maxconn 2000
                              defaults
                                  log global
                                  mode http
                                  timeout connect 5000ms
                                  timeout client 50000ms
                                  timeout server 50000ms
                              frontend http_front
                                  bind *:80
                                  default_backend http_back
                              backend http_back
                                  balance roundrobin
                                  server web_app_1 ${google_compute_instance.web_app[0].network_interface[0].network_ip}:80 check
                                  server web_app_2 ${google_compute_instance.web_app[1].network_interface[0].network_ip}:80 check
                                  server web_app_3 ${google_compute_instance.web_app[2].network_interface[0].network_ip}:80 check
                              EOT

                              systemctl restart haproxy
                              EOF
}

# --- 5. Output ---

output "haproxy_public_ip_gcp" {
  value = google_compute_instance.haproxy_lb.network_interface[0].access_config[0].nat_ip
}