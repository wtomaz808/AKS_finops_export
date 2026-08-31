terraform {
  required_version = ">= 1.7"

  # Populate via `terraform init -backend-config=backend.hcl` (see backend.hcl.example).
  # Local backend only works for a single-operator POC - use azurerm backend for the
  # customer rollout so shared state is available to the per-cluster CI matrix jobs.
  backend "azurerm" {}

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
