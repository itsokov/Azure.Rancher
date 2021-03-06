
resource "azurerm_resource_group" "RG" {
  name     = var.rg_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_linux_virtual_machine" "ranchervm0" {
  name                = "${var.ranchervm}0"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = var.vm_size
  admin_username      = "rancheradmin"
  network_interface_ids = [
    azurerm_network_interface.nwinterface[0].id,
  ]

  admin_ssh_key {
    username   = "rancheradmin"
    public_key = tls_private_key.ssh.public_key_openssh
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
&& az vm wait -g "${azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.ranchervm0.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& az vm wait -g "${azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.ranchervm1.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& az vm wait -g "${azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.ranchervm2.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& sleep 60 \
&& ansible-playbook -i "${self.public_ip_address},"  \
../ansible/playbook.yaml \
--extra-vars ' \
cert_public_key="${module.generate-cert.cert_public_key}" \
cert_private_key="${module.generate-cert.cert_private_key}" \
ca_cert_pem="${module.generate-cert.ca_cert_pem}" \
hostname="${var.common_name}" \
rancher1IP="${azurerm_linux_virtual_machine.ranchervm0.private_ip_address}" \
rancher2IP="${azurerm_linux_virtual_machine.ranchervm1.private_ip_address}" \
rancher3IP="${azurerm_linux_virtual_machine.ranchervm2.private_ip_address}" \ 
'
EOF
  }


  tags = local.common_tags

  depends_on = [
    azurerm_linux_virtual_machine.ranchervm1,
    azurerm_linux_virtual_machine.ranchervm2
  ]
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "null_resource" "ssh_keypair" {


  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh.private_key_pem}\" > ~/.ssh/id_rsa; chmod 400 ~/.ssh/id_rsa"
  }
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh.public_key_pem}\" > ~/.ssh/id_rsa.pub; chmod 400 ~/.ssh/id_rsa.pub"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ~/.ssh/id_rsa"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ~/.ssh/id_rsa.pub"
  }
}

resource "azurerm_linux_virtual_machine" "ranchervm1" {
  name                = "${var.ranchervm}1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = var.vm_size
  admin_username      = "rancheradmin"
  network_interface_ids = [
    azurerm_network_interface.nwinterface[1].id,
  ]

  admin_ssh_key {
    username   = "rancheradmin"
    public_key = tls_private_key.ssh.public_key_openssh
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
&& az vm wait -g "${azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.ranchervm1.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& sleep 60 \
&& ansible-playbook -i "${self.public_ip_address},"  \
../ansible/playbook_rancher23.yaml
EOF
  }

  tags = local.common_tags
}

resource "azurerm_linux_virtual_machine" "ranchervm2" {
  name                = "${var.ranchervm}2"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = var.vm_size
  admin_username      = "rancheradmin"
  network_interface_ids = [
    azurerm_network_interface.nwinterface[2].id,
  ]

  admin_ssh_key {
    username   = "rancheradmin"
    public_key = tls_private_key.ssh.public_key_openssh
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
&& az vm wait -g "${azurerm_resource_group.RG.name}" -n "${azurerm_linux_virtual_machine.ranchervm2.name}" --custom "instanceView.statuses[?code=='PowerState/running']" \
&& sleep 60 \
&& ansible-playbook -i "${self.public_ip_address},"  \
../ansible/playbook_rancher23.yaml
EOF
  }
  tags = local.common_tags
}


### sort out these storage accounts that get created NetworkWatcherRG DefaultResourceGroup-WEU with LogAnalytics workspace
### find a way to replace sleep 60 with a real check