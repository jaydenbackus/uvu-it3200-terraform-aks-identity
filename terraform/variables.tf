variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "student_name" {
  description = "Lowercase letters and digits only. Used in every resource name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,20}$", var.student_name))
    error_message = "student_name must be 2-20 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westus3"
}

variable "node_vm_size" {
  description = "VM size for the AKS node pool. Keep it small for the lab."
  type        = string
  default     = "Standard_D2s_v6"
}

variable "node_count" {
  description = "Number of AKS nodes."
  type        = number
  default     = 1
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Null uses the region default."
  type        = string
  default     = null
}

variable "app_namespace" {
  description = "Namespace the service principal may deploy into."
  type        = string
  default     = "it3200-lab"
}

variable "sp_secret_lifetime_days" {
  description = "Days before the service principal client secret expires."
  type        = number
  default     = 30
}

variable "admin_user_object_id" {
  description = "Object ID of your personal Entra user. Null uses the identity running Terraform."
  type        = string
  default     = null
}

# --- Toggles for the troubleshooting parts of the lab ---

variable "enable_kubelet_acr_pull" {
  description = "Grant AcrPull to the kubelet identity. Set false for the break/fix bonus."
  type        = bool
  default     = true
}

variable "grant_sp_cluster_access" {
  description = "Grant the service principal its AKS roles. Set false to reproduce the Forbidden error in Part 4."
  type        = bool
  default     = true
}

variable "grant_user_bootstrap_admin" {
  description = "Temporarily grant your personal user RBAC Cluster Admin to create the namespace. Turn off when done."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    course  = "IT3200"
    purpose = "aks-identity-lab"
  }
}
