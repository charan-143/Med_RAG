import os
from agno.vectordb.lancedb import LanceDb
from agno.knowledge.knowledge import Knowledge
from core.config import settings

os.makedirs(settings.LANCEDB_URI, exist_ok=True)
os.makedirs("data/uploads", exist_ok=True)

from agno.knowledge.embedder.google import GeminiEmbedder

vector_db = LanceDb(
    table_name="medical_knowledge",
    uri=settings.LANCEDB_URI,
    embedder=GeminiEmbedder(api_key=settings.GOOGLE_API_KEY),
)

pdf_knowledge_base = Knowledge(
    vector_db=vector_db,
)
