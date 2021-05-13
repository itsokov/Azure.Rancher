data "azurerm_resource_group" "RG" {
  name = var.rg_name
}


resource "azurerm_linux_virtual_machine" "vaultvm0" {
  name                = "${var.vaultvm}0"
  resource_group_name = data.azurerm_resource_group.RG.name
  location            = data.azurerm_resource_group.RG.location
  size                = var.vm_size
  admin_username      = "vaultadmin"
  network_interface_ids = [
    azurerm_network_interface.nwinterface[0].id,
  ]

  admin_ssh_key {
    username   = "vaultadmin"
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

  provisioner "local-exec" {
    command = <<EOF
ansible-galaxy install -r ../ansible/requirements.yml --force \
&& az vm wait -g "${data.azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.vaultvm0.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& sleep 60 \
&& ansible-playbook -i "${self.public_ip_address},"  \
../ansible/playbook_vault.yaml \
--extra-vars '\
node_name=${self.name} \
bind_addr=${self.private_ip_address} \
cert_public_key="${module.generate-cert.cert_public_key}" \
cert_private_key="${module.generate-cert.cert_private_key}" \
ca_cert_pem="${module.generate-cert.ca_cert_pem}" \
'
EOF
  }



  tags = local.common_tags
}
