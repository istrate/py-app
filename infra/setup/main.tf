# https://registry.terraform.io/providers/hashicorp/aws/latest/docs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.23.0"
    }
  }

  backend "s3" {
    bucket         = "devops-py-app"
    key            = "tf-state-setup"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "devops-py-app-tf-lock"
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      Envrionment = terraform.workspace
      Project     = var.project
      contact     = var.contact
      ManagedBy   = "Terraform/setup"
    }
  }

}