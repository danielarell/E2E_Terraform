#!/bin/bash
# ─── bootstrap.sh ────────────────────────────────────────────────────────────
# Script de arranque (user_data) de la instancia EC2.
# Se ejecuta UNA VEZ como root cuando la instancia inicia por primera vez.
#
# Flujo:
#   1. Actualizar el sistema e instalar Python 3.11
#   2. Instalar dependencias del proyecto
#   3. Copiar el código fuente desde el repo (o usar el incrustado por Terraform)
#   4. Ejecutar train.py → genera y sube model.joblib a S3
#   5. Lanzar uvicorn con app.py en el puerto 8000
##!/bin/bash
# ─── bootstrap.sh ────────────────────────────────────────────────────────────
# Script de arranque (user_data) de la instancia EC2.
# Se ejecuta UNA VEZ como root cuando la instancia inicia por primera vez.
#
# Flujo:
#   1. Actualizar el sistema e instalar Python 3.11
#   2. Instalar dependencias del proyecto
#   3. Copiar el código fuente desde el repo (o usar el incrustado por Terraform)
#   4. Ejecutar train.py → genera y sube model.joblib a S3
#   5. Lanzar uvicorn con app.py en el puerto 8000
#
# Variables sustituidas por Terraform templatefile():
#   ${s3_bucket}   → nombre del bucket S3
#   ${model_key}   → clave del modelo (models/model.joblib)
#   ${aws_region}  → región de AWS

set -euo pipefail  # Abortar ante cualquier error

LOG_FILE="/var/log/mlops-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirigir stdout y stderr al log

echo "======================================================"
echo " MLOps Housing — Bootstrap iniciado: $(date)"
echo " Bucket: ${s3_bucket}"
echo " Model key: ${model_key}"
echo " Región: ${aws_region}"
echo "======================================================"

# ── 1. Sistema base ───────────────────────────────────────────────────────────
echo "[1/5] Actualizando sistema..."
dnf update -y --quiet
dnf install -y python3.11 python3.11-pip git --quiet
python3.11 -m ensurepip --upgrade
python3.11 -m pip install --upgrade pip --quiet

# ── 2. Directorio de trabajo ──────────────────────────────────────────────────
echo "[2/5] Configurando directorio de trabajo..."
APP_DIR="/opt/mlops-housing"
mkdir -p "$APP_DIR/src" "$APP_DIR/tests"
cd "$APP_DIR"

# Exportar variables de entorno para que train.py y app.py las lean
export S3_BUCKET="${s3_bucket}"
export MODEL_KEY="${model_key}"
export AWS_DEFAULT_REGION="${aws_region}"

# Persistir en /etc/environment para que uvicorn (systemd) las lea
cat >> /etc/environment <<EOF
S3_BUCKET=${s3_bucket}
MODEL_KEY=${model_key}
AWS_DEFAULT_REGION=${aws_region}
EOF

# ── 3. Dependencias Python ────────────────────────────────────────────────────
echo "[3/5] Instalando dependencias Python..."
cat > "$APP_DIR/requirements.txt" <<'REQS'
scikit-learn==1.4.2
joblib==1.4.0
numpy==1.26.4
pandas==2.2.2
boto3==1.34.84
botocore==1.34.84
fastapi==0.111.0
uvicorn[standard]==0.29.0
pydantic==2.7.1
REQS

python3.11 -m pip install -r requirements.txt --quiet

# ── 4. Código fuente ──────────────────────────────────────────────────────────
echo "[4/5] Descargando código fuente..."

# Fallback: si no hay código, descargar desde S3
if [ ! -f "$APP_DIR/src/train.py" ]; then
    echo "  → Descargando src/ desde s3://${s3_bucket}/src/"
    aws s3 cp "s3://${s3_bucket}/src/" "$APP_DIR/src/" --recursive --region "${aws_region}" || true
fi

# ── 5. Entrenamiento ──────────────────────────────────────────────────────────
echo "[5/5] Entrenando modelo..."
cd "$APP_DIR"
python3.11 src/train.py \
    --bucket "${s3_bucket}" \
    --key "${model_key}" \
    --output /tmp/model.joblib

echo "  ✓ Modelo entrenado y subido a S3."

# ── 6. Servir API ─────────────────────────────────────────────────────────────
echo "[6/5] Lanzando servidor FastAPI..."

