"""
Chat routes — updated for agno v2.x Team API.
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from typing import Optional
import os
import shutil
import uuid
import logging

from agno.team import Team
from api.dependencies import get_medical_team_router
from models.api_models import ChatResponse, ChatMessage
from services.image_processor import prepare_image
from db.sqlite_db import save_chat_message, list_chat_history, list_files

log = logging.getLogger(__name__)
router = APIRouter(tags=["chat"])


@router.get("/chat/history", response_model=list[ChatMessage])
async def get_chat_history(limit: int = 50):
    """Return saved chat message history."""
    msgs = list_chat_history(limit)
    return [ChatMessage(**m) for m in msgs]


@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    message: str = Form(...),
    image: Optional[UploadFile] = File(None),
    file_ids:   Optional[str] = Form(None),   # comma-separated vault file IDs
    folder_ids: Optional[str] = Form(None),   # comma-separated folder IDs
    team: Team = Depends(get_medical_team_router),
):
    images_to_process = []
    context_ids: list[str] = []

    # Build vault context list
    if file_ids:
        context_ids.extend(fid.strip() for fid in file_ids.split(",") if fid.strip())
    if folder_ids:
        for fid in (f.strip() for f in folder_ids.split(",") if f.strip()):
            context_ids.extend(f["id"] for f in list_files(folder_id=fid))

    # Handle direct image upload
    if image and image.filename:
        fname_lower = image.filename.lower()
        if not fname_lower.endswith((".png", ".jpg", ".jpeg", ".webp")):
            raise HTTPException(400, "Unsupported image file type.")

        UPLOAD_DIR = "data/uploads"
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        ext = os.path.splitext(fname_lower)[1]
        safe_fn = f"{uuid.uuid4().hex}{ext}"
        filepath = os.path.join(UPLOAD_DIR, safe_fn)

        with open(filepath, "wb") as buf:
            shutil.copyfileobj(image.file, buf)
        images_to_process.append(prepare_image(filepath))

    # Persist user message
    save_chat_message(
        role="user",
        content=message,
        context_ids=",".join(context_ids),
    )

    try:
        # agno Team.run() — same signature as Agent.run() for images
        if images_to_process:
            result = team.run(message, images=images_to_process)
        else:
            result = team.run(message)

        # TeamRunOutput exposes .content (str | list)
        ai_content = result.content
        if isinstance(ai_content, list):
            ai_content = "\n".join(
                str(block.text if hasattr(block, "text") else block)
                for block in ai_content
            )
        ai_content = ai_content or "I was unable to generate a response. Please try again."

        # Persist assistant message
        save_chat_message(role="assistant", content=ai_content)

        return ChatResponse(
            response=ai_content,
            status="success",
            context_used=bool(context_ids or images_to_process),
        )

    except Exception:
        log.exception("Error in chat_endpoint")
        raise HTTPException(500, "Internal server error")
