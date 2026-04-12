import io
import os
import sys
import boto3
import joblib
import numpy as np
import pytest
from moto import mock_aws
from train import (
    FEATURE_NAMES,
    build_pipeline,
    load_data,
    save_model_locally,
    train_model,
    upload_to_s3,
)

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

# Fixtures


@pytest.fixture(scope="module")
def dataset():
    return load_data()


@pytest.fixture(scope="module")
def trained_model(dataset):
    X, y = dataset
    model, metrics = train_model(X, y)
    return model, metrics


@pytest.fixture
def tmp_model_path(tmp_path):
    return str(tmp_path / "model.joblib")

# Test de carga de datos


class TestLoadData:
    def test_returns_two_elements(self, dataset):
        X, y = dataset
        assert X is not None and y is not None

    def test_feature_count(self, dataset):
        X, _ = dataset
        assert X.shape[1] == 8, f"Se esperaban 8 features, se obtuvieron {X.shape[1]}"

    def test_feature_names(self, dataset):
        X, _ = dataset
        assert list(X.columns) == FEATURE_NAMES

    def test_sample_count_reasonable(self, dataset):
        X, y = dataset
        assert len(X) > 1000, "Dataset demasiado pequeño"
        assert len(X) == len(y), "X e y deben tener el mismo número de filas"

    def test_no_missing_values(self, dataset):
        X, y = dataset
        assert X.isnull().sum().sum() == 0, "Hay valores nulos en X"
        assert y.isnull().sum() == 0, "Hay valores nulos en y"

    def test_target_range(self, dataset):
        _, y = dataset
        assert y.min() > 0, "Precios negativos no tienen sentido"
        assert y.max() < 100, "Precios absurdamente altos (el target está en $100K)"


# Tests pipeline

class TestBuildPipeline:
    def test_pipeline_has_two_steps(self):
        pipe = build_pipeline()
        assert len(pipe.steps) == 2

    def test_pipeline_step_names(self):
        pipe = build_pipeline()
        names = [name for name, _ in pipe.steps]
        assert "scaler" in names
        assert "regressor" in names

    def test_pipeline_has_predict_method(self):
        pipe = build_pipeline()
        assert hasattr(pipe, "predict"), "El pipeline debe tener método predict"


# Tests entrenamiento

class TestTrainModel:
    def test_returns_model_and_metrics(self, trained_model):
        model, metrics = trained_model
        assert model is not None
        assert isinstance(metrics, dict)

    def test_metrics_keys(self, trained_model):
        _, metrics = trained_model
        assert "rmse" in metrics
        assert "r2" in metrics

    def test_rmse_non_negative(self, trained_model):
        _, metrics = trained_model
        assert metrics["rmse"] >= 0

    def test_r2_positive(self, trained_model):
        _, metrics = trained_model
        assert metrics["r2"] > 0.5, (
            f"R² demasiado bajo ({metrics['r2']}). "
            "Revisa que el pipeline incluya el scaler."
        )

    def test_model_can_predict(self, trained_model):
        model, _ = trained_model
        sample = np.array([[8.3252, 41.0, 6.9841, 1.0238, 322.0, 2.5556, 37.88, -122.23]])
        prediction = model.predict(sample)
        assert prediction.shape == (1,)
        assert prediction[0] > 0

    def test_prediction_in_reasonable_range(self, trained_model):
        model, _ = trained_model
        sample = np.array([[8.3252, 41.0, 6.9841, 1.0238, 322.0, 2.5556, 37.88, -122.23]])
        pred = model.predict(sample)[0]
        assert 0.1 < pred < 20, f"Predicción fuera de rango razonable: {pred}"


# Tests serialización

class TestSerialization:
    def test_save_creates_file(self, trained_model, tmp_model_path):
        model, _ = trained_model
        save_model_locally(model, tmp_model_path)
        assert os.path.exists(tmp_model_path)

    def test_saved_file_not_empty(self, trained_model, tmp_model_path):
        model, _ = trained_model
        save_model_locally(model, tmp_model_path)
        assert os.path.getsize(tmp_model_path) > 0

    def test_loaded_model_predicts_same(self, trained_model, tmp_model_path):
        model, _ = trained_model
        save_model_locally(model, tmp_model_path)

        loaded = joblib.load(tmp_model_path)
        sample = np.array([[5.0, 20.0, 5.0, 1.0, 200.0, 2.5, 34.0, -118.0]])

        pred_original = model.predict(sample)[0]
        pred_loaded = loaded.predict(sample)[0]

        assert abs(pred_original - pred_loaded) < 1e-6


# Tests upload a S3 (mock)

class TestUploadToS3:
    @mock_aws
    def test_upload_creates_object(self, trained_model, tmp_model_path):
        model, _ = trained_model
        save_model_locally(model, tmp_model_path)

        # Crear bucket falso con moto
        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket="test-bucket")

        upload_to_s3(tmp_model_path, "test-bucket", "models/model.joblib")

        # Verificar que el objeto existe
        response = s3.head_object(Bucket="test-bucket", Key="models/model.joblib")
        assert response["ResponseMetadata"]["HTTPStatusCode"] == 200

    @mock_aws
    def test_uploaded_object_is_valid_model(self, trained_model, tmp_model_path):
        model, _ = trained_model
        save_model_locally(model, tmp_model_path)

        s3 = boto3.client("s3", region_name="us-east-1")
        s3.create_bucket(Bucket="test-bucket")
        upload_to_s3(tmp_model_path, "test-bucket", "models/model.joblib")

        # Descargar y verificar
        obj = s3.get_object(Bucket="test-bucket", Key="models/model.joblib")
        model_bytes = obj["Body"].read()
        loaded = joblib.load(io.BytesIO(model_bytes))

        sample = np.array([[5.0, 20.0, 5.0, 1.0, 200.0, 2.5, 34.0, -118.0]])
        assert loaded.predict(sample).shape == (1,)
