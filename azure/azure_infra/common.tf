resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = local.resource-group
    }
    byte_length = 8
}

resource "azurerm_storage_account" "allnodes" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.cpdrg.name
    location                    = var.region
    account_replication_type    = "LRS"
    account_tier                = "Standard"
    depends_on = [
        azurerm_resource_group.cpdrg,
    ]
}