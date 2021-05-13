data "azurerm_resource_group" "RG" {
  name = var.rg_name
}

resource "azurerm_linux_virtual_machine" "kubernetesvm0" {
  name                = "${var.kubernetesvm}0"
  resource_group_name = var.rg_name
  location            = data.azurerm_resource_group.RG.location
  size                = var.vm_size
  admin_username      = "kubeadmin"
  network_interface_ids = [
    azurerm_network_interface.nwinterface[0].id,
  ]

  admin_ssh_key {
    username   = "kubeadmin"
    public_key = var.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = "60"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  #   boot_diagnostics {
  #   enabled     = false
  # }

  provisioner "local-exec" {
    command = <<EOF
ansible-galaxy install -r ../ansible/requirements.yml --force \
&& az vm wait -g "${data.azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.kubernetesvm0.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& sleep 60 \
&& ansible-playbook -i "${self.public_ip_address},"  \
../ansible/playbook_kubernetes.yaml
EOF
  }


  tags = local.common_tags

  # depends_on = [
  #   azurerm_linux_virtual_machine.kubernetesvm1,
  #   azurerm_linux_virtual_machine.kubernetesvm2
  # ]
}


# resource "azurerm_linux_virtual_machine" "kubernetesvm1" {
#   name                = "${var.kubernetesvm}1"
#   resource_group_name = data.azurerm_resource_group.RG.name
#   location            = data.azurerm_resource_group.RG.location
#   size                = var.vm_size
#   admin_username      = "kubeadmin"
#   network_interface_ids = [
#     azurerm_network_interface.nwinterface[1].id,
#   ]

#   admin_ssh_key {
#     username   = "kubeadmin"
#     public_key = var.public_key_openssh
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "StandardSSD_LRS"
#     disk_size_gb         = "60"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   #   boot_diagnostics {
#   #   enabled     = false
#   # }

#   provisioner "local-exec" {
#     command = <<EOF
# ansible-galaxy install -r ../ansible/requirements.yml --force \
# && az vm wait -g "${data.azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.kubernetesvm1.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
# && sleep 60 \
# && ansible-playbook -i "${self.public_ip_address},"  \
# ../ansible/playbook_kubernetes.yaml
# EOF
#   }

#   tags = local.common_tags
# }

# resource "azurerm_linux_virtual_machine" "kubernetesvm2" {
#   name                = "${var.kubernetesvm}2"
#   resource_group_name = data.azurerm_resource_group.RG.name
#   location            = data.azurerm_resource_group.RG.location
#   size                = var.vm_size
#   admin_username      = "kubeadmin"
#   network_interface_ids = [
#     azurerm_network_interface.nwinterface[2].id,
#   ]

#   admin_ssh_key {
#     username   = "kubeadmin"
#     public_key = var.public_key_openssh
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "StandardSSD_LRS"
#     disk_size_gb         = "60"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   #   boot_diagnostics {
#   #   enabled     = false
#   # }

#   provisioner "local-exec" {
#     command = <<EOF
# ansible-galaxy install -r ../ansible/requirements.yml --force \
# && az vm wait -g "${data.azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.kubernetesvm2.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
# && sleep 60 \
# && ansible-playbook -i "${self.public_ip_address},"  \
# ../ansible/playbook_kubernetes.yaml
# EOF
#   }
#   tags = local.common_tags
# }


### sort out these storage accounts that get created NetworkWatcherRG DefaultResourceGroup-WEU with LogAnalytics workspace
### find a way to replace sleep 60 with a real check