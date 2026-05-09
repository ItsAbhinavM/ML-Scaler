import os
import time
import shutil

from fastapi import FastAPI, UploadFile
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from ultralytics import YOLO

app = FastAPI(title="ML-Scaler YOLO API")

# Instrument Prometheus metrics at /metrics
Instrumentator().instrument(app).expose(app)

# Load model once at startup (per worker process)
model = YOLO("yolo11n.pt")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/predict")
async def predict(file: UploadFile):
    os.makedirs("input", exist_ok=True)
    os.makedirs("output", exist_ok=True)
    file_path = f"input/{file.filename}"

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    start = time.time()
    results = model(file_path, verbose=False)  # verbose=False reduces log spam under load
    inference_time = time.time() - start

    detections = []
    for box in results[0].boxes:
        detections.append({
            "class": results[0].names[int(box.cls[0])],
            "confidence": float(box.conf[0]),
            "bbox": box.xyxy[0].tolist(),
        })

    return JSONResponse(content={
        "status": "done",
        "inference_time_ms": round(inference_time * 1000, 2),
        "detections": detections,
    })