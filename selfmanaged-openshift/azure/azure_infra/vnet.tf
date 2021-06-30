locals {
  resource-group       = var.new-or-existing == "new" ? var.resource-group : var.existing-vnet-resource-group
  bootnode_ip_address  = var.privateBootnode == "yes" ? azurerm_network_interface.bootnode-pvt[0].private_ip_address : azurerm_public_ip.bootnode[0].ip_address
  network_interface_id = var.privateBootnode == "yes" ? azurerm_network_interface.bootnode-pvt[0].id : azurerm_network_interface.bootnode-pub[0].id
}

resource "null_resource" "az_validation_check" {
  provisioner "local-exec" {
    command = "chmod +x ./*.sh"
  }
  provisioner "local-exec" {
    command = "./az_resource_quota_validation.sh -appId ${var.azure-client-id} -password ${var.azure-client-secret} -tenantId ${var.azure-tenant-id} -subscriptionId ${var.azure-subscription-id} -region ${var.region} -printlog false ; if [ $? -ne 0 ] ; then echo \"Resource quota validation Failed\" ; exit 1 ; fi"
    # after false ## -is_wsl ${var.watson-studio-library} -is_wkc ${var.watson-knowledge-catalog} -is_wml ${var.watson-machine-learning} -is_dv ${var.data-virtualization} -is_wos ${var.watson-ai-openscale} -is_spark ${var.apache-spark} -is_cde ${var.cognos-dashboard-embedded} -is_streams ${var.streams} -is_streams_flows ${var.streams-flows} -is_db2wh ${var.db2-warehouse} -is_ds ${var.datastage} -is_db2oltp ${var.db2-advanced-edition} -is_dods ${var.decision-optimization} -is_spss ${var.spss-modeler} -is_bigsql ${var.db2-bigsql} -is_pa ${var.planning-analytics} -is_ca ${var.cognos-analytics}
  }
}

resource "azurerm_resource_group" "cpdrg" {
  count    = var.new-or-existing == "new" && var.existing-resource-group == "no" ? 1 : 0
  name     = var.resource-group
  location = var.region
  depends_on = [
    null_resource.az_validation_check,
  ]
}

resource "azurerm_virtual_network" "cpdvirtualnetwork" {
  count               = var.new-or-existing == "new" ? 1 : 0
  name                = var.virtual-network-name
  address_space       = [var.virtual-network-cidr]
  location            = var.region
  resource_group_name = var.resource-group
  depends_on = [
    azurerm_resource_group.cpdrg,
  ]
}

resource "azurerm_subnet" "bootnode" {
  count                = var.new-or-existing == "new" ? 1 : 0
  name                 = var.bootnode-subnet-name
  resource_group_name  = var.resource-group
  virtual_network_name = var.virtual-network-name
  address_prefix       = var.bootnode-subnet-cidr
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_subnet" "masternode" {
  count                = var.new-or-existing == "new" ? 1 : 0
  name                 = var.master-subnet-name
  resource_group_name  = var.resource-group
  virtual_network_name = var.virtual-network-name
  address_prefix       = var.master-subnet-cidr
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_subnet" "workernode" {
  count                = var.new-or-existing == "new" ? 1 : 0
  name                 = var.worker-subnet-name
  resource_group_name  = var.resource-group
  virtual_network_name = var.virtual-network-name
  address_prefix       = var.worker-subnet-cidr
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_public_ip" "bootnode" {
  count               = var.privateBootnode == "no" ? 1 : 0
  name                = "bootnode-pip"
  location            = var.region
  resource_group_name = var.resource-group
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.cpdrg,
  ]
}

resource "azurerm_network_interface" "bootnode-pub" {
  count               = var.privateBootnode == "no" ? 1 : 0
  name                = "bootnode-nic"
  location            = var.region
  resource_group_name = var.resource-group

  ip_configuration {
    name                          = "bootnode-nic-config"
    subnet_id                     = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.bootnode-subnet-name}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bootnode[count.index].id
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_subnet.bootnode,
  ]
}

