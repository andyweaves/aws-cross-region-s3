# a walkaround using sleep to wait for role to be created
resource "time_sleep" "wait" {
  create_duration = "20s"
}

resource "databricks_mws_credentials" "this" {
  account_id       = var.databricks_account_id
  role_arn         = var.cross_account_role_arn
  credentials_name = "${var.resource_prefix}-cr-credentials"
  depends_on       = [time_sleep.wait]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  bucket_name                = var.bucket_name
  storage_configuration_name = "${var.resource_prefix}-storage"
}

resource "databricks_mws_vpc_endpoint" "backend_rest" {
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = var.backend_rest
  vpc_endpoint_name   = "${var.resource_prefix}-vpce-backend-${var.vpc_id}"
  region              = var.region
}

resource "databricks_mws_vpc_endpoint" "backend_relay" {
  account_id          = var.databricks_account_id
  aws_vpc_endpoint_id = var.backend_relay
  vpc_endpoint_name   = "${var.resource_prefix}-vpce-relay-${var.vpc_id}"
  region              = var.region
}

resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "${var.resource_prefix}-network"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.subnet_ids
  vpc_id             = var.vpc_id
  vpc_endpoints {
    dataplane_relay = [databricks_mws_vpc_endpoint.backend_relay.vpc_endpoint_id]
    rest_api        = [databricks_mws_vpc_endpoint.backend_rest.vpc_endpoint_id]
  }
}

resource "databricks_mws_private_access_settings" "pas" {
  account_id                   = var.databricks_account_id
  private_access_settings_name = "Private Access Settings for ${var.resource_prefix}"
  region                       = var.region
  public_access_enabled        = true
  private_access_level         = "ACCOUNT"
}

resource "databricks_mws_workspaces" "this" {
  account_id      = var.databricks_account_id
  aws_region      = var.region
  workspace_name  = var.resource_prefix
  #deployment_name = var.resource_prefix
  credentials_id                           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id                 = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id                               = databricks_mws_networks.this.network_id
  # storage_customer_managed_key_id          = databricks_mws_customer_managed_keys.workspace_storage.customer_managed_key_id
  # managed_services_customer_managed_key_id = databricks_mws_customer_managed_keys.managed_services.customer_managed_key_id
  private_access_settings_id               = databricks_mws_private_access_settings.pas.private_access_settings_id
  pricing_tier                             = "ENTERPRISE"
  depends_on                               = [databricks_mws_networks.this]
}