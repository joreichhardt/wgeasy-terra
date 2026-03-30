provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_dns_managed_zone" "selected" {
  name = var.dnszone
}

resource "google_compute_address" "wireguard_ip" {
  name   = "wireguard-ip"
  region = var.region
}

resource "google_compute_firewall" "wireguard_ssh" {
  name    = "wireguard-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["wireguard"]
}

resource "google_compute_firewall" "wireguard_web" {
  name    = "wireguard-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wireguard"]
}

resource "google_compute_firewall" "wireguard_udp" {
  name    = "wireguard-udp"
  network = "default"

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wireguard"]
}

resource "google_compute_instance" "wireguard" {
  name         = "wireguard"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["wireguard"]

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/debian13-golden-v1"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip       = google_compute_address.wireguard_ip.address
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_pubkey}"
  }

  metadata_startup_script = <<-EOF
#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

mkdir -p /opt/wireguard
mkdir -p /opt/wireguard/traefik/dynamic

cat >/etc/sysctl.d/99-wireguard.conf <<'SYSCTL'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
SYSCTL

sysctl --system

apt-get update
apt-get install -y ca-certificates curl docker.io docker-compose nftables

cat >/etc/nftables.conf <<'NFT'
#!/usr/sbin/nft -f

flush ruleset

table ip nat {
  chain POSTROUTING {
    type nat hook postrouting priority 100;
    oifname "ens4" masquerade
  }
}

table ip filter {
  chain FORWARD {
    type filter hook forward priority 0;
    policy accept;
  }
}
NFT

systemctl enable nftables
systemctl restart nftables

systemctl enable docker
systemctl start docker

touch /opt/wireguard/traefik/acme.json
chmod 600 /opt/wireguard/traefik/acme.json

cat >/opt/wireguard/traefik/traefik.yml <<'TRAEFIK'
api:
  dashboard: false

providers:
  docker:
    exposedByDefault: false
  file:
    directory: /etc/traefik/dynamic
    watch: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  le:
    acme:
      email: ${var.acme_email}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
TRAEFIK

cat >/opt/wireguard/traefik/dynamic/wg.yml <<'DYNAMIC'
http:
  routers:
    wg:
      rule: "Host(`${var.subdomain}.${trimsuffix(var.domain, ".")}`)"
      entryPoints:
        - websecure
      tls:
        certResolver: le
      service: wg

  services:
    wg:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:51821"
DYNAMIC

cat >/opt/wireguard/docker-compose.yml <<'COMPOSE'
version: "3.8"

services:
  traefik:
    image: traefik:v3.4
    container_name: traefik
    restart: unless-stopped
    network_mode: "host"
    command:
      - --configFile=/etc/traefik/traefik.yml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/wireguard/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - /opt/wireguard/traefik/dynamic:/etc/traefik/dynamic:ro
      - /opt/wireguard/traefik/acme.json:/letsencrypt/acme.json

  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    restart: unless-stopped
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      INIT_ENABLED: "true"
      INIT_USERNAME: "admin"
      INIT_PASSWORD: ${jsonencode(var.password)}
      INIT_HOST: ${jsonencode("${var.subdomain}.${trimsuffix(var.domain, ".")}")}
      INIT_PORT: "51820"
      WG_MTU: "1380"
    volumes:
      - /etc/wireguard:/etc/wireguard
      - /lib/modules:/lib/modules:ro
COMPOSE

docker-compose -f /opt/wireguard/docker-compose.yml config
docker-compose -f /opt/wireguard/docker-compose.yml up -d
EOF
}

resource "google_dns_record_set" "wireguard" {
  name         = "${var.subdomain}.${trimsuffix(var.domain, ".")}."
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.selected.name

  rrdatas = [google_compute_address.wireguard_ip.address]
}
