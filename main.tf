terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "managed" {
  bucket = "eric-borba-state-ops-managed-bucket"

  tags = {
    Name      = "Managed Bucket"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket" "primary" {
  bucket = "eric-borba-state-ops-primary"

  tags = {
    Name = "Example 1"
  }
}

resource "aws_s3_bucket" "example2" {
  bucket = "eric-borba-state-ops-example2"

  tags = {
    Name = "Example 2"
  }
}

resource "aws_s3_bucket" "imported" {
  bucket = "eric-borba-state-ops-unmanaged"

  tags = {
    Name      = "Imported Bucket"
    ManagedBy = "Terraform"
  }
}
