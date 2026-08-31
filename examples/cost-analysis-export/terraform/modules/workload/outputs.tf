output "namespace" {
  value = var.namespace
}

output "cron_job_name" {
  value = kubernetes_cron_job_v1.this.metadata[0].name
}

output "aks_data_prefix" {
  value = local.aks_data_prefix
}
