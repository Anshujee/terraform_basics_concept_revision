terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.4.0"
    }
  }
  # backend "azurerm" {
  #   resource_group_name = "Test1"
  #   storage_account_name = "mystorageanshujee123"
  #   container_name = "tfstate"
  #   key = "dev.terraform.tfstate"
  # }
}

provider "azurerm" {
  # Configuration options
  features {}
}

resource "azurerm_resource_group" "RG1" {
  name     = "Test1"
  location = "Central India"
}

# Concept of Dependency in Terraform. So we have two types of dependency
# 1 ) Implicit Dependency. -- We use this dependency inside the code ex - resource_group_name = azurerm_resource_group.RG1.name and location = azurerm_resource_group.RG1.location
# resource "azurerm_storage_account" "tfstate" {
#   name                     = "mystorageanshujee123"
#   resource_group_name      = azurerm_resource_group.RG1.name     # Implicit dependency on the resource group name.
#   location                 = azurerm_resource_group.RG1.location # Implicit dependency on the resource group location.
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# 2 ) Explicit Dependency through Terraform - We use this when there's no attribute reference to infer the order from. So for that we are using the depends_on keyword.
resource "azurerm_storage_account" "tfstate" {

  depends_on               = [azurerm_resource_group.RG1] # Explicit dependency on the resource group.
  name                     = "mystorageanshujee123"
  resource_group_name      = "Test1"         # Hardcoded value, not a reference - this is why depends_on is needed above.
  location                 = "Central India" # Hardcoded value, not a reference - this is why depends_on is needed above.
  account_tier             = "Standard"
  account_replication_type = "LRS"

}
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
 