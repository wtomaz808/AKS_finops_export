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
  environment = var.azure_environment
  features {}
}

provider "azapi" {
  environment = var.azure_environment
}