# Crear servicio systemd para que la API sobreviva reinicios
cat > /etc/systemd/system/mlops-api.service <<UNIT
[Unit]
Description=MLOps Housing Inference API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="S3_BUCKET=${s3_bucket}"
Environment="MODEL_KEY=${model_key}"
Environment="AWS_DEFAULT_REGION=${aws_region}"
ExecStart=/usr/bin/python3.11 -m uvicorn src.app:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable mlops-api
systemctl start mlops-api

echo "======================================================"
echo " Bootstrap completado: $(date)"
echo " API disponible en http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
echo " Logs en: $LOG_FILE"
echo " Estado del servicio: systemctl status mlops-api"
echo "======================================================"

# Variables sustituidas por Terraform templatefile():
#   ${s3_bucket}   → nombre del bucket S3
#   ${model_key}   → clave del modelo (models/model.joblib)
#   ${aws_region}  → región de AWS

set -euo pipefail  # Abortar ante cualquier error

LOG_FILE="/var/log/mlops-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # Redirigir stdout y stderr al log

echo "======================================================"
echo " MLOps Housing — Bootstrap iniciado: $(date)"
echo " Bucket: ${s3_bucket}"
echo " Model key: ${model_key}"
echo " Región: ${aws_region}"
echo "======================================================"

# ── 1. Sistema base ───────────────────────────────────────────────────────────
echo "[1/5] Actualizando sistema..."
dnf update -y --quiet
dnf install -y python3.11 python3.11-pip git --quiet
python3.11 -m ensurepip --upgrade
python3.11 -m pip install --upgrade pip --quiet

# ── 2. Directorio de trabajo ──────────────────────────────────────────────────
echo "[2/5] Configurando directorio de trabajo..."
APP_DIR="/opt/mlops-housing"
mkdir -p "$APP_DIR/src" "$APP_DIR/tests"
cd "$APP_DIR"

# Exportar variables de entorno para que train.py y app.py las lean
export S3_BUCKET="${s3_bucket}"
export MODEL_KEY="${model_key}"
export AWS_DEFAULT_REGION="${aws_region}"

# Persistir en /etc/environment para que uvicorn (systemd) las lea
cat >> /etc/environment <<EOF
S3_BUCKET=${s3_bucket}
MODEL_KEY=${model_key}
AWS_DEFAULT_REGION=${aws_region}
EOF

# ── 3. Dependencias Python ────────────────────────────────────────────────────
echo "[3/5] Instalando dependencias Python..."
cat > "$APP_DIR/requirements.txt" <<'REQS'
scikit-learn==1.4.2
joblib==1.4.0
numpy==1.26.4
pandas==2.2.2
boto3==1.34.84
botocore==1.34.84
fastapi==0.111.0
uvicorn[standard]==0.29.0
pydantic==2.7.1
REQS

python3.11 -m pip install -r requirements.txt --quiet

# ── 4. Código fuente ──────────────────────────────────────────────────────────
echo "[4/5] Descargando código fuente..."

# Fallback: si no hay código, descargar desde S3
if [ ! -f "$APP_DIR/src/train.py" ]; then
    echo "  → Descargando src/ desde s3://${s3_bucket}/src/"
    aws s3 cp "s3://${s3_bucket}/src/" "$APP_DIR/src/" --recursive --region "${aws_region}" || true
fi

# ── 5. Entrenamiento ──────────────────────────────────────────────────────────
echo "[5/5] Entrenando modelo..."
cd "$APP_DIR"
python3.11 src/train.py \
    --bucket "${s3_bucket}" \
    --key "${model_key}" \
    --output /tmp/model.joblib

echo "  ✓ Modelo entrenado y subido a S3."

# ── 6. Servir API ─────────────────────────────────────────────────────────────
echo "[6/5] Lanzando servidor FastAPI..."

# Crear servicio systemd para que la API sobreviva reinicios
cat > /etc/systemd/system/mlops-api.service <<UNIT
[Unit]
Description=MLOps Housing Inference API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="S3_BUCKET=${s3_bucket}"
Environment="MODEL_KEY=${model_key}"
Environment="AWS_DEFAULT_REGION=${aws_region}"
ExecStart=/usr/bin/python3.11 -m uvicorn src.app:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable mlops-api
systemctl start mlops-api

echo "======================================================"
echo " Bootstrap completado: $(date)"
echo " API disponible en http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
echo " Logs en: $LOG_FILE"
echo " Estado del servicio: systemctl status mlops-api"
echo "======================================================"
