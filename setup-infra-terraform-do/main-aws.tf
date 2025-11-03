# 1. Konfigurasi Provider AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1" # Contoh: Singapura
}

variable "ami_id" {
  description = "AMI ID untuk Ubuntu 22.04"
  # Ganti dengan AMI yang sesuai untuk region Anda (misalnya Ubuntu 22.04 LTS)
  default     = "ami-0eb2693821ce7d032" 
}

# --- 2. Jaringan VPC dan Subnet ---

resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "app-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Diperlukan untuk HAProxy
  availability_zone       = "ap-southeast-1a"
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false # Tidak ada IP Publik
  availability_zone       = "ap-southeast-1a"
  tags = { Name = "private-subnet" }
}

# Gateway Internet untuk koneksi publik (hanya untuk HAProxy)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.app_vpc.id
}

# Tabel Rute Publik
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- 3. Security Groups (Firewall) ---

# SG untuk Load Balancer: Membuka Port 80 (HTTP) dari Internet
resource "aws_security_group" "lb_sg" {
  name        = "lb-security-group"
  vpc_id      = aws_vpc.app_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Akses dari mana saja
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG untuk Internal: Memungkinkan lalu lintas dari LB ke Aplikasi dan Aplikasi ke DB
resource "aws_security_group" "internal_sg" {
  name        = "internal-security-group"
  vpc_id      = aws_vpc.app_vpc.id
  # Memungkinkan lalu lintas internal penuh antar instance di grup ini
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  # Memungkinkan HAProxy (LB) mengakses node aplikasi (Port 80)
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }
  # Memungkinkan Aplikasi mengakses DB (Port 5432 - PostgreSQL)
  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [aws_security_group.internal_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 4. EC2 Instances (Droplets) ---

# Database (2x EC2 - Private Subnet)
resource "aws_instance" "db_node" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = "your-key-pair-name" # Ganti dengan nama key pair AWS Anda
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  tags = {
    Name = count.index == 0 ? "DB-Primary" : "DB-Secondary"
  }
  # User data untuk konfigurasi DB awal
  user_data = <<-EOF
              #!/bin/bash
              echo "Installing database on ${self.tags.Name}..."
              # Skrip instalasi PostgreSQL dan replikasi akan diletakkan di sini.
              EOF
}

# Web App (3x EC2 - Private Subnet)
resource "aws_instance" "web_app" {
  count                  = 3
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = "your-key-pair-name"
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  tags = { Name = "Web-App-Node-${count.index + 1}" }
  
  # User Data: Instalasi Web Server dan Koneksi ke DB Primary
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              DB_PRIMARY_IP="${aws_instance.db_node[0].private_ip}"
              echo "Server web ${count.index + 1} running. DB IP: $DB_PRIMARY_IP" | tee /var/www/html/index.html
              systemctl start nginx
              EOF
}

# Load Balancer (1x EC2 - Public Subnet)
resource "aws_instance" "haproxy_lb" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = "your-key-pair-name"
  vpc_security_group_ids = [aws_security_group.lb_sg.id, aws_security_group.internal_sg.id]
  associate_public_ip_address = true # Mendapatkan IP Publik
  tags = { Name = "HAProxy-Load-Balancer" }

  # User Data: Instalasi dan Konfigurasi HAProxy
  user_data = <<-EOF
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
                  server web_app_1 ${aws_instance.web_app[0].private_ip}:80 check
                  server web_app_2 ${aws_instance.web_app[1].private_ip}:80 check
                  server web_app_3 ${aws_instance.web_app[2].private_ip}:80 check
              EOT

              systemctl restart haproxy
              EOF
}

# --- 5. Output ---

output "haproxy_public_ip_aws" {
  value = aws_instance.haproxy_lb.public_ip
}