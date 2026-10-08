terraform {
  required_version = ">= 1.7"

  # Local backend for this POC - state isn't shared across operators/CI here.
  # For the customer rollout, switch to an azurerm backend (see backend.hcl.example)
  # so shared state is available to the per-cluster CI matrix jobs.
  backend "local" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.15"
    }
  }
}

provider "azurerm" {
  environment     = var.azure_environment
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  features {}

  # Entra auth for blob container operations; needed when shared key access is disabled.
  storage_use_azuread = var.storage_use_azuread
}

provider "azapi" {
  environment     = var.azure_environment
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
