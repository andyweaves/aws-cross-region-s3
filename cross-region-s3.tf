resource "aws_s3_bucket" "cross_region_bucket" {
  provider = aws.peered
  bucket = local.cross_region_bucketname
  acl    = "private"
  force_destroy = true
  tags = {
    Name = local.cross_region_bucketname
  }
}

resource "aws_s3_bucket_versioning" "cross_region_versioning" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cross_region_bucket" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cross_region_bucket" {
  provider = aws.peered
  bucket                  = aws_s3_bucket.cross_region_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.cross_region_bucket]
}

data "databricks_aws_bucket_policy" "cross_region_bucket" {
  #provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.bucket
}

resource "aws_s3_object" "red_wine" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.id
  key    = "wine_quality/winequality-red.csv"
  source = "resources/winequality-red.csv"
}

resource "aws_s3_object" "white_wine" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.id
  key    = "wine_quality/winequality-white.csv"
  source = "resources/winequality-white.csv"
}

resource "aws_s3_object" "ext_red_wine" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.id
  key    = "unity_catalog/external_location/winequality-red.csv"
  source = "resources/winequality-red.csv"
}

resource "aws_s3_object" "ext_wrhite_wine" {
  provider = aws.peered
  bucket = aws_s3_bucket.cross_region_bucket.id
  key    = "unity_catalog/external_location/winequality-white.csv"
  source = "resources/winequality-white.csv"
}

# resource "aws_s3_bucket_policy" "cross_region_bucket" {
#   provider = aws.peered
#   bucket     = aws_s3_bucket.cross_region_bucket.id
#   policy     = data.databricks_aws_bucket_policy.cross_region_bucket.json
#   depends_on = [aws_s3_bucket_public_access_block.cross_region_bucket]
# }