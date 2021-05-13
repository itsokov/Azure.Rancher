

data "azurerm_virtual_network" "vnet" {
  name                = var.nw_name
  resource_group_name = data.azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "vaultsubnet1" {
  name                 = "vaultsubnet1"
  resource_group_name  = data.azurerm_resource_group.RG.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

}

resource "azurerm_network_interface" "nwinterface" {
  count               = 1
  name                = "vaultvm${count.index}-nic"
  location            = data.azurerm_resource_group.RG.location
  resource_group_name = data.azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vaultsubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vaultvm[count.index].id

  }
  tags = local.common_tags
}

resource "azurerm_network_security_group" "vaultNsg" {
  name                = "vaultNsg"
  location            = data.azurerm_resource_group.RG.location
  resource_group_name = data.azurerm_resource_group.RG.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Vault1"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Vault2"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8201"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Consul"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8500"
    source_address_prefix      = var.home_exernal_ip
    destination_address_prefix = "*"
  }
  tags = local.common_tags
}

resource "azurerm_public_ip" "vaultvm" {
  count               = 1
  name                = "vaultvm-${count.index}"
  resource_group_name = data.azurerm_resource_group.RG.name
  location            = data.azurerm_resource_group.RG.location
  allocation_method   = "Static"

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "nsgAssociation" {
  count                     = 1
  network_interface_id      = azurerm_network_interface.nwinterface[count.index].id
  network_security_group_id = azurerm_network_security_group.vaultNsg.id
}


output "public_ip_0" {
  value = azurerm_public_ip.vaultvm[0].ip_address
}