resource "azurerm_network_interface" "bootnode-pvt" {
  count               = var.privateBootnode == "yes" ? 1 : 0
  name                = "bootnode-nic"
  location            = var.region
  resource_group_name = var.resource-group

  ip_configuration {
    name                          = "bootnode-nic-config"
    subnet_id                     = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.bootnode-subnet-name}"
    private_ip_address_allocation = "Static"
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_subnet.bootnode,
  ]
}

resource "azurerm_network_interface" "nfs" {
  count               = var.storage == "nfs" ? 1 : 0
  name                = "nfs-nic"
  location            = var.region
  resource_group_name = var.resource-group

  ip_configuration {
    name                          = "nfs-nic-config"
    subnet_id                     = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.worker-subnet-name}"
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_subnet.workernode,
  ]
}

resource "azurerm_network_security_group" "bootnode" {
  count               = var.new-or-existing == "new" ? 1 : 0
  name                = "bootnode-nsg"
  location            = var.region
  resource_group_name = var.resource-group

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

resource "azurerm_network_security_group" "master" {
  count               = var.new-or-existing == "new" ? 1 : 0
  name                = "master-nsg"
  location            = var.region
  resource_group_name = var.resource-group


  security_rule {
    name                       = "apiServer"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bootnode-subnet-cidr
    destination_address_prefix = var.master-subnet-cidr
  }
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_network_security_group" "worker" {
  count               = var.new-or-existing == "new" ? 1 : 0
  name                = "worker-nsg"
  location            = var.region
  resource_group_name = var.resource-group

  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork
  ]
}

resource "azurerm_network_security_rule" "nfsin" {
  count                       = var.storage == "nfs" && var.new-or-existing == "new" ? 1 : 0
  name                        = "nfsin"
  priority                    = 700
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "2049"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource-group
  network_security_group_name = azurerm_network_security_group.worker[count.index].name
}

resource "azurerm_network_security_rule" "worker-https" {
  count                       = var.new-or-existing == "new" ? 1 : 0
  name                        = "https"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource-group
  network_security_group_name = azurerm_network_security_group.worker[count.index].name
}

resource "azurerm_network_security_rule" "worker-http" {
  count                       = var.new-or-existing == "new" ? 1 : 0
  name                        = "http"
  priority                    = 501
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource-group
  network_security_group_name = azurerm_network_security_group.worker[count.index].name
}

resource "azurerm_network_security_rule" "worker-ssh" {
  count                       = var.new-or-existing == "new" ? 1 : 0
  name                        = "ssh"
  priority                    = 503
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.bootnode-subnet-cidr
  destination_address_prefix  = var.worker-subnet-cidr
  resource_group_name         = var.resource-group
  network_security_group_name = azurerm_network_security_group.worker[count.index].name
}

resource "azurerm_subnet_network_security_group_association" "master" {
  count                     = var.new-or-existing == "new" ? 1 : 0
  subnet_id                 = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.master-subnet-name}"
  network_security_group_id = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/networkSecurityGroups/${azurerm_network_security_group.master[count.index].name}"
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork,
    azurerm_subnet.masternode
  ]
}

resource "azurerm_subnet_network_security_group_association" "worker" {
  count                     = var.new-or-existing == "new" ? 1 : 0
  subnet_id                 = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.worker-subnet-name}"
  network_security_group_id = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/networkSecurityGroups/${azurerm_network_security_group.worker[count.index].name}"
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork,
    azurerm_subnet.workernode
  ]
}

resource "azurerm_subnet_network_security_group_association" "bootnode" {
  count                     = var.new-or-existing == "new" ? 1 : 0
  subnet_id                 = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/virtualNetworks/${var.virtual-network-name}/subnets/${var.bootnode-subnet-name}"
  network_security_group_id = "/subscriptions/${var.azure-subscription-id}/resourceGroups/${var.resource-group}/providers/Microsoft.Network/networkSecurityGroups/${azurerm_network_security_group.bootnode[count.index].name}"
  depends_on = [
    azurerm_resource_group.cpdrg,
    azurerm_virtual_network.cpdvirtualnetwork,
    azurerm_subnet.bootnode
  ]
}