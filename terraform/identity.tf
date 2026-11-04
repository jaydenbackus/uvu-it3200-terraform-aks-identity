data "azuread_client_config" "current" {}

locals {
  user_object_id = coalesce(var.admin_user_object_id, data.azuread_client_config.current.object_id)
}

# Application registration: the definition of the app identity.
resource "azuread_application" "deployer" {
  display_name = "sp-${local.suffix}-deployer"
  owners       = [data.azuread_client_config.current.object_id]
}

# Service principal: the app's instance in this tenant. Role assignments target this.
resource "azuread_service_principal" "deployer" {
  client_id = azuread_application.deployer.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Short-lived client secret. Terraform stores it in state, so keep state out of Git.
resource "time_rotating" "sp_secret" {
  rotation_days = var.sp_secret_lifetime_days
}

resource "azuread_application_password" "deployer" {
  application_id = azuread_application.deployer.id
  display_name   = "lab-secret"
  end_date       = time_rotating.sp_secret.rotation_rfc3339
}
