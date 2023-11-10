terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
    }
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region  
  default_tags {
    tags = {
    Owner = var.resource_owner
    }
  }
}

provider "aws" {
  region = var.peered_vpc_region 
  alias = "peered" 
  default_tags {
    tags = {
    Owner = var.resource_owner
    }
  }
}

provider "databricks" {
  alias    = "mws"
  host     = "https://accounts.cloud.databricks.com"
  client_id     = var.client_id
  client_secret = var.client_secret
  account_id = var.databricks_account_id
  # auth_type = oauth-m2m
  # auth_type =  "basic"
}

provider "databricks" {
  alias    = "created_workspace"
  host     = module.databricks_mws_workspace.workspace_url
  client_id     = var.client_id
  client_secret = var.client_secret
  # account_id = var.databricks_account_id
  # auth_type = oauth-m2m
  # auth_type =  "basic"
}