import os
import shutil
from fastapi import APIRouter, File, UploadFile, HTTPException
from services.document_parser import load_documents_to_db
from models.api_models import UploadResponse

router = APIRouter()

UPLOAD_DIR = "data/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")
    
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # If the file is a PDF, trigger vector store load
    if file.filename.lower().endswith('.pdf'):
        load_documents_to_db(file_path)
        return UploadResponse(
            message=f"PDF {file.filename} uploaded and vectorized successfully.",
            filename=file.filename,
            status="success"
        )
    
    # If it is an image
    elif file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
        return UploadResponse(
            message=f"Image {file.filename} uploaded successfully. You can now refer to it in your chat.", 
            filename=file.filename,
            status="success"
        )

    return UploadResponse(
        message=f"File {file.filename} uploaded successfully.",
        filename=file.filename,
        status="success"
    )
