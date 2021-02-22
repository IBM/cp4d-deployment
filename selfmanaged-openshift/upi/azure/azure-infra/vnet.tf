locals {
  resource-group = var.new-or-existing == "new" ? var.resource-group : var.existing-vnet-resource-group
}

resource "azurerm_resource_group" "cpdrg" {
  name     = local.resource-group
  location = var.region
}

resource "azurerm_virtual_network" "cpdvirtualnetwork" {
  name                = var.virtual-network-name
  address_space       = [var.virtual-network-cidr]
  location            = var.region
  resource_group_name = local.resource-group
  depends_on = [
    azurerm_resource_group.cpdrg
  ]
}

resource "azurerm_subnet" "bootnode" {
  count                = var.new-or-existing == "new" ? 1 : 0
  name                 = var.bootnode-subnet-name
  resource_group_name  = local.resource-group
  virtual_network_name = var.virtual-network-name
  address_prefix       = var.bootnode-subnet-cidr
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_public_ip" "bootnode" {
  name                = "${var.cluster-name}-bootnode-pip"
  location            = var.region
  resource_group_name = local.resource-group
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.cpdrg,
  ]
}

resource "azurerm_network_interface" "bootnode" {
  name                = "${var.cluster-name}-bootnode-nic"
  location            = var.region
  resource_group_name = local.resource-group

  ip_configuration {
    name                          = "${var.cluster-name}-bootnode-nic-config"
    subnet_id                     = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${local.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.bootnode-subnet-name}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bootnode.id
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_subnet.bootnode
  ]
}

resource "azurerm_network_security_group" "bootnode" {
  count               = var.new-or-existing == "new" ? 1 : 0
  name                = "${var.cluster-name}-bootnode-nsg"
  location            = var.region
  resource_group_name = local.resource-group

  security_rule {
    name                       = "allSSHin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bootnode-source-cidr
    destination_address_prefix = var.bootnode-subnet-cidr
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
  ]
}

resource "azurerm_virtual_network_peering" "bootnode2mirrornode" {
  count                        = var.disconnected-cluster == "yes" ? 1 : 0
  name                         = "bootnodevnet2mirrornodevnet"
  resource_group_name          = azurerm_resource_group.cpdrg.name
  virtual_network_name         = azurerm_virtual_network.cpdvirtualnetwork.name
  remote_virtual_network_id    = var.mirror-node-vnet-id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_virtual_network_peering" "mirrornode2bootnode" {
  count                        = var.disconnected-cluster == "yes" ? 1 : 0
  name                         = "mirrornodevnet2bootnodevnet"
  resource_group_name          = var.mirror-node-resource-group
  virtual_network_name         = var.mirror-node-vnet-name
  remote_virtual_network_id    = azurerm_virtual_network.cpdvirtualnetwork.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}