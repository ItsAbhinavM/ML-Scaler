import os
from locust import HttpUser, task, between

# Path to test image relative to where locust is run (project root)
IMAGE_PATH = os.path.join(os.path.dirname(__file__), "..", "resources", "bild.jpg")


class MLScalerUser(HttpUser):
    """Load test user for ML-Scaler YOLO API.

    Sends prediction requests (CPU-intensive ML inference) and health checks.
    The predict task is weighted higher to stress the CPU and trigger HPA scaling.
    wait_time: 0.5-1.5s gives realistic pacing — avoids overwhelming single-threaded uvicorn.
    """
    wait_time = between(0.5, 1.5)

    @task(4)
    def predict(self):
        """Send image for YOLO inference — this is the CPU-heavy operation."""
        with open(IMAGE_PATH, "rb") as img:
            self.client.post(
                "/predict",
                files={"file": ("bild.jpg", img, "image/jpeg")},
                timeout=120,   # 2 min timeout — inference can be slow under load
            )

    @task(1)
    def health_check(self):
        """Lightweight health check endpoint."""
        self.client.get("/health", timeout=30)
