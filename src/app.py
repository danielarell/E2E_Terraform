import logging
import os
from typing import List

import boto3
import joblib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

# Configuración de logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="California Housing Inference API")

# --- Configuración de Paths ---
MODEL_LOCAL_PATH = "model.joblib"

# Valores por defecto basados en train.py
BUCKET_NAME = os.getenv("S3_BUCKET")
MODEL_S3_KEY = os.getenv("MODEL_KEY", "models/model.joblib")


def download_model_from_s3():
    """Descarga el modelo si el bucket está configurado."""
    if BUCKET_NAME:
        try:
            logger.info(
                f"Intentando descargar modelo desde s3://{BUCKET_NAME}/{MODEL_S3_KEY}"
            )
            s3 = boto3.client("s3")
            s3.download_file(
                BUCKET_NAME,
                MODEL_S3_KEY,
                MODEL_LOCAL_PATH,
            )
            logger.info("Modelo descargado exitosamente.")
        except Exception as e:
            logger.error(
                f"Error descargando de S3: {e}. "
                "Se intentará usar archivo local."
            )
    else:
        logger.warning(
            "S3_BUCKET no configurado. Se usará el modelo local si existe."
        )


# Intentar obtener el modelo al arrancar
download_model_from_s3()


# Cargar el modelo (el Pipeline ya incluye el StandardScaler)
try:
    model = joblib.load(MODEL_LOCAL_PATH)
    logger.info("Modelo cargado correctamente en memoria.")
except Exception as e:
    model = None
    logger.error(f"No se pudo cargar el modelo: {e}")


# --- Esquema de Validación de Datos ---
class PredictionRequest(BaseModel):
    """Request de predicción para el modelo."""

    # Orden:
    # [MedInc, HouseAge, AveRooms, AveBedrms,
    #  Population, AveOccup, Latitude, Longitude]
    features: List[float] = Field(
        ...,
        min_items=8,
        max_items=8,
        example=[
            8.32,
            41.0,
            6.98,
            1.02,
            322.0,
            2.55,
            37.88,
            -122.23,
        ],
    )


# --- Endpoints ---
@app.get("/health")
def health():
    """Verifica el estado del servicio y del modelo."""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "bucket": BUCKET_NAME,
    }


@app.post("/predict")
def predict(request: PredictionRequest):
    """Realiza la predicción de precio de vivienda."""
    if model is None:
        raise HTTPException(
            status_code=503,
            detail="Modelo no cargado en el servidor.",
        )

    try:
        prediction = model.predict([request.features])
        return {"prediction": float(prediction[0])}
    except Exception as e:
        logger.error(f"Error en predicción: {e}")
        raise HTTPException(
            status_code=500,
            detail="Error interno al procesar la predicción.",
        )
