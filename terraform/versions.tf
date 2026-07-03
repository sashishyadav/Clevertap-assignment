terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # In production, use a remote backend with state locking.
  # Left commented so the project can `init` locally out of the box.
  # backend "s3" {
  #   bucket         = "my-tfstate-bucket"
  #   key            = "engagement-platform/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}
