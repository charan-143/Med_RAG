"""
Vault routes: files + folders + overview stats.
Replaces and extends the original routes_upload.py functionality.
"""

import os
import shutil
import threading
import uuid
import mimetypes
import asyncio
from pathlib import Path

from fastapi import APIRouter, File, UploadFile, HTTPException, Form, Query, Depends, BackgroundTasks
from fastapi.responses import FileResponse
from typing import Optional

from agno.team import Team
from api.dependencies import get_medical_team_router

from db.sqlite_db import (
    insert_file, get_file, list_files, delete_file_record, update_file_ai,
    list_folders, create_folder, update_folder, delete_folder, get_folder_file_count,
    get_overview_stats, update_folder_ai
)
from models.api_models import (
    UploadResponse, FileOut, FolderOut, FolderCreate, FolderUpdate, OverviewStats, FileMoveRequest
)
from services.document_parser import load_documents_to_db

router = APIRouter(tags=["vault"])

UPLOAD_DIR = "data/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

_pdf_lock = threading.Lock()

ALLOWED_EXTENSIONS = {
    ".pdf":  ("pdf",   "application/pdf"),
    ".png":  ("image", "image/png"),
    ".jpg":  ("image", "image/jpeg"),
    ".jpeg": ("image", "image/jpeg"),
    ".webp": ("image", "image/webp"),
    ".dicom":("image", "application/dicom"),
    ".dcm":  ("image", "application/dicom"),
    ".tiff": ("image", "image/tiff"),
    ".tif":  ("image", "image/tiff"),
}


def _infer_ai_name(original_name: str, file_type: str) -> str:
    """Simple deterministic AI-style name from filename (real AI via /api/files/{id}/summarize)."""
    stem = Path(original_name).stem.replace("_", " ").replace("-", " ").title()
    return stem


# ─── Overview ───────────────────────────────────────────────────────────────────
@router.get("/overview/stats", response_model=OverviewStats)
async def overview_stats():
    return get_overview_stats()


# ─── Folders ────────────────────────────────────────────────────────────────────
@router.get("/folders", response_model=list[FolderOut])
async def get_folders():
    folders = list_folders()
    result = []
    for f in folders:
        result.append(FolderOut(
            **f,
            file_count=get_folder_file_count(f["id"])
        ))
    return result

@router.post("/folders", response_model=FolderOut, status_code=201)
async def add_folder(body: FolderCreate):
    try:
        folder = create_folder(body.name, body.icon)
        return FolderOut(**folder, file_count=0)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/folders/{folder_id}", response_model=FolderOut)
async def edit_folder(folder_id: str, body: FolderUpdate):
    try:
        folder = update_folder(folder_id, name=body.name, icon=body.icon)
        if not folder:
            raise HTTPException(status_code=404, detail="Folder not found")
        return FolderOut(**folder, file_count=get_folder_file_count(folder_id))
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/folders/{folder_id}", status_code=204)
async def remove_folder(folder_id: str):
    delete_folder(folder_id)

@router.post("/folders/{folder_id}/summarize", response_model=FolderOut)
async def summarize_folder(folder_id: str, team: Team = Depends(get_medical_team_router)):
    conn_folder = update_folder(folder_id)
    if not conn_folder:
        raise HTTPException(404, "Folder not found")
        
    files = list_files(folder_id)
    if not files:
        summary = "This folder is empty."
    else:
        file_list_str = "\n".join(f"- {f['original_name']}: {f.get('ai_summary') or 'No summary yet'}" for f in files)
        prompt = f"Please provide a concise medical patient overview (2-3 sentences) based on the summaries of the documents in this folder:\n{file_list_str}"
        try:
            result = await asyncio.to_thread(team.run, prompt)
            summary = result.content
            if isinstance(summary, list):
                summary = "\n".join(str(block.text if hasattr(block, "text") else block) for block in summary)
        except Exception as e:
            summary = "Summary generation failed."

    update_folder_ai(folder_id, ai_summary=summary)
    conn_folder["ai_summary"] = summary
    return FolderOut(**conn_folder, file_count=len(files))


# ─── Files ──────────────────────────────────────────────────────────────────────
@router.get("/files", response_model=list[FileOut])
async def get_files(folder_id: Optional[str] = Query(None)):
    files = list_files(folder_id)
    return [FileOut(**f) for f in files]

@router.get("/files/{file_id}", response_model=FileOut)
async def get_file_detail(file_id: str):
    f = get_file(file_id)
    if not f:
        raise HTTPException(404, "File not found")
    return FileOut(**f)

@router.get("/files/{file_id}/preview")
async def preview_file(file_id: str):
    f = get_file(file_id)
    if not f:
        raise HTTPException(404, "File not found")
    path = os.path.join(UPLOAD_DIR, f["safe_name"])
    if not os.path.exists(path):
        raise HTTPException(404, "File not found on disk")
    media_type = f.get("mime_type")
    
    # Fallback MIME type guessing if the DB has octet-stream
    if not media_type or media_type == "application/octet-stream":
        name_lower = f["original_name"].lower()
        if name_lower.endswith(".pdf"):
            media_type = "application/pdf"
        elif name_lower.endswith((".png", ".jpg", ".jpeg")):
            media_type = "image/jpeg"
        else:
            media_type = "application/octet-stream"

    return FileResponse(
        path, 
        media_type=media_type, 
        filename=f["original_name"], 
        content_disposition_type="inline"
    )

