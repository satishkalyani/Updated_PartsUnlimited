terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.29.1"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tf-backends"
    storage_account_name = "azb23tfremotebackend"
    container_name       = "tfremotebackend"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  # Configuration options
  features {

  }
}
module "create-rg-01" {
  source       = "./modules/rg"
  rg_name      = var.rg_01_name
  rg_location  = var.rg_01_location
  tag_env_name = var.tag_env_name
}

resource "azurerm_virtual_network" "vnet-01" {
  name                = var.vnet_01_name
  address_space       = var.vnet_01_address_space
  location            = var.rg_01_location
  resource_group_name = var.rg_01_name
  depends_on = [
    module.create-rg-01
  ]
}

resource "azurerm_subnet" "subnet-01" {
  name                 = var.subnet_01_name
  resource_group_name  = var.rg_01_name
  virtual_network_name = var.vnet_01_name
  address_prefixes     = var.subnet_01_address_perfix
  depends_on = [
    module.create-rg-01
  ]
}

resource "azurerm_network_security_group" "nsg-01" {
  name                = var.nsg_01_name
  location            = var.rg_01_location
  resource_group_name = var.rg_01_name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [
    module.create-rg-01
  ]
}


resource "azurerm_subnet_network_security_group_association" "nsg-ass-01" {
  subnet_id                 = azurerm_subnet.subnet-01.id
  network_security_group_id = azurerm_network_security_group.nsg-01.id
}



resource "azurerm_network_interface" "nic-01" {
  name                = var.nic_01_name
  location            = var.rg_01_location
  resource_group_name = var.rg_01_name
  ip_configuration {
    name                          = "config01"
    private_ip_address            = var.private_ip_address
    subnet_id                     = azurerm_subnet.subnet-01.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm-01" {
  name                  = var.vm_01_name
  resource_group_name   = var.rg_01_name
  location              = var.rg_01_location
  size                  = "Standard_B1s"
  admin_username        = "kalyaniuser"
  admin_password        = "P@$$w0rd1234!"
  network_interface_ids = [azurerm_network_interface.nic-01.id]
  depends_on = [
    module.create-rg-01
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}
resource "azurerm_public_ip" "pip-01" {
  name                = var.pip_01_name
  resource_group_name = var.rg_01_name
  location            = var.rg_01_location
  allocation_method   = "Static"
  depends_on = [
    module.create-rg-01
  ]
  tags = {
    environment = var.tag_env_name
  }
}

resource "azurerm_service_plan" "asp-01" {
  name                = "my-webapps-01"
  resource_group_name = var.rg_01_name
  location            = var.rg_01_location
  sku_name            = "B1"
  os_type             = "Windows"

  depends_on = [
    module.create-rg-01
  ]
}

resource "azurerm_windows_web_app" "app-01" {
  name                = "my-win-app-01"
  resource_group_name = var.rg_01_name
  location            = var.rg_01_location
  service_plan_id     = azurerm_service_plan.asp-01.id

  depends_on = [
    module.create-rg-01
  ]
  site_config {}

  connection_string {
    name  = "Parts-database"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_mssql_database.sql-db-01.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_server.sql-server-01.name};Persist Security Info=False;User ID=${azurerm_mssql_server.sql-server-01.administrator_login};Password=${azurerm_mssql_server.sql-server-01.administrator_login_password};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}

resource "azurerm_mssql_server" "sql-server-01" {
  name                         = "mssql-server-01"
  resource_group_name          = var.rg_01_name
  location                     = var.rg_01_location
  version                      = "12.0"
  administrator_login          = "kalyani11"
  administrator_login_password = "satishadmin@16"
  minimum_tls_version          = "1.2"
  azuread_administrator {
    login_username = "kalyanisatish16@outlook.com"
    object_id      = "2406facc-ddce-4430-8265-017b1d18999d"
  }
  depends_on = [
    module.create-rg-01
  ]

  tags = {
    automation  = "terraform"
    environment = var.tag_env_name
  }
}

resource "azurerm_mssql_database" "sql-db-01" {
  name         = "mssql-db-01"
  server_id    = azurerm_mssql_server.sql-server-01.id
  license_type = "LicenseIncluded"
  max_size_gb  = 4
  sku_name     = "S0"


  depends_on = [
    module.create-rg-01
  ]
  tags = {
    automation  = "terraform"
    environment = var.tag_env_name
  }
}
