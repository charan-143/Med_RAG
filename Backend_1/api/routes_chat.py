from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from typing import Optional
from PIL import Image
import io
import os
import shutil

from api.dependencies import get_medical_team_router
from models.api_models import ChatResponse
from services.image_processor import prepare_image
from agno.agent import Agent

router = APIRouter()

@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    message: str = Form(...), 
    image: Optional[UploadFile] = File(None),
    agent: Agent = Depends(get_medical_team_router)
):
    images_to_process = []
    
    if image and image.filename:
        filename_lower = image.filename.lower()
        if not filename_lower.endswith(('.png', '.jpg', '.jpeg', '.webp')):
            raise HTTPException(status_code=400, detail="Unsupported image file type. Please upload a .png, .jpg, .jpeg, or .webp file.")

        UPLOAD_DIR = "data/uploads"
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        
        import uuid
        ext = os.path.splitext(filename_lower)[1]
        safe_filename = f"{uuid.uuid4().hex}{ext}"
        filepath = os.path.join(UPLOAD_DIR, safe_filename)
        
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        images_to_process.append(prepare_image(filepath))

    try:
        # Run the routing team agent
        if images_to_process:
            response = agent.run(message, images=images_to_process)
        else:
            response = agent.run(message)
            
        return ChatResponse(
            response=response.content,
            status="success",
            context_used=True if not images_to_process else False 
        )

    except Exception as e:
        import logging
        logging.getLogger(__name__).exception("An unhandled error occurred during chat_endpoint execution:")
        raise HTTPException(status_code=500, detail="Internal server error")
