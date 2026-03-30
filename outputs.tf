output "public_ip" {
  value = google_compute_address.wireguard_ip.address
}

output "wg_ui" {
  value       = "https://${var.subdomain}.${var.domain}"
  description = "WireGuard UI URL"
}
