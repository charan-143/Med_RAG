import os
import shutil
import threading
from fastapi import APIRouter, File, UploadFile, HTTPException
from services.document_parser import load_documents_to_db
from models.api_models import UploadResponse

router = APIRouter()

pdf_db_lock = threading.Lock()

def safe_load_documents_to_db(path):
    with pdf_db_lock:
        load_documents_to_db(path)

UPLOAD_DIR = "data/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")
    
    filename_lower = file.filename.lower()
    if filename_lower.endswith('.pdf'):
        file_type = 'pdf'
    elif filename_lower.endswith(('.png', '.jpg', '.jpeg', '.webp')):
        file_type = 'image'
    else:
        raise HTTPException(status_code=400, detail="Unsupported file type. Please upload a PDF or an image (.png, .jpg, .jpeg, .webp).")
    
    import uuid
    ext = os.path.splitext(filename_lower)[1]
    safe_filename = f"{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, safe_filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    import asyncio
    import logging

    if file_type == 'pdf':
        try:
            await asyncio.to_thread(safe_load_documents_to_db, file_path)
        except Exception as e:
            logging.getLogger(__name__).exception("Failed to parse and vectorize PDF:")
            raise HTTPException(status_code=500, detail="Internal server error during document processing.") from e
            
        return UploadResponse(
            message=f"PDF {file.filename} uploaded and vectorized successfully.",
            filename=safe_filename,
            status="success"
        )
    elif file_type == 'image':
        return UploadResponse(
            message=f"Image {file.filename} uploaded successfully. You can now refer to it in your chat.", 
            filename=safe_filename,
            status="success"
        )
