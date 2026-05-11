import io
import os
import time

import numpy as np
from PIL import Image

from .metrics import INFERENCE_DURATION


class YoloModel:
    def __init__(self, model_path: str) -> None:
        # In Docker Compose mode we keep the image lightweight (no torch/ultralytics).
        # The API stays the same, but predictions are mocked.
        self._mock_mode = os.getenv("YOLO_MOCK", "0") == "1"
        self.model_path = model_path

        if not self._mock_mode:
            # Lazy import so local/k8s deployments can still use the real model.
            from ultralytics import YOLO  # type: ignore

            self.model = YOLO(model_path)
        else:
            self.model = None

    def predict(self, file_bytes: bytes, conf: float = 0.25):
        image = self._load_image(file_bytes)
        start = time.perf_counter()
        try:
            if self._mock_mode:
                # Fake some compute that scales with image size.
                w, h = image.size
                work = (w * h) / (640 * 480)
                time.sleep(min(0.05, 0.005 * max(1.0, work)))
                return self._mock_results(image.size)

            results = self.model.predict(source=np.array(image), conf=conf, verbose=False)
            return self._format_results(results)
        finally:
            duration = time.perf_counter() - start
            INFERENCE_DURATION.observe(duration)

    @staticmethod
    def _load_image(file_bytes: bytes) -> Image.Image:
        try:
            return Image.open(io.BytesIO(file_bytes)).convert("RGB")
        except Exception as exc:
            raise ValueError("Unable to decode image") from exc

    @staticmethod
    def _mock_results(size):
        w, h = size
        return [
            {
                "class_id": 0,
                "confidence": 0.42,
                "bbox": {
                    "x1": w * 0.25,
                    "y1": h * 0.25,
                    "x2": w * 0.75,
                    "y2": h * 0.75,
                },
            }
        ]

    @staticmethod
    def _format_results(results):
        formatted = []
        for result in results:
            boxes = result.boxes
            if boxes is None or boxes.shape[0] == 0:
                continue
            for box in boxes:
                xyxy = box.xyxy[0].tolist()
                cls = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                formatted.append(
                    {
                        "class_id": cls,
                        "confidence": conf,
                        "bbox": {
                            "x1": xyxy[0],
                            "y1": xyxy[1],
                            "x2": xyxy[2],
                            "y2": xyxy[3],
                        },
                    }
                )
        return formatted


def create_model():
    model_path = os.getenv("YOLO_MODEL", "yolov8n.pt")
    return YoloModel(model_path)
