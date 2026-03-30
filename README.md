# 🚀 WireGuard VPN + Web UI on GCP (Terraform)

Provision a **self-hosted VPN endpoint in your home country** while traveling — fully automated with **Terraform + Docker + Traefik + Let’s Encrypt**.

---

## ✨ Features

- 🌍 Deploy VPN in any GCP region (your “home country IP”)
- 🔐 WireGuard via **wg-easy Web UI**
- 🔒 Automatic HTTPS via **Traefik + Let’s Encrypt**
- ⚙️ Fully automated provisioning with Terraform
- ♻️ Ephemeral infrastructure (destroy anytime)

---

## 🏗️ Architecture

```
GCP VM (Debian)
├── Docker
│   ├── Traefik (reverse proxy + ACME)
│   └── wg-easy (WireGuard + UI)
└── Terraform (provisioning + cloud dns + state in GCS)
```

---

## ⚡ Quick Start

    git clone https://github.com/joreichhardt/wgeasy-terra
    cd wgeasy-terra

    vim terraform.tfvars


    ssh_pubkey    = ""   # optional (OS Login recommended)
    password      = "YOURPASSWD_MIN_12_Characters"
    acme_email    = "your@email.com"
    domain        = "YOURDOMAIN"
    subdomain     = "YOURSUBDOMAIN"
    dnszone       = "YOURDNSZONE"


    terraform init
    terraform apply
---

👉 After deployment:

- Web UI: https://YOURSUBDOMAIN.YOURDOMAIN
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

    gsutil mb -p <PROJECT_ID> gs://<STATE_BUCKET>

Example:

project_id        = "project-xxx"
state_bucket_name = "project-xxx-tf-state"

---

## 🌐 DNS Setup (Critical)

You must point your domain to **Google Cloud DNS**.
Or just register your domain with **Google Cloud Domains**


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

## 📌 TODO / Ideas

- Secrets via GCP Secret Manager
- Backstage Portal for one-click installation
