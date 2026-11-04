locals {
  namespace_scope = "${azurerm_kubernetes_cluster.aks.id}/namespaces/${var.app_namespace}"
}

# ---------------------------------------------------------------------------
# Image pulls: kubelet managed identity -> ACR
# ---------------------------------------------------------------------------

# Nodes pull images as the kubelet identity, not the cluster identity and not
# the service principal. AcrPull lets it read images and nothing more.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.enable_kubelet_acr_pull ? 1 : 0

  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# Service principal -> AKS
# ---------------------------------------------------------------------------

# Lets the SP download the user kubeconfig (listClusterUserCredential).
# Grants no rights inside Kubernetes.
resource "azurerm_role_assignment" "sp_cluster_user" {
  count = var.grant_sp_cluster_access ? 1 : 0

  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
}

# Read-only view of workloads across the cluster.
resource "azurerm_role_assignment" "sp_rbac_reader" {
  count = var.grant_sp_cluster_access ? 1 : 0

  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
}

# Create and update Deployments, Services, and Pods, but only in the lab namespace.
resource "azurerm_role_assignment" "sp_rbac_writer_ns" {
  count = var.grant_sp_cluster_access ? 1 : 0

  scope                = local.namespace_scope
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = azuread_service_principal.deployer.object_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Personal user -> AKS (comparison identity for Part 6)
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "user_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = local.user_object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "user_rbac_reader" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = local.user_object_id
  principal_type       = "User"
}

# Temporary, documented bootstrap role. Namespace-scoped roles cannot create the
# namespace itself, so an operator needs cluster-level rights once. Turn this off
# (grant_user_bootstrap_admin = false) right after creating the namespace.
resource "azurerm_role_assignment" "user_bootstrap_admin" {
  count = var.grant_user_bootstrap_admin ? 1 : 0

  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = local.user_object_id
  principal_type       = "User"
}
