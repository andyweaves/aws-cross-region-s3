// Cross Account Role
data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "cross_account_role" {
  name               = "${local.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags = {
    Name = "${local.prefix}-crossaccount-role"
  }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${local.prefix}-crossaccount-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "Stmt1403287045000",
            "Effect": "Allow",
            "Action": [
        "ec2:AssociateIamInstanceProfile",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CancelSpotInstanceRequests",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeIamInstanceProfileAssociations",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeInstances",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeNatGateways",
        "ec2:DescribeNetworkAcls",
        "ec2:DescribePrefixLists",
        "ec2:DescribeReservedInstancesOfferings",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSpotInstanceRequests",
        "ec2:DescribeSpotPriceHistory",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeVpcs",
        "ec2:DetachVolume",
        "ec2:DisassociateIamInstanceProfile",
        "ec2:ReplaceIamInstanceProfileAssociation",
        "ec2:RequestSpotInstances",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeFleetHistory",
        "ec2:ModifyFleet",
        "ec2:DeleteFleets",
        "ec2:DescribeFleetInstances",
        "ec2:DescribeFleets",
        "ec2:CreateFleet",
        "ec2:DeleteLaunchTemplate",
        "ec2:GetLaunchTemplateData",
        "ec2:CreateLaunchTemplate",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:ModifyLaunchTemplate",
        "ec2:DeleteLaunchTemplateVersions",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:AssignPrivateIpAddresses",
        "ec2:GetSpotPlacementScores"
        ],
          "Resource": ["*"]
        },
        {
          "Effect": "Allow",
          "Action": [
            "iam:CreateServiceLinkedRole",
            "iam:PutRolePolicy"
          ],
          "Resource": "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot",
          "Condition": {
            "StringLike": {
              "iam:AWSServiceName": "spot.amazonaws.com"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": "iam:PassRole",
          "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-s3-instance-profile"
        }
      ]
    }
  )
}

// Instance Profile
resource "aws_iam_role" "s3_instance_profile" {
  name = "${local.prefix}-s3-instance-profile"
  description        = "Role for S3 access"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
    tags = {
    Name = "${local.prefix}-s3-instance-profile"
  }
}

resource "aws_iam_role_policy" "s3_instance-profile" {
  name   = "${local.prefix}-s3-instance-profile-policy"
  role   = aws_iam_role.s3_instance_profile.id
  depends_on              = [aws_s3_bucket.root_storage_bucket] 
  policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
          {
                "Sid": "GrantCatalogAccessToGlue",
                "Effect": "Allow",
                "Action": [
                    "glue:*"
                ],
                "Resource": [
                    "*"
                ]
            },
            {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${local.dbfsname}",
                "arn:aws:s3:::${local.cross_region_bucketname}"
            ]
            },
            {
            "Effect": "Allow",
            "Action": [
                "s3:*Object",
            ],
            "Resource": [
                "arn:aws:s3:::${local.dbfsname}/*",
                "arn:aws:s3:::${local.cross_region_bucketname}/*"
            ]
            }
        ]
        }
  )
}

resource "aws_iam_instance_profile" "s3_instance_profile" {
  name = "${local.prefix}-s3-instance-profile"
  role = aws_iam_role.s3_instance_profile.name
}