provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "nareshnewrg"
  location = var.location
}

# VNet1 and Subnet1
resource "azurerm_virtual_network" "myvnet1" {
  name                = "myvnet1"
  address_space       = [var.vnet1_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myvnet1.name
  address_prefixes     = [var.subnet1_address_prefix]
}

# VNet2 and Subnet2
resource "azurerm_virtual_network" "myvnet2" {
  name                = "myvnet2"
  address_space       = [var.vnet3_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet2" {
  name                 = "subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.myvnet2.name
  address_prefixes     = [var.subnet2_address_prefix]
}

# Virtual Network Peering (myvnet1 <-> myvnet2)
resource "azurerm_virtual_network_peering" "peer1to2" {
  name                           = "peer1to2"
  resource_group_name            = azurerm_resource_group.rg.name
  virtual_network_name           = azurerm_virtual_network.myvnet1.name
  remote_virtual_network_id      = azurerm_virtual_network.myvnet2.id
  allow_virtual_network_access   = true
  allow_forwarded_traffic        = false
  use_remote_gateways            = false
}

resource "azurerm_virtual_network_peering" "peer2to1" {
  name                           = "peer2to1"
  resource_group_name            = azurerm_resource_group.rg.name
  virtual_network_name           = azurerm_virtual_network.myvnet2.name
  remote_virtual_network_id      = azurerm_virtual_network.myvnet1.id
  allow_virtual_network_access   = true
  allow_forwarded_traffic        = false
  use_remote_gateways            = false
}

# Public IP for VM1
resource "azurerm_public_ip" "public_ip_vm1" {
  name                = "public-ip-vm1"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"

  lifecycle {
    prevent_destroy = true
  }
}

# NIC for VM1
resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm1_private_ip
    public_ip_address_id          = azurerm_public_ip.public_ip_vm1.id
  }
}

# NIC for VM2 (NO PUBLIC IP)
resource "azurerm_network_interface" "nic2" {
  name                = "nic2"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig2"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm2_private_ip
  }
}

# VM1
resource "azurerm_virtual_machine" "vm1" {
  name                  = "vm1"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic1.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vm1-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm1"
    admin_username = var.vm_username
    admin_password = var.vm_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# VM2
resource "azurerm_virtual_machine" "vm2" {
  name                  = "vm2"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic2.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vm2-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm2"
    admin_username = var.vm_username
    admin_password = var.vm_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Outputs
output "vm1_private_ip" {
  description = "Private IP of VM1"
  value       = azurerm_network_interface.nic1.ip_configuration[0].private_ip_address
}

output "vm1_public_ip" {
  description = "Public IP of VM1"
  value       = azurerm_public_ip.public_ip_vm1.ip_address
}

output "vm2_private_ip" {
  description = "Private IP of VM2"
  value       = azurerm_network_interface.nic2.ip_configuration[0].private_ip_address
}

