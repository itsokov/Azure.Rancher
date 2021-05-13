
resource "azurerm_resource_group" "RG" {
  name     = var.rg_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.nw_name
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
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