from pydantic import BaseModel
from typing import Optional

class ChatResponse(BaseModel):
    """Schema structuring exact diagnostic outputs."""
    response: str
    status: str = "success"

class UploadResponse(BaseModel):
    """Schema structuring document injection outputs."""
    message: str
    filename: str
    status: str = "success"