@router.patch("/files/{file_id}/move", response_model=FileOut)
async def move_file(file_id: str, body: FileMoveRequest):
    import sqlite3 as _sql
    from db.sqlite_db import get_conn
    f = get_file(file_id)
    if not f:
        raise HTTPException(404, "File not found")
    with get_conn() as conn:
        conn.execute("UPDATE files SET folder_id=? WHERE id=?", (body.folder_id, file_id))
        conn.commit()
    return FileOut(**get_file(file_id))

@router.delete("/files/{file_id}", status_code=204)
async def delete_file(file_id: str):
    safe_name = delete_file_record(file_id)
    if safe_name:
        disk_path = os.path.join(UPLOAD_DIR, safe_name)
        if os.path.exists(disk_path):
            os.remove(disk_path)


async def _run_summarization_logic(file_id: str, team: Team):
    """Helper to generate and store AI summary for a specific file."""
    import logging
    logger = logging.getLogger(__name__)
    
    f = get_file(file_id)
    if not f:
        return
        
    try:
        from services.image_processor import prepare_image
        images_to_process = []
        if f["file_type"] == "image":
            disk_path = os.path.join(UPLOAD_DIR, f["safe_name"])
            if os.path.exists(disk_path):
                images_to_process.append(prepare_image(disk_path))
            prompt = (
                "Please perform a comprehensive medical analysis of this image. "
                "Extract all observable details and present them using rich Markdown formatting to look stylish. "
                "Use headers (##), bold text (**), and lists (-) where appropriate. "
                "Ensure you include: \n"
                "- Title / Image Type\n"
                "- Detected Patient Info & Dates\n"
                "- Key Findings\n"
                "- Detailed Clinical Summary"
            )
        else:
            text_context = ""
            disk_path = os.path.join(UPLOAD_DIR, f["safe_name"])
            if f["file_type"] in ("pdf", "document") and os.path.exists(disk_path):
                from agno.knowledge.reader.pdf_reader import PDFReader
                try:
                    docs = PDFReader().read(pdf=disk_path)
                    text_context = "\n".join([d.content for d in docs if d.content])
                    text_context = text_context[:15000] # truncate to avoid token limits
                except Exception as e:
                    logger.error(f"Failed to read PDF text for {file_id}: {e}")
                    
            prompt = (
                f"Please extract all significant medical details from the document named '{f['original_name']}'. "
                f"Do not just write a short summary. Extract everything relevant and format your response using rich Markdown to make it stylish. "
                f"Use headers (##), bold text (**), and bullet points (-) to organize the information clearly. "
                f"Please organize fields such as Patient Info, Dates, Diagnoses, Key Findings, and a Clinical Summary."
            )
            if text_context:
                prompt += f"\n\nDocument text:\n{text_context}"
            
        if images_to_process:
            result = await asyncio.to_thread(team.run, prompt, images=images_to_process)
        else:
            result = await asyncio.to_thread(team.run, prompt)
            
        summary = result.content
        if not summary:
            summary = "The AI was unable to generate a summary for this file type."
        elif isinstance(summary, list):
            summary = "\n".join(str(block.text if hasattr(block, "text") else block) for block in summary)
            
    except Exception as e:
        logger.error(f"Gemini summarization failed for {file_id}: {e}")
        summary = "AI Overview is currently unavailable for this document. (Transient error or unreadable content)"

    update_file_ai(file_id, ai_summary=summary)

@router.post("/files/{file_id}/summarize", response_model=FileOut)
async def summarize_file(file_id: str, team: Team = Depends(get_medical_team_router)):
    await _run_summarization_logic(file_id, team)
    f = get_file(file_id)
    if not f:
        raise HTTPException(404, "File not found")
    return FileOut(**f)

# ─── Upload ──────────────────────────────────────────────────────────────────────
@router.post("/upload", response_model=UploadResponse, status_code=201)
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    folder_id: Optional[str] = Form(None),
    team: Team = Depends(get_medical_team_router),
):
    if not file.filename:
        raise HTTPException(400, "No file uploaded")

    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"Unsupported file type '{ext}'. "
                                  f"Allowed: {', '.join(ALLOWED_EXTENSIONS)}")

    file_type, mime_type = ALLOWED_EXTENSIONS[ext]
    safe_name = f"{uuid.uuid4().hex}{ext}"
    disk_path = os.path.join(UPLOAD_DIR, safe_name)

    # Stream to disk
    with open(disk_path, "wb") as buf:
        shutil.copyfileobj(file.file, buf)

    size_bytes = os.path.getsize(disk_path)
    ai_name = _infer_ai_name(file.filename, file_type)

    # Vectorize PDFs
    if file_type == "pdf":
        import asyncio
        import logging
        def _parse_pdf_sync():
            with _pdf_lock:
                load_documents_to_db(disk_path, file.filename)

        try:
            await asyncio.to_thread(_parse_pdf_sync)
        except Exception as e:
            logging.getLogger(__name__).exception("PDF vectorization failed:")

    # Persist metadata
    record = insert_file(
        original_name=file.filename,
        safe_name=safe_name,
        file_type=file_type,
        mime_type=mime_type,
        size_bytes=size_bytes,
        folder_id=folder_id,
        ai_name=ai_name,
    )

    # Trigger background summarization
    background_tasks.add_task(_run_summarization_logic, record["id"], team)

    return UploadResponse(
        message=f"{file.filename} uploaded successfully.",
        filename=safe_name,
        file_id=record["id"],
        status="success",
    )


# ─── Legacy compat ───────────────────────────────────────────────────────────────
# Keep old /api/upload route pointing here for backward compatibility
