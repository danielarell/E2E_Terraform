# ─── ec2.tf ─────────────────────────────────────────────────────────────────
# Crea la instancia EC2 que:
#   1. Ejecuta bootstrap.sh al arrancar (via user_data)
#   2. Entrena el modelo y lo sube a S3
#   3. Lanza el servidor FastAPI en el puerto 8000

# ── Buscar la AMI más reciente de Amazon Linux 2023 ──────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Security Group ───────────────────────────────────────────────────────────
resource "aws_security_group" "mlops_sg" {
  name        = "mlops-housing-sg-${var.team_id}"
  description = "Permite trafico entrante a la API de inferencia y salida completa"

  # Puerto 8000: API de inferencia (FastAPI)
  ingress {
    description = "FastAPI inference endpoint"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_for_api]
  }

  # Puerto 22: SSH (opcional, sólo si se define un key pair)
  ingress {
    description = "SSH acceso administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restringir a tu IP en producción
  }

  # Egress: acceso completo a internet (necesario para instalar dependencias)
  egress {
    description = "Salida completa a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mlops-housing-sg-${var.team_id}"
  }
}

# ── User data: contenido de bootstrap.sh ─────────────────────────────────────
# templatefile() reemplaza las variables ${...} en el script antes de enviarlo.
locals {
  user_data_script = templatefile("${path.module}/../scripts/bootstrap.sh", {
    s3_bucket = local.bucket_name
    model_key = var.model_key
    aws_region = var.aws_region
  })
}

# ── Instancia EC2 ────────────────────────────────────────────────────────────
resource "aws_instance" "mlops_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.mlops_sg.id]

  # key_pair_name es opcional: si se deja vacío, no se asigna (sin SSH directo)
  key_name = var.key_pair_name != "" ? var.key_pair_name : null

  user_data                   = base64encode(local.user_data_script)
  user_data_replace_on_change = true  # Fuerza recrear la instancia si bootstrap.sh cambia

  # Habilitar metadata v2 (IMDSv2) — buena práctica de seguridad
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 20   # GB
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "mlops-housing-server-${var.team_id}"
  }
}
