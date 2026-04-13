# ─── outputs.tf ─────────────────────────────────────────────────────────────
# Expone valores útiles después de un `terraform apply`.
# GitHub Actions los captura con: terraform output -raw ec2_public_ip

output "ec2_public_ip" {
  description = "IP pública de la instancia EC2 donde corre la API"
  value       = aws_instance.mlops_server.public_ip
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 (útil para SSH o logs en CloudWatch)"
  value       = aws_instance.mlops_server.id
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se almacena el modelo"
  value       = aws_s3_bucket.model_artifacts.bucket
}

output "api_health_url" {
  description = "URL completa del endpoint de salud"
  value       = "http://${aws_instance.mlops_server.public_ip}:8000/health"
}

output "api_predict_url" {
  description = "URL completa del endpoint de predicción"
  value       = "http://${aws_instance.mlops_server.public_ip}:8000/predict"
}

output "ami_used" {
  description = "AMI que se usó para crear la instancia"
  value       = data.aws_ami.amazon_linux_2023.id
}
