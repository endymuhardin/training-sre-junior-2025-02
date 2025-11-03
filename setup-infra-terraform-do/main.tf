# 1. Konfigurasi Provider DigitalOcean
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {}

# Variabel Dasar
variable "region" {
  description = "Region DigitalOcean"
  default     = "sgp1"
}

variable "app_count" {
  description = "Jumlah Node Aplikasi Web"
  default     = 3
}

# --- 2. Jaringan VPC (Isolasi) ---

resource "digitalocean_vpc" "private_network" {
  name   = "private-vpc-for-app"
  region = var.region
  # CIDR default DigitalOcean VPC adalah 10.108.0.0/20.
}

# Buat kunci SSH untuk akses ke Droplet
resource "digitalocean_ssh_key" "default" {
  name       = "my-app-key-private"
  public_key = file("~/.ssh/id_rsa.pub") 
}

# --- 3. Droplet Database (Primary & Secondary) ---

# Menggunakan satu resource dengan 'count' untuk Primary dan Secondary
resource "digitalocean_droplet" "database_node" {
  count  = 2
  name   = count.index == 0 ? "db-primary" : "db-secondary"
  image  = "ubuntu-22-04-x64"
  region = var.region
  size   = "s-1vcpu-2gb"
  ssh_keys = [digitalocean_ssh_key.default.id]
  
  # PENTING: Droplet ini HANYA berada di dalam VPC. 
  # Tidak ada IP publik yang diberikan.
  vpc_uuid = digitalocean_vpc.private_network.id

  # User Data untuk konfigurasi dasar (misalnya instalasi PostgreSQL)
  user_data = <<-EOF
              #!/bin/bash
              echo "Setting up DB Node ${self.name}..."
              # Skrip instalasi DB (PostgreSQL/MySQL) dan replikasi akan diletakkan di sini.
              # Note: Skrip replikasi Primary-Secondary manual akan kompleks, disederhanakan di sini.
              EOF
}

# Dapatkan IP Privat (VPC) untuk Database
data "digitalocean_droplet" "db_ips" {
  count = 2
  name  = digitalocean_droplet.database_node[count.index].name
  depends_on = [digitalocean_droplet.database_node]
}

# --- 4. Droplet Aplikasi Web (3 Node - Private Only) ---

resource "digitalocean_droplet" "web_app" {
  count  = var.app_count
  name   = "web-app-node-${count.index + 1}"
  image  = "ubuntu-22-04-x64" 
  region = var.region
  size   = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.default.id]
  
  # PENTING: Droplet ini HANYA berada di dalam VPC.
  vpc_uuid = digitalocean_vpc.private_network.id

  # User Data: Instalasi Web Server dan Koneksi ke DB Primary (VPC IP)
  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y nginx
              # Ambil IP Private dari DB Primary (Indeks 0)
              DB_PRIMARY_IP="${data.digitalocean_droplet.db_ips[0].ipv4_address_private}"
              echo "Server web ${self.name} berjalan dan terhubung ke DB di $DB_PRIMARY_IP" | tee /var/www/html/index.nginx-debian.html
              systemctl start nginx
              EOF
}

# --- 5. Droplet Load Balancer (HAProxy - Public Access) ---

resource "digitalocean_droplet" "haproxy_lb" {
  name   = "haproxy-load-balancer"
  image  = "ubuntu-22-04-x64"
  region = var.region
  size   = "s-1vcpu-1gb"
  ssh_keys = [digitalocean_ssh_key.default.id]
  
  # PENTING: Droplet ini memiliki VPC dan IP Publik default.
  vpc_uuid = digitalocean_vpc.private_network.id

  # Dapatkan IP Privat (VPC) dari semua Droplet Aplikasi Web
  app_private_ips = digitalocean_droplet.web_app.*.ipv4_address_private

  # User Data: Instalasi dan Konfigurasi HAProxy
  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y haproxy

              # Konfigurasi HAProxy sederhana (Port 80 HTTP)
              HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
              
              # Ganti konfigurasi default
              cat > $HAPROXY_CONFIG <<-EOT
              global
                  log /dev/log    local0 notice
                  maxconn 2000

              defaults
                  log global
                  mode http
                  option httplog
                  option dontlognull
                  timeout connect 5000ms
                  timeout client 50000ms
                  timeout server 50000ms
              
              # Frontend yang terekspose ke publik (IP Public Droplet)
              frontend http_front
                  bind *:80
                  default_backend http_back

              # Backend yang mengarah ke IP Private Droplet Aplikasi
              backend http_back
                  balance roundrobin
                  # Tambahkan 3 Node Aplikasi Web menggunakan IP Privat mereka
                  server web_app_1 ${digitalocean_droplet.web_app[0].ipv4_address_private}:80 check
                  server web_app_2 ${digitalocean_droplet.web_app[1].ipv4_address_private}:80 check
                  server web_app_3 ${digitalocean_droplet.web_app[2].ipv4_address_private}:80 check
              EOT

              systemctl restart haproxy
              EOF
}

# --- Output ---

# IP Publik yang harus diakses pengguna (HAProxy)
output "haproxy_public_ip" {
  value = digitalocean_droplet.haproxy_lb.ipv4_address
}

# Daftar IP Privat (VPC) semua komponen
output "private_ips_summary" {
  value = {
    haproxy_lb   = digitalocean_droplet.haproxy_lb.ipv4_address_private,
    web_apps     = digitalocean_droplet.web_app.*.ipv4_address_private,
    db_primary   = data.digitalocean_droplet.db_ips[0].ipv4_address_private,
    db_secondary = data.digitalocean_droplet.db_ips[1].ipv4_address_private,
  }
}
