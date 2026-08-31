terraform {
  required_version = ">= 1.7"

  # Each cluster gets its own state key so 50 clusters can apply concurrently in a CI
  # matrix without lock contention, e.g. key = "cost-analysis-export/clusters/${cluster_name}.tfstate"
  backend "azurerm" {}

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
  environment = var.azure_environment
  features {}
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}
