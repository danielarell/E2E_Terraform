# ─── iam.tf ─────────────────────────────────────────────────────────────────
# Crea el IAM Role que la instancia EC2 asumirá automáticamente.
# Esto permite que train.py y app.py accedan a S3 SIN credenciales hardcodeadas.

# ── Trust policy: sólo EC2 puede asumir este rol ────────────────────────────
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name               = "mlops-housing-ec2-role-${var.team_id}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  description = "Permite a EC2 leer y escribir el bucket de artefactos MLOps"
}

# ── Política inline: acceso específico al bucket del proyecto ────────────────
data "aws_iam_policy_document" "s3_access" {
  # Listar el contenido del bucket
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.model_artifacts.arn]
  }

  # Leer y escribir objetos (modelo, datos)
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.model_artifacts.arn}/*"]
  }
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name   = "mlops-housing-s3-policy"
  role   = aws_iam_role.ec2_s3_role.id
  policy = data.aws_iam_policy_document.s3_access.json
}

# ── Instance Profile: wrapper que asocia el role a la instancia EC2 ──────────
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "mlops-housing-instance-profile-${var.team_id}"
  role = aws_iam_role.ec2_s3_role.name
}
