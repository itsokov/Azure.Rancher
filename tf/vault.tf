module "create-vault" {
  source             = "./modules/vault"
  home_exernal_ip    = var.home_exernal_ip
  nw_name            = azurerm_virtual_network.vnet.name
  rg_name            = azurerm_resource_group.RG.name
  public_key_openssh = tls_private_key.ssh.public_key_openssh

  organization_name     = var.organization_name
  ca_common_name        = var.ca_common_name
  common_name           = var.common_name
  dns_names             = var.dns_names
  validity_period_hours = var.validity_period_hours

  depends_on = [
    azurerm_resource_group.RG,
    azurerm_virtual_network.vnet,
    tls_private_key.ssh,
  ]
}