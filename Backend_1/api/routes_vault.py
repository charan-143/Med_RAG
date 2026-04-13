"""
Vault routes: files + folders + overview stats.
Replaces and extends the original routes_upload.py functionality.
"""

import os
import shutil
import threading
import uuid
import mimetypes
from pathlib import Path

from fastapi import APIRouter, File, UploadFile, HTTPException, Form, Query
from fastapi.responses import FileResponse
from typing import Optional

from db.sqlite_db import (
    insert_file, get_file, list_files, delete_file_record, update_file_ai,
    list_folders, create_folder, delete_folder, get_folder_file_count,
    get_overview_stats
)
from models.api_models import (
    UploadResponse, FileOut, FolderOut, FolderCreate, OverviewStats, FileMoveRequest
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

@router.delete("/folders/{folder_id}", status_code=204)
async def remove_folder(folder_id: str):
    delete_folder(folder_id)


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
    media_type = f.get("mime_type") or "application/octet-stream"
    return FileResponse(path, media_type=media_type, filename=f["original_name"])

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


# ─── Upload ──────────────────────────────────────────────────────────────────────
@router.post("/upload", response_model=UploadResponse, status_code=201)
async def upload_document(
    file: UploadFile = File(...),
    folder_id: Optional[str] = Form(None),
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
        try:
            with _pdf_lock:
                await asyncio.to_thread(load_documents_to_db, disk_path)
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

    return UploadResponse(
        message=f"{file.filename} uploaded successfully.",
        filename=safe_name,
        file_id=record["id"],
        status="success",
    )


# ─── Legacy compat ───────────────────────────────────────────────────────────────
# Keep old /api/upload route pointing here for backward compatibility
