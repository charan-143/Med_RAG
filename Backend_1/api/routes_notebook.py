"""
Notebook routes: CRUD for patient notes + save AI insight from chat.
"""

from fastapi import APIRouter, HTTPException
from models.api_models import NoteCreate, NoteUpdate, NoteOut, SaveInsightRequest
from db.sqlite_db import list_notes, get_note, create_note, update_note, delete_note

router = APIRouter(tags=["notebook"])


@router.get("/notes", response_model=list[NoteOut])
async def get_notes():
    notes = list_notes()
    return [_to_out(n) for n in notes]


@router.post("/notes", response_model=NoteOut, status_code=201)
async def add_note(body: NoteCreate):
    note = create_note(
        title=body.title,
        content=body.content,
        tags=body.tags,
        source=body.source,
        source_ref=body.source_ref,
    )
    return _to_out(note)


@router.get("/notes/{note_id}", response_model=NoteOut)
async def get_note_detail(note_id: str):
    note = get_note(note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    return _to_out(note)


@router.put("/notes/{note_id}", response_model=NoteOut)
async def edit_note(note_id: str, body: NoteUpdate):
    note = update_note(
        note_id,
        title=body.title,
        content=body.content,
        tags=body.tags,
        is_pinned=body.is_pinned,
    )
    if not note:
        raise HTTPException(404, "Note not found")
    return _to_out(note)


@router.delete("/notes/{note_id}", status_code=204)
async def remove_note(note_id: str):
    if not get_note(note_id):
        raise HTTPException(404, "Note not found")
    delete_note(note_id)


@router.post("/notes/save-insight", response_model=NoteOut, status_code=201)
async def save_ai_insight(body: SaveInsightRequest):
    """Save an AI chat response as a pinned notebook insight."""
    note = create_note(
        title=body.title,
        content=body.content,
        tags="ai-insight",
        source="chat",
        source_ref=body.chat_message_id,
    )
    # Auto-pin it
    note = update_note(note["id"], is_pinned=True)
    return _to_out(note)


def _to_out(n: dict) -> NoteOut:
    return NoteOut(
        id=n["id"],
        title=n["title"],
        content=n["content"],
        tags=n.get("tags", ""),
        is_pinned=bool(n.get("is_pinned", 0)),
        source=n.get("source", "manual"),
        source_ref=n.get("source_ref"),
        created_at=n["created_at"],
        updated_at=n["updated_at"],
    )
