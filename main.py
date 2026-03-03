from fastapi import FastAPI, UploadFile
from ultralytics import YOLO
import shutil
import os

app = FastAPI()
model = YOLO("yolo11n.pt")

@app.post("/predict")
async def predict(file: UploadFile):
    os.makedirs("input", exist_ok=True)
    file_path = f"input/{file.filename}"
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    results = model(file_path)
    results[0].save(filename="output/result.jpg")

    return {"status": "done"}