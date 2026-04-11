"""
train.py — Entrena un LinearRegression con California Housing
y sube el artefacto serializado a S3.

Uso:
    python train.py --bucket mi-bucket --key models/model.joblib
"""
import argparse
import logging
import os

import boto3
import joblib
import numpy as np
from sklearn.datasets import fetch_california_housing
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)


# ─── Constantes ─────────────────────────────────────────────────────────────

FEATURE_NAMES = [
    "MedInc",       # Ingreso mediano del hogar (decenas de miles USD)
    "HouseAge",     # Edad mediana de la casa
    "AveRooms",     # Promedio de cuartos por hogar
    "AveBedrms",    # Promedio de habitaciones por hogar
    "Population",   # Población del bloque
    "AveOccup",     # Promedio de ocupantes por hogar
    "Latitude",     # Latitud del bloque
    "Longitude",    # Longitud del bloque
]


# ─── Funciones ───────────────────────────────────────────────────────────────

def load_data():
    """Carga el dataset California Housing desde scikit-learn."""
    log.info("Cargando California Housing dataset…")
    housing = fetch_california_housing(as_frame=True)
    X = housing.data[FEATURE_NAMES]
    y = housing.target  # Valor mediano de casa en $100,000
    log.info("Dataset cargado: %d muestras, %d features", len(X), X.shape[1])
    return X, y


def build_pipeline():
    """Construye el pipeline: escalado + regresión lineal."""
    return Pipeline([
        ("scaler", StandardScaler()),
        ("regressor", LinearRegression()),
    ])


def train_model(X, y):
    """
    Divide, entrena y evalúa el modelo.
    Retorna (modelo_entrenado, métricas).
    """
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    log.info(
        "Split: %d train / %d test",
        len(X_train), len(X_test)
    )

    model = build_pipeline()
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    r2 = r2_score(y_test, y_pred)

    metrics = {"rmse": round(rmse, 4), "r2": round(r2, 4)}
    log.info("Métricas — RMSE: %.4f | R²: %.4f", rmse, r2)
    return model, metrics


def save_model_locally(model, path):
    """Serializa el modelo a disco con joblib."""
    joblib.dump(model, path)
    log.info("Modelo guardado localmente en: %s", path)


def upload_to_s3(local_path, bucket, key):
    """Sube el archivo al bucket S3 indicado."""
    s3 = boto3.client("s3")
    log.info("Subiendo a s3://%s/%s…", bucket, key)
    s3.upload_file(local_path, bucket, key)
    log.info("Upload completado.")


# ─── Entry point ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Entrenamiento MLOps Housing")
    parser.add_argument(
        "--bucket",
        default=os.environ.get("S3_BUCKET", ""),
        help="Nombre del bucket S3 donde subir el modelo",
    )
    parser.add_argument(
        "--key",
        default=os.environ.get("MODEL_KEY", "models/model.joblib"),
        help="Clave (path) del modelo dentro del bucket",
    )
    parser.add_argument(
        "--output",
        default="model.joblib",
        help="Ruta local del modelo serializado (por defecto: model.joblib)",
    )
    args = parser.parse_args()

    # 1. Cargar datos
    X, y = load_data()

    # 2. Entrenar
    model, metrics = train_model(X, y)

    # 3. Guardar localmente
    save_model_locally(model, args.output)

    # 4. Subir a S3 (opcional: si no hay bucket definido, sólo guarda local)
    if args.bucket:
        upload_to_s3(args.output, args.bucket, args.key)
    else:
        log.warning(
            "No se definió S3_BUCKET. El modelo sólo se guardó localmente."
        )

    log.info("¡Entrenamiento completado! Métricas finales: %s", metrics)
    return metrics


if __name__ == "__main__":
    main()