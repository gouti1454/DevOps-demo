resource "azurerm_resource_group" "aparito" {
  name     = "aparito-resources"
  location = "UK South"
}
//Virtual n/w
resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name
}
//subnet
resource "azurerm_subnet" "SubnetA" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.aparito.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.2.0/24"]
}



//declaring public ip name
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
// declaring private ip and  commenting the public address since adding front end ip address
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
  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}


//adding nsg group :: Network security group example-nsg-1 (attached to subnet: internal)
resource "azurerm_network_security_group" "NSG-example" {
  name                = "example-nsg-1"
  location            = azurerm_resource_group.aparito.location
  resource_group_name = azurerm_resource_group.aparito.name

  security_rule {
    name                       = "portssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "port3000"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "NSG-subnet-example" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.NSG-example.id
}

// Ending nsg group : Network security group example-nsg-1 (attached to subnet: internal)

//adding nsg group associ with Network interface
resource "azurerm_network_interface_security_group_association" "NSG-NIC-example" {
  network_interface_id      = azurerm_network_interface.Nic_inter.id
  network_security_group_id = azurerm_network_security_group.NSG-example.id
}
//ending - nsg group associ with Network interface




// declaring load balancer
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
//adding backend pool address name
resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "PoolA"

  depends_on = [
    azurerm_lb.app_balancer
  ]
}
// adding lb-backend-address-pool : ip address
resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
  name                    = "appvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  //ip_address              = "10.0.1.1"
  ip_address = azurerm_network_interface.Nic_inter.private_ip_address
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


//virtual machine example-machine
resource "azurerm_linux_virtual_machine" "example-machine" {
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


//# Adding NAT rules for the load balancer and mapping backend pool: ssh22 port

/*
resource "azurerm_lb_nat_rule" "inbound_rule_22" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-22"
  protocol                       = "Tcp"
  frontend_port_start            = 22
  frontend_port_end              = 22
  backend_port                   = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id
  frontend_ip_configuration_name = "frontend-ip"
  enable_floating_ip             = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}
*/


//# Adding more NAT rules : for the  load balancer and mapping backend pool::  for other ports
//NAT rule for  cadvisor 8080

/*
resource "azurerm_lb_nat_rule" "inbound_rule_8080" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-8080"
  protocol                       = "Tcp"
  frontend_port_start            = 8080
  frontend_port_end              = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id

  enable_floating_ip = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}
*/

//NAT rule for  prometheus 9090
resource "azurerm_lb_nat_rule" "inbound_rule_9090" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-9090"
  protocol                       = "Tcp"
  frontend_port_start            = 9090
  frontend_port_end              = 9090
  backend_port                   = 9090
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id

  enable_floating_ip = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}

//NAT rule for Docker 8000
resource "azurerm_lb_nat_rule" "inbound_rule_8000" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-8000"
  protocol                       = "Tcp"
  frontend_port_start            = 8000
  frontend_port_end              = 8000
  backend_port                   = 8000
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id

  enable_floating_ip = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}


//NAT rule for Docker instance1
resource "azurerm_lb_nat_rule" "inbound_rule_32770" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-32770"
  protocol                       = "Tcp"
  frontend_port_start            = 32770
  frontend_port_end              = 32770
  backend_port                   = 32770
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id
  enable_floating_ip             = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}

//NAT rule for Docker instance2
resource "azurerm_lb_nat_rule" "inbound_rule_32771" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-32771"
  protocol                       = "Tcp"
  frontend_port_start            = 32771
  frontend_port_end              = 32771
  backend_port                   = 32771
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id
  enable_floating_ip             = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}

//NAT rule for Docker instance2
resource "azurerm_lb_nat_rule" "inbound_rule_32772" {
  resource_group_name            = azurerm_resource_group.aparito.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "inbound-rule-32772"
  protocol                       = "Tcp"
  frontend_port_start            = 32772
  frontend_port_end              = 32772
  backend_port                   = 32772
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.PoolA.id
  enable_floating_ip             = false

  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_linux_virtual_machine.example-machine
  ]
}