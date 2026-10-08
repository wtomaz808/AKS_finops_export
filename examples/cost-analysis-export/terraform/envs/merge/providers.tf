terraform {
  required_version = ">= 1.7"

  # Local backend for this POC - use an azurerm backend for the customer rollout.
  backend "local" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "azurerm" {
  environment     = var.azure_environment
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  features {}
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}
