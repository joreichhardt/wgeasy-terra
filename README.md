# 🚀 WireGuard VPN + Web UI on GCP (Terraform)

Provision a **self-hosted VPN endpoint in your home country** while traveling — fully automated with **Terraform + Docker + Traefik + Let’s Encrypt**.

---

## ✨ Features

- 🌍 Deploy VPN in any GCP region (your “home country IP”)
- 🔐 WireGuard via **wg-easy Web UI**
- 🔒 Automatic HTTPS via **Traefik + Let’s Encrypt**
- ⚙️ Fully automated provisioning with Terraform
- ♻️ Ephemeral infrastructure (destroy anytime)
- 🧠 Idempotent bootstrap via **GCE startup scripts + systemd**

---

## 🏗️ Architecture

```
GCP VM (Debian)
├── Docker
│   ├── Traefik (reverse proxy + ACME)
│   └── wg-easy (WireGuard + UI)
├── systemd (one-shot bootstrap)
└── Terraform (provisioning + cloud dns + state in GCS)
```

---

## ⚡ Quick Start

    git clone https://github.com/joreichhardt/wgeasy-terra
    cd wgeasy-terra

    vim terraform.tfvars


hcl
ssh_pubkey    = ""   # optional (OS Login recommended)
password      = "YOURPASSWD_MIN_12_Characters"
acme_email    = "your@email.com"
domain        = "YOURDOMAIN"
subdomain     = "YOURSUBDOMAIN"
dnszone       = "YOURDNSZONE"


terraform init
terraform apply
```

👉 After deployment:

- Web UI: https://wg.YOURDOMAIN
- Login with your configured password

---

## 🧾 Prerequisites

### GCP

- Project created
- Billing enabled
- APIs enabled:
  - Compute Engine
  - Cloud DNS (recommended)

### Terraform State (GCS)

Create a bucket:

```bash
gsutil mb -p <PROJECT_ID> gs://<STATE_BUCKET>
```

Example:

```hcl
project_id        = "project-xxx"
state_bucket_name = "project-xxx-tf-state"
```

---

## 🌐 DNS Setup (Critical)

You must point your domain to **Google Cloud DNS**.

### Nameservers:

```
ns-cloud-b1.googledomains.com
ns-cloud-b2.googledomains.com
ns-cloud-b3.googledomains.com
ns-cloud-b4.googledomains.com
```

Then create:

```
wg.YOUR-DOMAIN → A → <VM_PUBLIC_IP
THIS IS DONE BY TERRAFORM
```

---

## ⚙️ Configuration

### terraform.tfvars

```hcl
ssh_pubkey    = ""   # optional (OS Login recommended)
password      = "YOURPASSWD_MIN_12_Characters"
acme_email    = "your@email.com"
domain        = "YOURDOMAIN"
subdomain     = "YOURSUBDOMAIN"
dnszone       = "YOURDNSZONE"

```

---

## 🔐 Password Hash

    seems to be fixed in latest version

You need to run the container one time locally to exec wgpw to get a valid hash for your tfvars

```bash
    docker run ghcr.io/wg-easy/wg-easy:nightly wgpw YOURPASSWORD
```

---

## 🧠 Bootstrapping Logic

The VM uses a **two-phase initialization**:

1. Startup Script
   - installs Docker
   - writes config (.env, docker-compose.yml)
   - installs systemd unit
   - triggers reboot

2. systemd one-shot service
   - runs docker compose up -d
   - removes bootstrap marker
   - never runs again

👉 Ensures clean, idempotent provisioning.

---

## 🔄 Lifecycle

Destroy everything:

```bash
terraform destroy
```

---

## 🔍 Troubleshooting

### DNS not resolving

```bash
dig fqdn +short
```

If empty → check nameservers (NOT DNS records)

---

### Containers not running

```bash
docker ps -a
docker logs wg-easy
docker logs traefik
```

---

### HTTPS / ACME issues

```bash
docker logs traefik --tail 100
```

Common causes:
- DNS not propagated
- port 80/443 blocked

---

## 🔓 Ports

Ensure GCP firewall allows:
(this is already done by Terraform)

- TCP 80 (HTTP / ACME)
- TCP 443 (HTTPS)
- UDP 51820 (WireGuard)

---

## 🧹 Notes

- VM reboots once after provisioning
- Containers use restart: unless-stopped
- No re-provisioning on reboot
- No manual Docker interaction required

---

## 🧠 Why this approach?

- No config drift
- Fully reproducible infrastructure
- Clean separation: Terraform vs runtime
- Minimal operational overhead

---

## 📌 TODO / Ideas

- Multi-region deployment
- Terraform module extraction
- Secrets via GCP Secret Manager
- WireGuard peer automation (API)
