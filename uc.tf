resource "aws_s3_bucket" "unity_catalog" {
  bucket = local.uc_bucketname
  acl    = "private"
  versioning {
    enabled = true
  }
  force_destroy = true
  tags = {
    Name = local.uc_bucketname
  }
}

resource "aws_s3_bucket_public_access_block" "unity_catalog" {
  bucket                  = aws_s3_bucket.unity_catalog.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.unity_catalog]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unity_catalog" {
  bucket = aws_s3_bucket.unity_catalog.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "passrole_for_uc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-unity-catalog"]
    }
  }
}

resource "aws_iam_policy" "unity_metastore" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ],
        "Resource" : [
          aws_s3_bucket.unity_catalog.arn,
          "${aws_s3_bucket.unity_catalog.arn}/*"
        ],
        "Effect" : "Allow"
      },
    ]
  })
  tags = {
    Name = "${local.prefix} UC policy"
    Owner = var.resource_owner
  }
}

resource "aws_iam_policy" "sample_data" {
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.prefix}-databricks-sample-data"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          "arn:aws:s3:::databricks-datasets-oregon/*",
          "arn:aws:s3:::databricks-datasets-oregon"

        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = {
    Name = "${local.prefix} UC policy"
    Owner = var.resource_owner
  }
}

resource "aws_iam_role" "metastore_data_access" {
  name                = "${local.prefix}-unity-catalog"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.unity_metastore.arn, aws_iam_policy.sample_data.arn]
  tags = {
    Name = "${local.prefix} UC policy"
    Owner = var.resource_owner
  }
}

resource "databricks_metastore" "unity_catalog" {
  provider = databricks.created_workspace
  name          = "${local.prefix}-${var.region}"
  storage_root  = "s3://${aws_s3_bucket.unity_catalog.id}/managed"
  owner         = var.databricks_account_username
  region = var.region
  force_destroy = true
}

resource "databricks_metastore_data_access" "this" {

  provider = databricks.created_workspace
  metastore_id = databricks_metastore.unity_catalog.id
  name         = aws_iam_role.metastore_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.metastore_data_access.arn
  }
  is_default = true
  depends_on = [ databricks_metastore_assignment.unity_catalog ]
}

resource "databricks_metastore_assignment" "unity_catalog" {
  provider             = databricks.created_workspace
  workspace_id         = module.databricks_mws_workspace.workspace_id
  metastore_id         = databricks_metastore.unity_catalog.id
  default_catalog_name = "main"
  #default_catalog_name = "hive_metastore"
}

data "aws_iam_policy_document" "storage_creds" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-${var.peered_vpc_region}"]
    }
  }
}

resource "aws_iam_policy" "external_location" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ],
        "Resource" : [
          aws_s3_bucket.cross_region_bucket.arn,
          "${aws_s3_bucket.cross_region_bucket.arn}/*"
        ],
        "Effect" : "Allow"
      },
    ]
  })
  tags = {
    Name = "${local.prefix} external location policy"
    Owner = var.resource_owner
  }
}

resource "aws_iam_role" "storage_credentials" {
  name                = "${local.prefix}-${var.peered_vpc_region}"
  assume_role_policy  = data.aws_iam_policy_document.storage_creds.json
  managed_policy_arns = [aws_iam_policy.external_location.arn]
  tags = {
    Name = "${local.prefix} external location policy"
    Owner = var.resource_owner
  }
  depends_on = [ databricks_metastore_assignment.unity_catalog ]
}

resource "databricks_storage_credential" "external" {
  provider             = databricks.created_workspace
  name = aws_iam_role.storage_credentials.name
  aws_iam_role {
    role_arn = aws_iam_role.storage_credentials.arn
  }
  comment = "Managed by TF"
}

resource "databricks_external_location" "some" {

  provider             = databricks.created_workspace
  name            = var.peered_vpc_region
  url             = "s3://${aws_s3_bucket.cross_region_bucket.id}/unity_catalog/external_location/"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
}