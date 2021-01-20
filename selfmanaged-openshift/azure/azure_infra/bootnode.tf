resource "azurerm_virtual_machine" "bootnode" {
    name                  = "${var.cluster-name}-bootnode"
    location              = var.region
    resource_group_name   = local.resource-group
    network_interface_ids = [azurerm_network_interface.bootnode.id]
    vm_size               = var.bootnode-instance-type

    storage_os_disk {
        name              = "${var.cluster-name}-bootnode-OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7-RAW"
        version   = "latest"
    }

    os_profile {
        computer_name  = "bootnode"
        admin_username = var.admin-username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.admin-username}/.ssh/authorized_keys"
            key_data = var.ssh-public-key
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.allnodes.primary_blob_endpoint
    }
    depends_on = [
        azurerm_resource_group.cpdrg,
    ]
}