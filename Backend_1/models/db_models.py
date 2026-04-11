from pydantic import BaseModel
from datetime import datetime

class ChatMessageHistory(BaseModel):
    """
    Pydantic representation of a persistent medical chat session.
    (Placeholder) Easily map this to traditional SQL (PostgreSQL/SQLite) 
    using SQLModel in the future to keep global user conversational bounds tracked, 
    independent of the LanceDB automated Vector schemas.
    """
    session_id: str
    user_query: str
    assistant_response: str
    timestamp: datetime
    images_attached: bool = False
