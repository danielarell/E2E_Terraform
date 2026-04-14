# ─── main.tf ────────────────────────────────────────────────────────────────
# Configura el provider de AWS y el backend remoto (S3 + DynamoDB).
# El backend garantiza que todo el equipo comparta el mismo state.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "mlops-housing"
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}
