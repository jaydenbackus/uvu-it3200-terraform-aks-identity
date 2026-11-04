output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "tenant_id" {
  value = local.tenant_id
}

output "sp_client_id" {
  description = "Application (client) ID of the deployer service principal."
  value       = azuread_application.deployer.client_id
}

output "sp_object_id" {
  description = "Object ID of the deployer service principal (the role assignment target)."
  value       = azuread_service_principal.deployer.object_id
}

output "cluster_identity_principal_id" {
  value = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "kubelet_identity_client_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
}

output "app_namespace" {
  value = var.app_namespace
}

# Read with: terraform output -raw sp_client_secret
# Never paste it into docs, screenshots, or commits.
output "sp_client_secret" {
  value     = azuread_application_password.deployer.value
  sensitive = true
}
