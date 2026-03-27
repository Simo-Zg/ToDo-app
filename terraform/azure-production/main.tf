terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.azure_region
}

resource "azurerm_service_plan" "plan" {
  name                = "tp-devsecops-prod-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      docker_image     = var.docker_image
      docker_image_tag = var.docker_image_tag
    }
  }

  app_settings = {
    WEBSITES_PORT = "3000"
    DOCKER_REGISTRY_SERVER_URL       = var.registry_url
    DOCKER_REGISTRY_SERVER_USERNAME  = var.registry_user
    DOCKER_REGISTRY_SERVER_PASSWORD  = var.registry_password
    MONGO_DB_URI                     = var.mongo_db_uri
    JWT_SECRET                       = var.jwt_secret
    JWT_REFRESH_SECRET               = var.jwt_refresh_secret
    SECRET_PASSWORD                  = var.secret_password
    AES_KEY                          = var.aes_key
  }
}