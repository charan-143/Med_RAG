import os
import shutil
from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from services.document_parser import load_documents_to_db

router = APIRouter()

UPLOAD_DIR = "data/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")
    
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # If the file is a PDF, trigger vector store load
    if file.filename.lower().endswith('.pdf'):
        load_documents_to_db(file_path)
        return JSONResponse(content={"message": f"PDF {file.filename} uploaded and vectorized successfully."})
    
    # If it is an image
    elif file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
        return JSONResponse(content={"message": f"Image {file.filename} uploaded successfully. You can now refer to it in your chat."})

    return JSONResponse(content={"message": f"File {file.filename} uploaded successfully."})
