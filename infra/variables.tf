# ─── variables.tf ───────────────────────────────────────────────────────────
# Define todas las variables configurables del proyecto.

variable "aws_region" {
  description = "Región de AWS donde se crearán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "team_id" {
  description = "Identificador único del equipo (se usa en nombres de recursos para evitar colisiones)"
  type        = string
  default     = "mlops_lprpdi"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"  # Free tier eligible
}