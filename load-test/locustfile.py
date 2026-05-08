import os
from locust import HttpUser, task, between

# Path to test image relative to where locust is run (project root)
IMAGE_PATH = os.path.join(os.path.dirname(__file__), "..", "resources", "bild.jpg")

class MLScalerUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def predict(self):
        with open(IMAGE_PATH, "rb") as img:
            self.client.post(
                "/predict",
                files={"file": ("bild.jpg", img, "image/jpeg")},
            )

    @task(3)
    def health_check(self):
        self.client.get("/health")
