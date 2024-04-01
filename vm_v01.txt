resource "azurerm_resource_group" "aparito" {
  name     = "aparito-resources"
  location = "UK South"
}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.aparito.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_public_ip" "load_ip" {
  name                = "load_ip"
  resource_group_name = azurerm_resource_group.aparito.name
  location            = azurerm_resource_group.aparito.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = "Production"
  }
}
resource "azurerm_network_interface" "Nic_inter" {
  name                = "example-nic"
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
    //public_ip_address_id          = azurerm_public_ip.load_ip.id
  }
}
// load balancer
resource "azurerm_lb" "app_balancer" {
  name                = "app_balancer"
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }
  sku        = "Standard"
  depends_on = [azurerm_public_ip.load_ip]
}
//adding backend pool address for Load balancer
resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "PoolA"

  depends_on = [
    azurerm_lb.app_balancer
  ]
}
// adding lb-backend-address-pool-address
resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
  name                    = "appvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = "10.0.1.1"
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}
//ADDING health lb-probe
resource "azurerm_lb_probe" "ProbeA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "ProbeA"
  port            = 80
  depends_on = [
    azurerm_lb.app_balancer
  ]
}
//adding lb-rule
resource "azurerm_lb_rule" "RuleA" {
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.PoolA.id]
  probe_id                       = azurerm_lb_probe.ProbeA.id
  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_lb_probe.ProbeA
  ]
}

//adding inbound rules
resource "azurerm_network_security_group" "Sec-rule1" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["32700-32770", "80", "8080", "3000", "9090"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_linux_virtual_machine" "Demoapp" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.aparito.name
  location            = azurerm_resource_group.aparito.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.Nic_inter.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("vm.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}