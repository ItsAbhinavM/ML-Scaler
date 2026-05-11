import time

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from .metrics import ACTIVE_REQUESTS, ERRORS_TOTAL, REQUEST_LATENCY, REQUESTS_TOTAL
from .metrics import INFERENCE_DURATION
from .model import create_model

app = FastAPI(title="YOLO Inference Service")
model = create_model()


@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    start = time.perf_counter()
    ACTIVE_REQUESTS.inc()
    status = 200
    try:
        if not file.content_type or "image" not in file.content_type:
            ERRORS_TOTAL.labels("invalid_content_type").inc()
            raise HTTPException(status_code=400, detail="File must be an image")
        data = await file.read()
        detections = model.predict(data)
        return {"detections": detections, "count": len(detections)}
    except HTTPException:
        status = 400
        raise
    except Exception as exc:
        status = 500
        ERRORS_TOTAL.labels("inference_error").inc()
        raise HTTPException(status_code=500, detail=str(exc))
    finally:
        ACTIVE_REQUESTS.dec()
        REQUESTS_TOTAL.labels("POST", "/predict", str(status)).inc()
        REQUEST_LATENCY.labels("POST", "/predict").observe(time.perf_counter() - start)


@app.get("/metrics")
def metrics():
    # Ensure histograms are exported even if no requests happened yet.
    _ = INFERENCE_DURATION
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
