from locust import HttpUser, task, between


class YoloUser(HttpUser):
    wait_time = between(0.5, 1.5)

    def on_start(self):
        self.image = (
            b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
            b"\xff\xdb\x00\x84\x00" + b"\x08" * 64 + b"\xff\xc0\x00\x11\x08\x00\x01\x00\x01\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01\xff\xda\x00\x0c\x03\x01\x00\x02\x11\x03\x11\x00\x3f\x00\xa4\x03\xff\xd9"
        )

    @task
    def predict(self):
        files = {"file": ("sample.jpg", self.image, "image/jpeg")}
        self.client.post("/predict", files=files)
