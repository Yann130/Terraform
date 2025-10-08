##########################################
#        Azure infra with Vault SSH       #
##########################################

# 1️⃣ Lecture des secrets depuis Vault
# (assure-toi que le chemin est bien "secret/data/azure")
data "vault_kv_secret_v2" "azure_secrets" {
  mount = "secret"
  name  = "azure"
}

# 2️⃣ Groupe de ressources
resource "azurerm_resource_group" "rg" {
  name     = "rg-k3s-demo"
  location = "West Europe"
}

# 3️⃣ Réseau et sous-réseaux
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-k3s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_master" {
  name                 = "subnet-master"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_worker" {
  name                 = "subnet-worker"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 4️⃣ NSG (SSH + HTTP + K3s API)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-k3s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range      = "22"
    source_port_range           = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range      = "80"
    source_port_range           = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  security_rule {
    name                       = "allow-k3s"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range      = "6443"
    source_port_range           = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }
}

# 5️⃣ IP publique
resource "azurerm_public_ip" "pubip" {
  name                = "publicip-k3s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 6️⃣ Interfaces réseau
resource "azurerm_network_interface" "nic_master" {
  name                = "nic-master"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_master.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip.id
  }
}

resource "azurerm_network_interface" "nic_worker" {
  name                = "nic-worker"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_worker.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 7️⃣ Association NSG
resource "azurerm_network_interface_security_group_association" "nsg_master" {
  network_interface_id      = azurerm_network_interface.nic_master.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nsg_worker" {
  network_interface_id      = azurerm_network_interface.nic_worker.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 8️⃣ Machines virtuelles
resource "azurerm_linux_virtual_machine" "master" {
  name                = "vm-master"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = data.vault_kv_secret_v2.azure_secrets.data["admin_username"]
  disable_password_authentication = true
  network_interface_ids = [azurerm_network_interface.nic_master.id]

  admin_ssh_key {
    username   = data.vault_kv_secret_v2.azure_secrets.data["admin_username"]
    public_key = data.vault_kv_secret_v2.azure_secrets.data["ssh_public_key"]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "worker" {
  name                = "vm-worker"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = data.vault_kv_secret_v2.azure_secrets.data["admin_username"]
  disable_password_authentication = true
  network_interface_ids = [azurerm_network_interface.nic_worker.id]

  admin_ssh_key {
    username   = data.vault_kv_secret_v2.azure_secrets.data["admin_username"]
    public_key = data.vault_kv_secret_v2.azure_secrets.data["ssh_public_key"]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}
# Fichier inventory.ini pour Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = <<EOT
[master]
${azurerm_linux_virtual_machine.master.private_ip_address} ansible_user=${data.vault_kv_secret_v2.azure_secrets.data["admin_username"]} ansible_ssh_private_key_file=~/.ssh/id_rsa

[worker]
${azurerm_linux_virtual_machine.worker.private_ip_address} ansible_user=${data.vault_kv_secret_v2.azure_secrets.data["admin_username"]} ansible_ssh_private_key_file=~/.ssh/id_rsa
EOT
}
