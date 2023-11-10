variable "client_id" {
  type = string
  sensitive = true
}

variable "client_secret" {
  type = string
  sensitive = true
}

variable "databricks_account_id" {
  type = string
  sensitive = true
}

variable "resource_owner" {
  type = string
  sensitive = true
}

variable "vpc_cidr_range" {
  type = string
}

variable "private_subnets_cidr" {
  type = string
}

variable "privatelink_subnets_cidr" {
  type = string
}

variable "availability_zones" {
  type = string
}

variable "region" {
  type = string
}

variable "resource_prefix" {
  type = string
}

variable "workspace_vpce_service" {
  type = string
}

variable "relay_vpce_service" {
  type = string
}

variable "peered_vpc_region" {
  type = string
}

variable "peered_vpc_cidr_range" {
  type = string
}

variable "peer_vpc_subnets_cidr" {
  type = string
}

variable "peered_region_availability_zones" {
  type = string
}

variable "username" {
  type = string
}