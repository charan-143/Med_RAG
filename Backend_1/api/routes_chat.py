from fastapi import APIRouter, HTTPException, File, Form, UploadFile
from typing import Optional
import os
import shutil
from agents.medical_agent import medical_agent
from services.image_processor import prepare_image

router = APIRouter()

@router.post("/chat")
async def chat(
    message: str = Form(...),
    file: Optional[UploadFile] = File(None)
):
    images_to_process = []
    
    # Check if a file was provided with the chat message
    if file and file.filename:
        UPLOAD_DIR = "data/uploads"
        # Ensure directory exists just in case
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        
        filepath = os.path.join(UPLOAD_DIR, file.filename)
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Optional: verify it is an image
        if file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            images_to_process.append(prepare_image(filepath))
        else:
            # If they upload a PDF directly here, we could parse it, but let's assume it's for imágenes
            pass
            
    try:
        # If images are provided, Agno will automatically convert them to Gemini multimodal blocks
        if images_to_process:
            response = medical_agent.run(message, images=images_to_process)
        else:
            response = medical_agent.run(message)
            
        return {"response": response.content}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
