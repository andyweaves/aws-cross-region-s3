locals {
  prefix                       = var.resource_prefix
  owner                        = var.resource_owner
  vpc_cidr_range               = var.vpc_cidr_range
  private_subnets_cidr         = split(",", var.private_subnets_cidr)
  privatelink_subnets_cidr     = split(",", var.privatelink_subnets_cidr)
  sg_egress_ports              = [443, 3306, 6666]
  sg_ingress_protocol          = ["tcp", "udp"]
  sg_egress_protocol           = ["tcp", "udp"]
  availability_zones           = split(",", var.availability_zones)
  dbfsname                     = join("", [local.prefix, "-", var.region, "-", "dbfsroot"]) 
  uc_bucketname                = join("", [local.prefix, "-", var.region, "-", "unity-catalog"]) 
  cross_region_bucketname      = join("", [local.prefix, "-", var.peered_vpc_region]) 
  peer_vpc_subnets_cidr = split(",", var.peer_vpc_subnets_cidr) 
  peered_region_availability_zones = split(",", var.peered_region_availability_zones)
}

module "databricks_mws_workspace" {
  source = "./modules/databricks_workspace"
  providers = {
    databricks = databricks.mws
  }

  databricks_account_id  = var.databricks_account_id
  resource_prefix        = local.prefix
  security_group_ids     = [aws_security_group.sg.id]
  subnet_ids             = aws_subnet.private[*].id
  vpc_id                 = aws_vpc.dataplane_vpc.id
  cross_account_role_arn = aws_iam_role.cross_account_role.arn
  bucket_name            = aws_s3_bucket.root_storage_bucket.id
  region                 = var.region
  backend_rest           = aws_vpc_endpoint.backend_rest.id
  backend_relay          = aws_vpc_endpoint.backend_relay.id
  depends_on = [aws_iam_instance_profile.s3_instance_profile]
}

// create PAT token to provision entities within workspace
resource "databricks_token" "pat" {
  provider         = databricks.created_workspace
  comment          = "Terraform Provisioning"
  lifetime_seconds = 86400
}

resource "databricks_instance_profile" "instance_profile" {
  provider = databricks.created_workspace
  depends_on = [module.databricks_mws_workspace]
  instance_profile_arn = aws_iam_instance_profile.s3_instance_profile.arn
}

resource "databricks_group" "data_engineers" {
  provider = databricks.created_workspace
  depends_on = [module.databricks_mws_workspace]
  display_name = "data_engineers"
}

resource "databricks_group_role" "my_group_instance_profile" {
  provider = databricks.created_workspace
  depends_on = [module.databricks_mws_workspace]
  group_id = databricks_group.data_engineers.id
  role     = databricks_instance_profile.instance_profile.id
}

resource "databricks_notebook" "test_notebook" {
  provider = databricks.created_workspace
  depends_on = [module.databricks_mws_workspace]
  source = "resources/test_notebook.py"
  path   = "/Shared/test_notebook.py"
}

data "databricks_group" "admins" {
  provider = databricks.created_workspace
  display_name = "admins"
}

resource "databricks_user" "me" {
  provider = databricks.created_workspace
  user_name = var.username
}

resource "databricks_group_member" "admins" {
  provider = databricks.created_workspace
  group_id  = data.databricks_group.admins.id
  member_id = databricks_user.me.id
}