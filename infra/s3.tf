# ─── s3.tf ──────────────────────────────────────────────────────────────────
# Crea el bucket S3 donde se almacenarán:
#   - models/model.joblib   → artefacto del modelo entrenado
#   - data/                 → datos crudos (opcional)

locals {
  bucket_name = "mlops-housing-${var.team_id}"
}

resource "aws_s3_bucket" "model_artifacts" {
  bucket        = local.bucket_name
  force_destroy = true  # Permite destruir el bucket aunque tenga objetos (útil en labs)

  lifecycle {
    prevent_destroy = false
  }
}

# Versionado: guarda historial de model.joblib ante reentrenamientos
resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.model_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bloqueo de acceso público (el modelo no debe ser público)
resource "aws_s3_bucket_public_access_block" "artifacts_pab" {
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado en reposo con clave gestionada por AWS
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_sse" {
  bucket = aws_s3_bucket.model_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
