import os
from agno.vectordb.lancedb import LanceDb
from agno.knowledge.knowledge import Knowledge
from agno.knowledge.embedder.google import GeminiEmbedder
from core.config import settings

# Vector store lives under data/vector_store/ (consolidated data directory)
VECTOR_STORE_URI = os.path.join("data", "vector_store")
os.makedirs(VECTOR_STORE_URI, exist_ok=True)
os.makedirs("data/uploads", exist_ok=True)

vector_db = LanceDb(
    table_name="medical_knowledge",
    uri=VECTOR_STORE_URI,
    embedder=GeminiEmbedder(api_key=settings.GOOGLE_API_KEY),
)

pdf_knowledge_base = Knowledge(
    vector_db=vector_db,
)
