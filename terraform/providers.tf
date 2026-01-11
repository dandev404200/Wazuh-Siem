terraform {
  required_version = ">= 1.6" # OpenTofu compatible

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Note: Run with `tofu init`, `tofu plan`, `tofu apply`

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "wazuh-siem"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
