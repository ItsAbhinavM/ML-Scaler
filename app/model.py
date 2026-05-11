import io
import os
import time

import cv2
import numpy as np
from ultralytics import YOLO

from metrics import INFERENCE_DURATION


def _load_image(file_bytes: bytes) -> np.ndarray:
    image_array = np.frombuffer(file_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Unable to decode image")
    return image


class YoloModel:
    def __init__(self, model_path: str) -> None:
        self.model = YOLO(model_path)

    def predict(self, file_bytes: bytes, conf: float = 0.25):
        image = _load_image(file_bytes)
        start = time.perf_counter()
        results = self.model.predict(source=image, conf=conf, verbose=False)
        duration = time.perf_counter() - start
        INFERENCE_DURATION.observe(duration)
        return self._format_results(results)

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
