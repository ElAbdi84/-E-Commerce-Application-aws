# terraform/s3.tf

resource "aws_s3_bucket" "products" {
  bucket = var.s3_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name = var.s3_bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "products" {
  bucket = aws_s3_bucket.products.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "products" {
  bucket = aws_s3_bucket.products.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "products" {
  bucket = aws_s3_bucket.products.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}