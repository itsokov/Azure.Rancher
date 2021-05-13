data "azurerm_virtual_network" "vnet" {
  name                = var.nw_name
  resource_group_name = data.azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = data.azurerm_resource_group.RG.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_network_interface" "nwinterface" {
  count               = 3
  name                = "ranchervm${count.index}-nic"
  location            = data.azurerm_resource_group.RG.location
  resource_group_name = data.azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ranchervm[count.index].id

  }
  tags = local.common_tags
}

resource "azurerm_network_security_group" "rancherNsg" {
  name                = "rancherNsg"
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

  tags = local.common_tags
}

resource "azurerm_public_ip" "ranchervm" {
  count               = 3
  name                = "ranchervm-${count.index}"
  resource_group_name = data.azurerm_resource_group.RG.name
  location            = data.azurerm_resource_group.RG.location
  allocation_method   = "Static"

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "nsgAssociation" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nwinterface[count.index].id
  network_security_group_id = azurerm_network_security_group.rancherNsg.id
}


output "public_ip_0" {
  value = azurerm_public_ip.ranchervm[0].ip_address
}

output "public_ip_1" {
  value = azurerm_public_ip.ranchervm[1].ip_address
}

output "public_ip_2" {
  value = azurerm_public_ip.ranchervm[2].ip_address
}