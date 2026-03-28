output "public_ip" {
  value = google_compute_address.wireguard_ip.address
}

output "wg_ui" {
  value = "https://wg.farmelo.de"
}
