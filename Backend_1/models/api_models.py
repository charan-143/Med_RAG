from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime


# ─── Chat ───────────────────────────────────────────────────────────────────────
class ChatResponse(BaseModel):
    """Schema structuring exact diagnostic outputs."""
    response: str
    status: str = "success"
    context_used: bool = False

class ChatMessage(BaseModel):
    id: str
    role: str          # "user" | "assistant"
    content: str
    context_ids: str = ""
    created_at: str

class ChatSessionOut(BaseModel):
    id: str
    title: str
    is_pinned: bool = False
    is_archived: bool = False
    created_at: str
    updated_at: str

class ChatSessionUpdate(BaseModel):
    title: Optional[str] = None
    is_pinned: Optional[bool] = None
    is_archived: Optional[bool] = None


# ─── Upload ─────────────────────────────────────────────────────────────────────
class UploadResponse(BaseModel):
    """Schema structuring document injection outputs."""
    message: str
    filename: str
    file_id: str
    status: str = "success"


# ─── Files & Folders ────────────────────────────────────────────────────────────
class FolderCreate(BaseModel):
    name: str
    icon: str = "folder"

class FolderUpdate(BaseModel):
    name: Optional[str] = None
    icon: Optional[str] = None

class FolderOut(BaseModel):
    id: str
    name: str
    icon: str
    created_at: str
    file_count: int = 0
    ai_summary: Optional[str] = None

class FileOut(BaseModel):
    id: str
    original_name: str
    safe_name: str
    file_type: str
    mime_type: Optional[str] = None
    size_bytes: int = 0
    folder_id: Optional[str] = None
    ai_name: Optional[str] = None
    ai_summary: Optional[str] = None
    uploaded_at: str

class FileMoveRequest(BaseModel):
    folder_id: Optional[str] = None

class OverviewStats(BaseModel):
    total_records: int
    total_folders: int
    by_type: Dict[str, int] = {}
    recent_files: List[Dict[str, Any]] = []


# ─── Notes ──────────────────────────────────────────────────────────────────────
class NoteCreate(BaseModel):
    title: str = "Untitled Entry"
    content: str = ""
    tags: str = ""
    source: str = "manual"
    source_ref: Optional[str] = None

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    tags: Optional[str] = None
    is_pinned: Optional[bool] = None

class NoteOut(BaseModel):
    id: str
    title: str
    content: str
    tags: str = ""
    is_pinned: bool = False
    source: str = "manual"
    source_ref: Optional[str] = None
    created_at: str
    updated_at: str

class SaveInsightRequest(BaseModel):
    chat_message_id: Optional[str] = None
    title: str = "AI Insight"
    content: str


# ─── Profile ─────────────────────────────────────────────────────────────────────
class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    dob: Optional[str] = None
    gender: Optional[str] = None
    blood_type: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    emergency_name: Optional[str] = None
    emergency_phone: Optional[str] = None
    emergency_rel: Optional[str] = None
    allergies: Optional[str] = None
    conditions: Optional[str] = None
    medications: Optional[str] = None
    insurance_provider: Optional[str] = None
    insurance_policy: Optional[str] = None

class ProfileOut(BaseModel):
    id: str
    full_name: Optional[str] = None
    dob: Optional[str] = None
    gender: Optional[str] = None
    blood_type: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    emergency_name: Optional[str] = None
    emergency_phone: Optional[str] = None
    emergency_rel: Optional[str] = None
    allergies: Optional[str] = None
    conditions: Optional[str] = None
    medications: Optional[str] = None
    insurance_provider: Optional[str] = None
    insurance_policy: Optional[str] = None
    updated_at: str
