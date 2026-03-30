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
      nat_ip = google_compute_address.wireguard_ip.address
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

  if [ -f /opt/wireguard/.startup-done ]; then
    exit 0
  fi

  apt-get update
  apt-get install -y ca-certificates curl docker.io docker-compose

  systemctl enable docker
  systemctl start docker

  mkdir -p /opt/wireguard/traefik

  touch /opt/wireguard/traefik/acme.json
  chmod 600 /opt/wireguard/traefik/acme.json

  cat >/opt/wireguard/.env <<ENVFILE
  ACME_EMAIL=${var.acme_email}
  ENVFILE

  chmod 600 /opt/wireguard/.env

  cat >/opt/wireguard/docker-compose.yml <<'COMPOSE'
  services:
    traefik:
      image: traefik:v3.4
      container_name: traefik
      restart: unless-stopped
      command:
        - --providers.docker=true
        - --providers.docker.exposedbydefault=false
        - --entrypoints.web.address=:80
        - --entrypoints.websecure.address=:443
        - --certificatesresolvers.le.acme.email=$${ACME_EMAIL}
        - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json
        - --certificatesresolvers.le.acme.httpchallenge=true
        - --certificatesresolvers.le.acme.httpchallenge.entrypoint=web
      ports:
        - "80:80"
        - "443:443"
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
        - /opt/wireguard/traefik/acme.json:/letsencrypt/acme.json
      env_file:
        - .env
      networks:
        - proxy

    wg-easy:
      image: ghcr.io/wg-easy/wg-easy:15
      container_name: wg-easy
      restart: unless-stopped
      cap_add:
        - NET_ADMIN
        - SYS_MODULE
      environment:
        INIT_ENABLED: "true"
        INIT_USERNAME: "admin"
        INIT_PASSWORD: "${var.password}"
        INIT_HOST: "${var.subdomain}.${var.domain}"
        INIT_PORT: "51820"
      volumes:
        - /etc/wireguard:/etc/wireguard
        - /lib/modules:/lib/modules:ro
      ports:
        - "51820:51820/udp"
      sysctls:
        - net.ipv4.ip_forward=1
        - net.ipv4.conf.all.src_valid_mark=1
      labels:
        - traefik.enable=true
        - traefik.http.routers.wg.rule=Host(`${var.subdomain}.${var.domain}`)
        - traefik.http.routers.wg.entrypoints=websecure
        - traefik.http.routers.wg.tls=true
        - traefik.http.routers.wg.tls.certresolver=le
        - traefik.http.services.wg.loadbalancer.server.port=51821
      env_file:
        - .env
      networks:
        - proxy

  networks:
    proxy:
      driver: bridge
  COMPOSE

  cat >/etc/systemd/system/wireguard-firstboot.service <<'UNIT'
  [Unit]
  Description=WireGuard first boot deploy
  Requires=docker.service
  After=docker.service network-online.target
  Wants=network-online.target
  ConditionPathExists=/opt/wireguard/.deploy-once

  [Service]
  Type=oneshot
  WorkingDirectory=/opt/wireguard
  ExecStart=/usr/bin/docker compose up -d
  ExecStartPost=/usr/bin/rm -f /opt/wireguard/.deploy-once
  TimeoutStartSec=0

  [Install]
  WantedBy=multi-user.target
  UNIT

  touch /opt/wireguard/.deploy-once
  touch /opt/wireguard/.startup-done

  systemctl daemon-reload
  systemctl enable wireguard-firstboot.service

  reboot
EOF
}

resource "google_dns_record_set" "wireguard" {
  name         = "${var.subdomain}.${trimsuffix(var.domain, ".")}."
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.selected.name

  rrdatas = [google_compute_address.wireguard_ip.address]
}
