# Lire le secret existant
data "vault_kv_secret_v2" "azure_existing" {
  mount = "secret"
  name  = "azure"
}

# Écrire le secret mis à jour sans écraser les autres champs
resource "vault_kv_secret_v2" "azure_update" {
  mount     = "secret"
  name      = "azure"
  data_json = jsonencode(
    merge(
      data.vault_kv_secret_v2.azure_existing.data,
      { public_ip = azurerm_public_ip.pubip.ip_address }
    )
  )

  depends_on = [azurerm_public_ip.pubip]
}
