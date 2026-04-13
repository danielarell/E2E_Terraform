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
  default     = "mlops-lprpdi"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"  # Free tier eligible
}

variable "app_port" {
  description = "Puerto en el que FastAPI escucha dentro de la instancia EC2."
  type        = number
  default     = 8000
}

variable "allowed_cidr_for_api" {
  description = "CIDR que puede acceder al puerto 8000 de la API. Por defecto, abierto al mundo."
  type        = string
  default     = "0.0.0.0/0"
  # En producción, restringir a la IP del runner de GitHub Actions o a tu red.
}

variable "key_pair_name" {
  description = "Nombre del key pair de EC2 para acceso SSH (debe existir en tu cuenta de AWS)"
  type        = string
  default     = ""  # Si se deja vacío, no se asigna key pair (sin SSH)
}

variable "model_key" {
  description = "Clave (path) del modelo dentro del bucket S3"
  type        = string
  default     = "models/model.joblib"
}