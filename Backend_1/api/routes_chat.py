"""
Chat routes — updated for agno v2.x Team API.
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from typing import Optional, Annotated
import os
import shutil
import uuid
import logging
import asyncio
from datetime import datetime

from agno.team import Team
from agents.routing_agent import create_medical_team_agent
from api.dependencies import get_medical_team_router
from models.api_models import ChatResponse, ChatMessage, ChatSessionUpdate, ChatSessionOut
from services.image_processor import prepare_image
from db.sqlite_db import (
    create_chat_session, list_chat_sessions, delete_chat_session,
    update_chat_session, list_files, get_file
)

log = logging.getLogger(__name__)
router = APIRouter(tags=["chat"])


@router.get("/chat/sessions")
async def get_sessions():
    """Return all chat session headers."""
    return list_chat_sessions()


@router.post("/chat/sessions")
async def create_session(title: str = Form("New Consultation")):
    """Start a new isolated chat session."""
    session_id = str(uuid.uuid4())
    create_chat_session(session_id, title)
    return {"session_id": session_id, "title": title}


@router.delete("/chat/sessions/{session_id}")
async def delete_session_endpoint(session_id: str):
    """Delete a session and its associated Agno memory."""
    delete_chat_session(session_id)
    return {"status": "success"}


@router.patch("/chat/sessions/{session_id}", response_model=ChatSessionOut)
async def update_session_endpoint(session_id: str, body: ChatSessionUpdate):
    """
    Patch a session's title, pinned state, or archived state.
    Used by: Rename, Pin chat, Archive menu actions.
    """
    updated = update_chat_session(
        session_id,
        title=body.title,
        is_pinned=body.is_pinned,
        is_archived=body.is_archived,
    )
    if not updated:
        raise HTTPException(404, f"Session {session_id} not found")
    return ChatSessionOut(
        id=updated["id"],
        title=updated["title"],
        is_pinned=bool(updated.get("is_pinned", 0)),
        is_archived=bool(updated.get("is_archived", 0)),
        created_at=updated["created_at"],
        updated_at=updated["updated_at"],
    )


@router.get("/chat/sessions/{session_id}/export")
async def export_session(session_id: str):
    """
    Export full chat history as a plain-text transcript.
    Used by: Share menu action — returns the conversation as a downloadable string.
    """
    from fastapi.responses import PlainTextResponse
    team = create_medical_team_agent(session_id=session_id)
    lines = [f"# Clinical Atelier — Chat Export\n# Session: {session_id}\n"]
    try:
        history = team.get_chat_history(session_id=session_id, last_n_runs=200)
        if history:
            for m in history:
                role_label = "You" if m.role == "user" else "Assistant"
                content = str(m.content) if m.content else ""
                lines.append(f"{role_label}:\n{content}\n")
    except Exception as e:
        log.warning(f"Export failed for {session_id}: {e}")
    transcript = "\n".join(lines)
    return PlainTextResponse(
        content=transcript,
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="chat_{session_id[:8]}.txt"'},
    )


@router.get("/chat/history", response_model=list[ChatMessage])
async def get_chat_history(session_id: str, limit: int = 50):
    """Return persisted chat messages for a specific session via Agno."""
    team = create_medical_team_agent(session_id=session_id)
    
    # Load session history from storage using Agno v2 method
    msgs = []
    try:
        history = team.get_chat_history(session_id=session_id, last_n_runs=limit)
        if history:
            for idx, m in enumerate(history):
                # Map agno.models.message.Message to our ChatMessage model
                role = m.role
                if role == "assistant":
                    role = "assistant"
                elif role == "user":
                    role = "user"
                else:
                    continue # Skip system messages for the UI
                    
                msgs.append(ChatMessage(
                    id=f"{session_id}_{idx}",
                    role=role,
                    content=str(m.content) if m.content else "",
                    created_at=datetime.utcnow().isoformat() # Agno doesn't store per-msg timestamp explicitly
                ))
    except Exception as e:
        log.warning(f"Agno session history empty or not found for {session_id}: {e}")
            
    return msgs


@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    message: Annotated[str, Form()] = "",
    session_id: Annotated[str, Form()] = "",
    image: Annotated[Optional[UploadFile], File()] = None,
    file_ids:   Annotated[Optional[str], Form()] = None,
    folder_ids: Annotated[Optional[str], Form()] = None,
):
    print(f"DEBUG: chat_endpoint hit: session={session_id}, msg_len={len(message)}")
    team = create_medical_team_agent(session_id=session_id)
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

    # Prepend context from selected files to the prompt
    final_prompt = message
    if context_ids:
        context_items = []
        for cid in context_ids:
            cf = get_file(cid)
            if cf:
                summary_snippet = cf.get("ai_summary") or "No summary available."
                context_items.append(f"- {cf['original_name']}: {summary_snippet}")
        
        if context_items:
            context_block = "User context:\nThe user has provided the following documents for context:\n" + "\n".join(context_items)
            final_prompt = f"{context_block}\n\nUser Question: {message}"

    try:
        # agno Team.run() — same signature as Agent.run() for images
        if images_to_process:
            result = await asyncio.to_thread(team.run, final_prompt, images=images_to_process)
        else:
            result = await asyncio.to_thread(team.run, final_prompt)

        # TeamRunOutput exposes .content (str | list)
        ai_content = result.content
        if isinstance(ai_content, list):
            ai_content = "\n".join(
                str(block.text if hasattr(block, "text") else block)
                for block in ai_content
            )
        ai_content = ai_content or "I was unable to generate a response. Please try again."

        # Persistence of assistant message is handled by Agno during run()

        return ChatResponse(
            response=ai_content,
            status="success",
            context_used=bool(context_ids or images_to_process),
        )

    except Exception:
        log.exception("Error in chat_endpoint")
        raise HTTPException(500, "Internal server error")
