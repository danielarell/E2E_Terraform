# ─── s3_objects.tf ──────────────────────────────────────────────────────────
# Sube los archivos del código fuente al bucket S3.
# Se ejecutan ANTES de crear la instancia EC2 (garantizado por depends_on).

# Sube train.py
resource "aws_s3_object" "train_py" {
  bucket = aws_s3_bucket.model_artifacts.id
  key    = "src/train.py"
  source = "${path.module}/../src/train.py"

  # Detectar cambios en el archivo local
  etag = filemd5("${path.module}/../src/train.py")
}

# Sube app.py
resource "aws_s3_object" "app_py" {
  bucket = aws_s3_bucket.model_artifacts.id
  key    = "src/app.py"
  source = "${path.module}/../src/app.py"

  # Detectar cambios en el archivo local
  etag = filemd5("${path.module}/../src/app.py")
}
