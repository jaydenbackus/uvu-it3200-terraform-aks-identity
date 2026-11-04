data "azurerm_client_config" "current" {}

locals {
  suffix   = "uvu-it3200-${var.student_name}"
  rg_name  = "rg-${local.suffix}"
  aks_name = "aks-${local.suffix}"
  acr_name = "acruvuit3200${var.student_name}" # ACR allows only letters and digits

  tenant_id = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_resource_group" "lab" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Private registry: anonymous pull and the admin account stay off,
# so every pull and push must use an Entra identity with an RBAC role.
resource "azurerm_container_registry" "acr" {
  name                   = local.acr_name
  resource_group_name    = azurerm_resource_group.lab.name
  location               = azurerm_resource_group.lab.location
  sku                    = "Basic"
  admin_enabled          = false
  anonymous_pull_enabled = false
  tags                   = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  dns_prefix          = local.aks_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    node_count                  = var.node_count
    temporary_name_for_rotation = "systemtmp"

    # Match the AKS defaults so plans stay clean.
    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Cluster (control plane) identity. AKS also creates a separate
  # kubelet identity for the nodes; see rbac.tf.
  identity {
    type = "SystemAssigned"
  }

  # Entra ID sign-in plus Azure RBAC for Kubernetes authorization:
  # Azure role assignments decide what each identity may do inside the cluster.
  azure_active_directory_role_based_access_control {
    tenant_id          = local.tenant_id
    azure_rbac_enabled = true
  }

  # No static admin kubeconfig. Everyone must sign in through Entra ID.
  local_account_disabled = true

  network_profile {
    network_plugin = "azure"
  }

  tags = var.tags
}
