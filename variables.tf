variable "project_id" {
  type    = string
  default = "project-84ddd43d-e408-4cb9-8cb"
}

variable "region" {
  type    = string
  default = "europe-west3"
}

variable "zone" {
  type    = string
  default = "europe-west3-a"
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "disk_size_gb" {
  type    = number
  default = 20
}

variable "ssh_user" {
  type    = string
  default = "jre"
}

variable "ssh_pubkey" {
  type = string
}

variable "password_hash" {
  type      = string
  sensitive = true
}

variable "acme_email" {
  type = string
}

variable "domain" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "dnszone" {
  type = string
}

variable "ssh_source_ranges" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
