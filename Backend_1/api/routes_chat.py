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
        UPLOAD_DIR = "data/uploads"
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        
        filepath = os.path.join(UPLOAD_DIR, image.filename)
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        if image.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
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
        raise HTTPException(status_code=500, detail=str(e))
