"""
test_endpoint.py — Integration tests for the deployed endpoint.

Usage:
    EC2_IP=<IP> pytest tests/test_endpoint.py -v
    pytest tests/test_endpoint.py -v  # defaults to localhost
"""
import os
import pytest
import httpx

BASE_URL = os.environ.get(
    "API_BASE_URL",
    f"http://{os.environ.get('EC2_IP', 'localhost')}:8000",
)

VALID_FEATURES = [8.3252, 41.0, 6.9841, 1.0238, 322.0, 2.5556, 37.88, -122.23]
TIMEOUT = 30


@pytest.fixture(scope="session")
def client():
    return httpx.Client(base_url=BASE_URL, timeout=TIMEOUT)


class TestHealth:
    def test_returns_200(self, client):
        assert client.get("/health").status_code == 200

    def test_model_loaded(self, client):
        data = client.get("/health").json()
        assert data.get("model_loaded") is True, f"Model not loaded: {data}"

    def test_status_healthy(self, client):
        data = client.get("/health").json()
        assert data.get("status") == "healthy", f"Unexpected status: {data}"


class TestPredict:
    def test_returns_200(self, client):
        assert client.post("/predict", json={"features": VALID_FEATURES}).status_code == 200

    def test_response_has_prediction(self, client):
        data = client.post("/predict", json={"features": VALID_FEATURES}).json()
        assert "prediction" in data

    def test_prediction_is_float(self, client):
        pred = client.post("/predict", json={"features": VALID_FEATURES}).json()["prediction"]
        assert isinstance(pred, (int, float))

    def test_prediction_in_range(self, client):
        pred = client.post("/predict", json={"features": VALID_FEATURES}).json()["prediction"]
        assert 0.1 < pred < 20, f"Prediction out of range: {pred}"

    def test_rejects_too_many_features(self, client):
        assert client.post("/predict", json={"features": VALID_FEATURES + [99.0]}).status_code == 422

    def test_rejects_empty_body(self, client):
        assert client.post("/predict", json={}).status_code == 422
