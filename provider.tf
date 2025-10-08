##########################################
# Provider configuration (Azure + Vault) #
##########################################

terraform {
  required_version = ">= 1.2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.22.0"
    }
  }
}

# Azure provider
provider "azurerm" {
  features {}
}

# Vault provider (à adapter si ton Vault est distant)
provider "vault" {
  address = "http://127.0.0.1:8200"
  token   =  var.token_vault
}
