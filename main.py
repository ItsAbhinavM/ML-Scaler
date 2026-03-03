import os
import datetime
from ultralytics import YOLO

outputFolder = "output"

model = YOLO('yolo11n.pt')
results = model(["resources/bild.jpg"])

for result in results:
    result.show()
    timestamp =  datetime.datetime.now().strftime("%H%M")
    save_path = os.path.join(outputFolder,f"{timestamp}_result.jpg")
    result.save(filename = save_path)
