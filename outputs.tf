output "public_ip" {
  description = "IP publique du master"
  value       = azurerm_public_ip.pubip.ip_address
}

output "master_private_ip" {
  value = azurerm_network_interface.nic_master.private_ip_address
}

output "worker_private_ip" {
  value = azurerm_network_interface.nic_worker.private_ip_address
}
